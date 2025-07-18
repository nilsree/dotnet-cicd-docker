#!/bin/bash

# GitHub CI/CD script for automated deployment
# This script polls a GitHub repository for changes and deploys automatically

# Configuration variables with defaults
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
POLL_INTERVAL="${POLL_INTERVAL:-60}"  # seconds
BUILD_SCRIPT="${BUILD_SCRIPT:-deploy.sh}"
ENABLE_AUTO_BUILD="${ENABLE_AUTO_BUILD:-true}"
APP_DIR="/app"
TEMP_DIR="/tmp/github-deploy"
LAST_COMMIT_FILE="/app/.last_commit"
SSH_KEY_FILE="/tmp/github_deploy_key"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CD: $1"
}

# Function to setup SSH key for GitHub access
setup_ssh_key() {
    local deploy_key="$1"
    
    if [ -z "$deploy_key" ]; then
        log "No deploy key provided, attempting public repository access"
        return 1
    fi
    
    # Create SSH directory
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Write deploy key to file
    echo "$deploy_key" > "$SSH_KEY_FILE"
    chmod 600 "$SSH_KEY_FILE"
    
    # Configure SSH to use the key
    cat > ~/.ssh/config << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY_FILE
    IdentitiesOnly yes
    StrictHostKeyChecking no
EOF
    
    chmod 600 ~/.ssh/config
    
    log "SSH key configured for GitHub access"
    return 0
}

# Function to get latest commit hash from GitHub
get_latest_commit() {
    local repo="$1"
    local branch="$2"
    
    # Try SSH first, then HTTPS
    local ssh_url="git@github.com:$repo.git"
    local https_url="https://github.com/$repo.git"
    
    # Try SSH access first
    if [ -f "$SSH_KEY_FILE" ]; then
        log "Attempting SSH access to repository"
        local commit_hash=$(git ls-remote "$ssh_url" "refs/heads/$branch" 2>/dev/null | cut -f1)
        if [ -n "$commit_hash" ]; then
            echo "$commit_hash"
            return 0
        fi
    fi
    
    # Fallback to HTTPS for public repositories
    log "Attempting HTTPS access to repository"
    local commit_hash=$(git ls-remote "$https_url" "refs/heads/$branch" 2>/dev/null | cut -f1)
    if [ -n "$commit_hash" ]; then
        echo "$commit_hash"
        return 0
    fi
    
    log "ERROR: Could not access repository"
    return 1
}

# Function to download and extract repository
download_repo() {
    local repo="$1"
    local branch="$2"
    local dest="$3"
    
    log "Downloading repository $repo (branch: $branch)..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Try SSH clone first, then HTTPS
    local ssh_url="git@github.com:$repo.git"
    local https_url="https://github.com/$repo.git"
    
    # Try SSH access first
    if [ -f "$SSH_KEY_FILE" ]; then
        log "Attempting SSH clone"
        if git clone --depth 1 --branch "$branch" "$ssh_url" repo 2>/dev/null; then
            log "SSH clone successful"
            cp -r repo/* "$dest/"
            return 0
        fi
    fi
    
    # Fallback to HTTPS for public repositories
    log "Attempting HTTPS clone"
    if git clone --depth 1 --branch "$branch" "$https_url" repo 2>/dev/null; then
        log "HTTPS clone successful"
        cp -r repo/* "$dest/"
        return 0
    fi
    
    log "ERROR: Failed to clone repository"
    return 1
}

# Function to run build script
run_build_script() {
    local script_path="$1"
    
    if [ "$ENABLE_AUTO_BUILD" != "true" ]; then
        log "Auto-build is disabled, skipping build script"
        return 0
    fi
    
    if [ -f "$script_path" ]; then
        log "Running build script: $script_path"
        chmod +x "$script_path"
        
        # Run build script with proper environment
        cd "$APP_DIR"
        bash "$script_path"
        
        if [ $? -eq 0 ]; then
            log "Build script completed successfully"
            return 0
        else
            log "ERROR: Build script failed"
            return 1
        fi
    else
        log "Build script not found: $script_path"
        return 1
    fi
}

# Function to restart .NET application
restart_dotnet_app() {
    log "Restarting .NET application..."
    
    # Find and kill existing .NET process
    local dotnet_pid=$(pgrep -f "dotnet.*\.dll")
    if [ -n "$dotnet_pid" ]; then
        log "Stopping existing .NET application (PID: $dotnet_pid)"
        kill $dotnet_pid
        sleep 5
        
        # Force kill if still running
        if kill -0 $dotnet_pid 2>/dev/null; then
            log "Force killing .NET application"
            kill -9 $dotnet_pid
        fi
    fi
    
    # Start new .NET application
    log "Starting new .NET application..."
    cd "$APP_DIR"
    
    # Find the main DLL file
    local dll_file=$(find . -name "*.dll" -type f | head -n 1)
    
    if [ -n "$dll_file" ]; then
        nohup dotnet "$dll_file" > /var/log/dotnet.log 2>&1 &
        local new_pid=$!
        log "Started new .NET application (PID: $new_pid)"
        echo $new_pid > /var/run/dotnet.pid
        return 0
    else
        log "ERROR: No .dll file found for .NET application"
        return 1
    fi
}

# Function to perform deployment
deploy_update() {
    local repo="$1"
    local branch="$2"
    local commit_hash="$3"
    
    log "Starting deployment for commit: $commit_hash"
    
    # Backup current application
    if [ -d "$APP_DIR" ]; then
        log "Creating backup of current application..."
        cp -r "$APP_DIR" "${APP_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Download new version
    if download_repo "$repo" "$branch" "$APP_DIR"; then
        # Run build script if enabled
        local build_script_path="$APP_DIR/$BUILD_SCRIPT"
        if run_build_script "$build_script_path"; then
            # Restart application
            if restart_dotnet_app; then
                # Update last commit hash
                echo "$commit_hash" > "$LAST_COMMIT_FILE"
                log "Deployment completed successfully"
                return 0
            else
                log "ERROR: Failed to restart .NET application"
                return 1
            fi
        else
            log "ERROR: Build script failed"
            return 1
        fi
    else
        log "ERROR: Failed to download repository"
        return 1
    fi
}

# Main polling loop
main() {
    if [ -z "$GITHUB_REPO" ]; then
        log "GITHUB_REPO not set, CI/CD disabled"
        return 0
    fi
    
    # Setup SSH key for GitHub access (from volume mount)
    if [ -f "/secrets/github_deploy_key" ]; then
        setup_ssh_key "$(cat /secrets/github_deploy_key)"
    else
        log "No SSH key found at /secrets/github_deploy_key, attempting public repository access"
    fi
    
    log "Starting CI/CD polling for repository: $GITHUB_REPO"
    log "Branch: $GITHUB_BRANCH"
    log "Poll interval: ${POLL_INTERVAL}s"
    log "Build script: $BUILD_SCRIPT"
    log "Auto-build enabled: $ENABLE_AUTO_BUILD"
    
    # Get last known commit
    local last_commit=""
    if [ -f "$LAST_COMMIT_FILE" ]; then
        last_commit=$(cat "$LAST_COMMIT_FILE")
        log "Last known commit: $last_commit"
    fi
    
    while true; do
        # Get latest commit from GitHub
        local latest_commit=$(get_latest_commit "$GITHUB_REPO" "$GITHUB_BRANCH")
        
        if [ -n "$latest_commit" ]; then
            if [ "$latest_commit" != "$last_commit" ]; then
                log "New commit detected: $latest_commit"
                
                # Perform deployment
                if deploy_update "$GITHUB_REPO" "$GITHUB_BRANCH" "$latest_commit"; then
                    last_commit="$latest_commit"
                    log "Successfully deployed commit: $latest_commit"
                else
                    log "ERROR: Deployment failed for commit: $latest_commit"
                fi
            else
                log "No new commits detected"
            fi
        else
            log "ERROR: Could not fetch latest commit from GitHub"
        fi
        
        # Wait before next poll
        sleep "$POLL_INTERVAL"
    done
}

# Run main function
main "$@"

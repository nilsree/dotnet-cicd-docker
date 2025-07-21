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
SSH_KEY_FILE="/secrets/github_deploy_key"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CD: $1"
}

# Function to setup SSH key for GitHub access
setup_ssh_key() {
    # Check if SSH key file exists (mounted from volume)
    if [ -f "$SSH_KEY_FILE" ]; then
        log "Found SSH key file at $SSH_KEY_FILE"
        
        # Create SSH directory
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # Ensure correct permissions on key file
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
    else
        log "No SSH key file found at $SSH_KEY_FILE, attempting public repository access"
        return 1
    fi
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
    
    # Clean and create temp directory
    rm -rf "$TEMP_DIR"
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
            rm -rf "$TEMP_DIR"  # Clean up temp directory
            return 0
        fi
    fi
    
    # Fallback to HTTPS for public repositories
    log "Attempting HTTPS clone"
    if git clone --depth 1 --branch "$branch" "$https_url" repo 2>/dev/null; then
        log "HTTPS clone successful"
        cp -r repo/* "$dest/"
        rm -rf "$TEMP_DIR"  # Clean up temp directory
        return 0
    fi
    
    log "ERROR: Failed to clone repository"
    rm -rf "$TEMP_DIR"  # Clean up temp directory even on failure
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
        log "Build script not found: $script_path, running default build process"
        return run_default_build
    fi
}

# Function to run default .NET build when no deploy script exists
run_default_build() {
    log "Starting default .NET build process"
    cd "$APP_DIR"
    
    # Determine project file to use
    local project_file=""
    if [ -n "$PROJECT_PATH" ]; then
        if [ -f "$PROJECT_PATH" ]; then
            project_file="$PROJECT_PATH"
            log "Using specified project: $project_file"
        else
            log "ERROR: Specified project not found: $PROJECT_PATH"
            return 1
        fi
    else
        # Auto-detect project file
        if ls *.sln 1> /dev/null 2>&1; then
            project_file="$(ls *.sln | head -n1)"
            log "Auto-detected solution: $project_file"
        elif ls *.csproj 1> /dev/null 2>&1; then
            project_file="$(ls *.csproj | head -n1)"
            log "Auto-detected project: $project_file"
        else
            log "ERROR: No .NET project or solution file found"
            return 1
        fi
    fi
    
    # Build the .NET application
    log "Restoring NuGet packages..."
    dotnet restore "$project_file"
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to restore NuGet packages"
        return 1
    fi
    
    log "Building application..."
    dotnet build "$project_file" -c Release
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to build application"
        return 1
    fi
    
    log "Publishing application..."
    dotnet publish "$project_file" -c Release -o /app/publish
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to publish application"
        return 1
    fi
    
    # Move published files to app directory
    if [ -d "/app/publish" ]; then
        log "Moving published files..."
        cp -r /app/publish/* /app/
        rm -rf /app/publish
    fi
    
    log "Default build completed successfully"
    return 0
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

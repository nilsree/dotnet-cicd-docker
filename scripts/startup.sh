#!/bin/bash

# Function to find and identify the .NET application DLL
find_app_dll() {
    local app_dll=""
    
    # First check for CI/CD built applications in /app
    cd /app
    
    # Look for .runtimeconfig.json files which indicate the main executable
    for config_file in *.runtimeconfig.json; do
        if [ -f "$config_file" ]; then
            # Extract the base name (remove .runtimeconfig.json)
            local base_name="${config_file%.runtimeconfig.json}"
            local dll_file="${base_name}.dll"
            
            if [ -f "$dll_file" ]; then
                app_dll="$dll_file"
                break
            fi
        fi
    done
    
    # Fallback to finding any DLL file in /app
    if [ -z "$app_dll" ]; then
        for dll in *.dll; do
            if [ -f "$dll" ]; then
                app_dll="$dll"
                break
            fi
        done
    fi
    
    # If no CI/CD app found, use fallback TestApp
    if [ -z "$app_dll" ]; then
        cd /app/fallback
        for config_file in *.runtimeconfig.json; do
            if [ -f "$config_file" ]; then
                local base_name="${config_file%.runtimeconfig.json}"
                local dll_file="${base_name}.dll"
                
                if [ -f "$dll_file" ]; then
                    app_dll="fallback/$dll_file"
                    break
                fi
            fi
        done
        
        if [ -z "$app_dll" ]; then
            for dll in *.dll; do
                if [ -f "$dll" ]; then
                    app_dll="fallback/$dll"
                    break
                fi
            done
        fi
    fi
    
    cd /app
    
    if [ -z "$app_dll" ]; then
        echo "ERROR: No .NET application DLL found in /app or /app/fallback" >&2
        return 1
    fi
    
    echo "$app_dll"
}

# Function to start CI/CD process
start_ci_cd() {
    if [ "$ENABLE_CI_CD" = "true" ] && [ -n "$GITHUB_REPO" ]; then
        echo "Starting CI/CD process..."
        /ci-cd.sh &
        CI_CD_PID=$!
        echo "CI/CD process started successfully"
    else
        echo "CI/CD is disabled or GITHUB_REPO not set"
    fi
}

# Function to start .NET application
start_dotnet_app() {
    echo "Starting .NET application..."
    
    # Find the main application DLL
    APP_DLL=$(find_app_dll)
    
    if [ -z "$APP_DLL" ]; then
        echo "ERROR: Could not find application DLL"
        
        # If CI/CD is enabled, wait for it to potentially download an app
        if [ "$ENABLE_CI_CD" = "true" ] && [ -n "$GITHUB_REPO" ]; then
            echo "Waiting for CI/CD to download application..."
            # Wait up to 120 seconds for CI/CD to provide an app
            for i in $(seq 1 120); do
                sleep 1
                APP_DLL=$(find_app_dll)
                if [ -n "$APP_DLL" ]; then
                    echo "Application found after CI/CD download: $APP_DLL"
                    break
                fi
                if [ $((i % 30)) -eq 0 ]; then
                    echo "Still waiting for CI/CD... ($i/120 seconds)"
                fi
            done
        fi
        
        if [ -z "$APP_DLL" ]; then
            echo "ERROR: No application available after waiting"
            exit 1
        fi
    fi
    
    echo "Starting .NET application: $APP_DLL"
    dotnet "$APP_DLL" &
    DOTNET_PID=$!
    
    echo ".NET application started successfully"
}

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    
    # Kill CI/CD process
    if [ ! -z "$CI_CD_PID" ]; then
        kill $CI_CD_PID
        wait $CI_CD_PID 2>/dev/null
    fi
    
    # Kill .NET application
    if [ ! -z "$DOTNET_PID" ]; then
        kill $DOTNET_PID
        wait $DOTNET_PID 2>/dev/null
    fi
    
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

echo "=== .NET GitHub CI/CD Container Startup ==="

# Start CI/CD process
start_ci_cd

# Start .NET application
start_dotnet_app

# Wait for .NET application to finish (with restart resilience)
echo "Container ready - monitoring services..."

# Continuous monitoring loop instead of simple wait
while true; do
    # Check if .NET process is still running
    if ! kill -0 $DOTNET_PID 2>/dev/null; then
        echo "DOTNET application process ended, checking for replacement..."
        
        # Give CI/CD time to potentially restart the application
        sleep 5
        
        # Look for new .NET process
        NEW_DOTNET_PID=$(pgrep -f "dotnet.*\.dll")
        if [ -n "$NEW_DOTNET_PID" ]; then
            echo "New .NET application detected (PID: $NEW_DOTNET_PID)"
            DOTNET_PID=$NEW_DOTNET_PID
        else
            # Try to restart application ourselves as fallback
            echo "No replacement found, attempting to restart application..."
            APP_DLL=$(find_app_dll)
            if [ -n "$APP_DLL" ]; then
                echo "Restarting .NET application: $APP_DLL"
                dotnet "$APP_DLL" &
                DOTNET_PID=$!
            else
                echo "ERROR: Cannot restart - no application DLL found"
                exit 1
            fi
        fi
    fi
    
    # Check if CI/CD process is still running (restart if needed)
    if [ "$ENABLE_CI_CD" = "true" ] && [ -n "$GITHUB_REPO" ]; then
        if ! kill -0 $CI_CD_PID 2>/dev/null; then
            echo "CI/CD process ended, restarting..."
            /ci-cd.sh &
            CI_CD_PID=$!
        fi
    fi
    
    # Wait before next check
    sleep 10
done

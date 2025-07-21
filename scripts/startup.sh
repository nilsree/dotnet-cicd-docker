#!/bin/bash

# Function to find and identify the .NET application DLL
find_app_dll() {
    local app_dll=""
    
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
    
    # Fallback to finding any DLL file
    if [ -z "$app_dll" ]; then
        for dll in *.dll; do
            if [ -f "$dll" ]; then
                app_dll="$dll"
                break
            fi
        done
    fi
    
    if [ -z "$app_dll" ]; then
        echo "ERROR: No .NET application DLL found in /app" >&2
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

# Wait for .NET application to finish
wait $DOTNET_PID

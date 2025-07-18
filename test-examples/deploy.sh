#!/bin/bash

# Test deployment script
echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: Starting test deployment"

# Navigate to application directory
cd /app

# Check if this is our test application
if [ -f "TestApp.csproj" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: Found TestApp.csproj"
    
    # Restore packages
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: Restoring packages..."
    dotnet restore TestApp.csproj
    
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: ERROR: Failed to restore packages"
        exit 1
    fi
    
    # Build the application
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: Building application..."
    dotnet build TestApp.csproj -c Release
    
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: ERROR: Failed to build"
        exit 1
    fi
    
    # Publish the application
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: Publishing application..."
    dotnet publish TestApp.csproj -c Release -o /app/publish
    
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: ERROR: Failed to publish"
        exit 1
    fi
    
    # Move published files
    if [ -d "/app/publish" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: Moving published files..."
        cp -r /app/publish/* /app/
        rm -rf /app/publish
    fi
    
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: No TestApp.csproj found, using generic deployment"
    
    # Generic .NET deployment
    dotnet restore
    dotnet build -c Release
    dotnet publish -c Release -o /app/publish
    
    if [ -d "/app/publish" ]; then
        cp -r /app/publish/* /app/
        rm -rf /app/publish
    fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST DEPLOY: Deployment completed successfully"
exit 0

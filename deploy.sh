#!/bin/bash

# Default deployment script
# This script is executed after code is downloaded from GitHub
# Customize this script according to your application's build requirements

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Starting deployment script"

# Navigate to application directory
cd /app

# Check if this is a .NET application
if [ -f "*.csproj" ] || [ -f "*.sln" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Detected .NET application"
    
    # Restore NuGet packages
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Restoring NuGet packages..."
    dotnet restore
    
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: ERROR: Failed to restore NuGet packages"
        exit 1
    fi
    
    # Build the application
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Building application..."
    dotnet build -c Release
    
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: ERROR: Failed to build application"
        exit 1
    fi
    
    # Publish the application
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Publishing application..."
    dotnet publish -c Release -o /app/publish
    
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: ERROR: Failed to publish application"
        exit 1
    fi
    
    # Move published files to app directory
    if [ -d "/app/publish" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Moving published files..."
        cp -r /app/publish/* /app/
        rm -rf /app/publish
    fi
    
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: No .NET project files found, skipping build"
fi

# Run database migrations if Entity Framework is present
if [ -f "*.csproj" ]; then
    # Check if Entity Framework is installed
    if dotnet tool list -g | grep -q "dotnet-ef"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Running Entity Framework migrations..."
        dotnet ef database update --connection "$ConnectionStrings__DefaultConnection"
        
        if [ $? -ne 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: WARNING: Entity Framework migrations failed"
        fi
    fi
fi

# Custom deployment steps can be added here
# For example:
# - Copy configuration files
# - Run additional build steps
# - Update file permissions
# - Run tests

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Deployment script completed successfully"
exit 0

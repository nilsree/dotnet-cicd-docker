#!/bin/bash

# Default deployment script
# This script is executed after code is downloaded from GitHub
# Customize this script according to your application's build requirements

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Starting deployment script"

# Navigate to application directory
cd /app

# Determine project file to use
PROJECT_FILE=""
if [ -n "$PROJECT_PATH" ]; then
    # Use specified project path
    if [ -f "$PROJECT_PATH" ]; then
        PROJECT_FILE="$PROJECT_PATH"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Using specified project: $PROJECT_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: ERROR: Specified project not found: $PROJECT_PATH"
        exit 1
    fi
else
    # Auto-detect project file
    if ls *.sln 1> /dev/null 2>&1; then
        PROJECT_FILE="$(ls *.sln | head -n1)"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Auto-detected solution: $PROJECT_FILE"
    elif ls *.csproj 1> /dev/null 2>&1; then
        PROJECT_FILE="$(ls *.csproj | head -n1)"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Auto-detected project: $PROJECT_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: ERROR: No .NET project or solution file found"
        exit 1
    fi
fi

# Check if this is a .NET application
if [ -n "$PROJECT_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Building .NET application: $PROJECT_FILE"
    
    # Restore NuGet packages
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Restoring NuGet packages..."
    dotnet restore "$PROJECT_FILE"
    
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: ERROR: Failed to restore NuGet packages"
        exit 1
    fi
    
    # Build the application
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Building application..."
    dotnet build "$PROJECT_FILE" -c Release
    
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: ERROR: Failed to build application"
        exit 1
    fi
    
    # Publish the application
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPLOY: Publishing application..."
    dotnet publish "$PROJECT_FILE" -c Release -o /app/publish
    
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

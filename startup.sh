#!/bin/bash

# Function to check if SQL Server is available and ready
wait_for_sql_server() {
    if ! command -v /opt/mssql/bin/sqlservr >/dev/null 2>&1; then
        echo "SQL Server not installed (likely ARM64 architecture) - skipping SQL Server startup"
        return 1
    fi
    
    echo "Waiting for SQL Server to start..."
    while ! /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1; do
        echo "SQL Server is not ready yet. Waiting..."
        sleep 2
    done
    echo "SQL Server is ready!"
}

# Function to start SQL Server
start_sql_server() {
    if ! command -v /opt/mssql/bin/sqlservr >/dev/null 2>&1; then
        echo "SQL Server not available on this architecture - continuing without local SQL Server"
        echo "You can connect to an external SQL Server using connection strings"
        return 0
    fi
    
    echo "Starting SQL Server..."
    /opt/mssql/bin/sqlservr &
    SQL_PID=$!
    
    # Wait for SQL Server to be ready
    if wait_for_sql_server; then
        # Run any initialization scripts if they exist
        if [ -d "/docker-entrypoint-initdb.d" ]; then
            echo "Running initialization scripts..."
            for f in /docker-entrypoint-initdb.d/*.sql; do
                if [ -f "$f" ]; then
                    echo "Executing $f..."
                    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -i "$f"
                fi
            done
        fi
        echo "SQL Server started successfully"
    fi
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
    
    # Find the main DLL file
    DLL_FILE=$(find /app -name "*.dll" -type f | head -n 1)
    
    if [ -z "$DLL_FILE" ]; then
        echo "Error: No .dll file found in /app directory"
        exit 1
    fi
    
    echo "Starting .NET application: $DLL_FILE"
    dotnet "$DLL_FILE" &
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
    
    # Kill SQL Server
    if [ ! -z "$SQL_PID" ]; then
        kill $SQL_PID
        wait $SQL_PID 2>/dev/null
    fi
    
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

# Validate required environment variables
if [ -z "$SA_PASSWORD" ]; then
    echo "Error: SA_PASSWORD environment variable is required"
    exit 1
fi

# Configure SQL Server
echo "Configuring SQL Server..."
/opt/mssql/bin/mssql-conf setup accept-eula

# Start SQL Server
start_sql_server

# Start CI/CD process
start_ci_cd

# Start .NET application
start_dotnet_app

# Wait for both processes
wait

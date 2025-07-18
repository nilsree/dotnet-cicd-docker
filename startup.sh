#!/bin/bash

# Function to check if SQL Server is available and ready
wait_for_sql_server() {
    if ! command -v /opt/mssql/bin/sqlservr >/dev/null 2>&1; then
        echo "SQL Server not installed (likely ARM64 architecture) - skipping SQL Server startup"
        return 1
    fi
    
    # Determine which version of sqlcmd to use
    local SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
    if [ ! -f "$SQLCMD" ]; then
        SQLCMD="/opt/mssql-tools/bin/sqlcmd"
    fi
    
    echo "Waiting for SQL Server to start..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if [ -f "/opt/mssql-tools18/bin/sqlcmd" ]; then
            # Use TLS version for newer tools
            if $SQLCMD -S localhost -U sa -P "$SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1; then
                echo "SQL Server is ready!"
                return 0
            fi
        else
            # Use non-TLS version for older tools
            if $SQLCMD -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1; then
                echo "SQL Server is ready!"
                return 0
            fi
        fi
        
        echo "SQL Server is not ready yet. Waiting... (attempt $((attempt + 1))/$max_attempts)"
        sleep 3
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: SQL Server failed to start within $((max_attempts * 3)) seconds"
    return 1
}

# Function to start SQL Server
start_sql_server() {
    if ! command -v /opt/mssql/bin/sqlservr >/dev/null 2>&1; then
        echo "SQL Server not available on this architecture - continuing without local SQL Server"
        echo "You can connect to an external SQL Server using connection strings"
        return 0
    fi
    
    echo "Starting SQL Server with custom initialization..."
    
    # Set required environment variables
    export MSSQL_SA_PASSWORD="$SA_PASSWORD"
    export ACCEPT_EULA="$ACCEPT_EULA"
    export MSSQL_PID="$MSSQL_PID"
    
    # Start SQL Server using our custom init script
    /init-mssql.sh &
    SQL_PID=$!
    
    # Wait for SQL Server to be ready
    if wait_for_sql_server; then
        # Run any initialization scripts if they exist
        if [ -d "/docker-entrypoint-initdb.d" ]; then
            echo "Running initialization scripts..."
            
            # Determine which version of sqlcmd to use
            local SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
            local SQLCMD_ARGS="-S localhost -U sa -P $SA_PASSWORD -C"
            if [ ! -f "$SQLCMD" ]; then
                SQLCMD="/opt/mssql-tools/bin/sqlcmd"
                SQLCMD_ARGS="-S localhost -U sa -P $SA_PASSWORD"
            fi
            
            for f in /docker-entrypoint-initdb.d/*.sql; do
                if [ -f "$f" ]; then
                    echo "Executing $f..."
                    $SQLCMD $SQLCMD_ARGS -i "$f"
                fi
            done
        fi
        echo "SQL Server started successfully"
    else
        echo "ERROR: SQL Server failed to start properly"
        echo "Check SQL Server logs for details"
        return 1
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
    
    # Find the main application by looking for .runtimeconfig.json file
    RUNTIME_CONFIG=$(find /app -name "*.runtimeconfig.json" -type f | head -n 1)
    
    if [ -n "$RUNTIME_CONFIG" ]; then
        APP_NAME=$(basename "$RUNTIME_CONFIG" .runtimeconfig.json)
        DLL_FILE="/app/$APP_NAME.dll"
        echo "Found runtime config: $RUNTIME_CONFIG"
        echo "Main application: $APP_NAME"
    else
        # Fallback: look for main application DLL by name pattern
        DLL_FILE=$(find /app -name "*.dll" -type f | grep -E "(App\.dll|\.App\.dll)" | head -n 1)
        
        # If still no DLL found, try to exclude known dependency libraries
        if [ -z "$DLL_FILE" ]; then
            DLL_FILE=$(find /app -name "*.dll" -type f | grep -v "System\." | grep -v "Microsoft\." | grep -v "Swashbuckle\." | grep -v "Azure\." | head -n 1)
        fi
    fi
    
    if [ -z "$DLL_FILE" ] || [ ! -f "$DLL_FILE" ]; then
        echo "Error: No main application .dll file found in /app directory"
        echo "Available files:"
        ls -la /app/
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

# Start SQL Server (configuration is handled in the function)
start_sql_server

# Start CI/CD process
start_ci_cd

# Start .NET application
start_dotnet_app

# Wait for both processes
wait

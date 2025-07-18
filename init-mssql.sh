#!/bin/bash

# SQL Server initialization script for Docker
# This script replaces the need for systemctl in containers

set -e

# Check if SQL Server is installed
if ! command -v /opt/mssql/bin/sqlservr >/dev/null 2>&1; then
    echo "SQL Server not available on this architecture"
    exit 1
fi

# Validate environment variables
if [ -z "$SA_PASSWORD" ]; then
    echo "ERROR: SA_PASSWORD environment variable is required"
    exit 1
fi

if [ -z "$ACCEPT_EULA" ] || [ "$ACCEPT_EULA" != "Y" ]; then
    echo "ERROR: ACCEPT_EULA must be set to 'Y'"
    exit 1
fi

# Set default PID if not specified
export MSSQL_PID="${MSSQL_PID:-Express}"

echo "Initializing SQL Server with PID: $MSSQL_PID"

# Create SQL Server configuration
mkdir -p /var/opt/mssql/data
mkdir -p /var/opt/mssql/log
mkdir -p /var/opt/mssql/backup

# Set permissions
chown -R mssql:mssql /var/opt/mssql 2>/dev/null || true

# Create mssql.conf with basic settings
cat > /var/opt/mssql/mssql.conf << EOF
[EULA]
accepteula = Y

[coredump]
captureminiandfull = true
coredumptype = full

[filelocation]
defaultbackupdir = /var/opt/mssql/backup
defaultdatadir = /var/opt/mssql/data
defaultlogdir = /var/opt/mssql/log

[network]
tcpport = 1433
EOF

# Start SQL Server
echo "Starting SQL Server..."
exec /opt/mssql/bin/sqlservr

# Multi-stage Dockerfile for .NET Application with MSSQL
FROM mcr.microsoft.com/mssql/server:2022-latest AS mssql-base

# .NET Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
ARG CSPROJ_PATH=test-examples/TestApp/TestApp.csproj

# Copy project file and restore dependencies
COPY ${CSPROJ_PATH} ./TestApp/TestApp.csproj
RUN dotnet restore ./TestApp/TestApp.csproj

# Copy source code and build
COPY . .
RUN dotnet publish ${CSPROJ_PATH} -c Release -o /app/publish

# Final runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# Install SQL Server tools and dependencies + CI/CD tools
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    apt-transport-https \
    gnupg \
    lsb-release \
    unzip \
    git \
    jq \
    openssh-client \
    ca-certificates \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --batch --yes -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/20.04/prod focal main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get install -y mssql-tools18 unixodbc-dev \
    && echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install SQL Server (only on amd64 - SQL Server doesn't support ARM64)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --batch --yes -o /usr/share/keyrings/microsoft-prod.gpg \
        && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/20.04/mssql-server-2022 focal main" > /etc/apt/sources.list.d/mssql-server.list \
        && apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y mssql-server \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*; \
    else \
        echo "SQL Server not available for $ARCH architecture - will use external database"; \
    fi

# Copy published app
COPY --from=build /app/publish .

# Create directories for SQL Server data
RUN mkdir -p /var/opt/mssql/data \
    && mkdir -p /var/opt/mssql/log \
    && mkdir -p /var/opt/mssql/backup

# Copy CI/CD and deployment scripts
COPY ci-cd.sh /ci-cd.sh
COPY deploy.sh /deploy.sh
COPY startup.sh /startup.sh
RUN chmod +x /ci-cd.sh /deploy.sh /startup.sh

# Environment variables with defaults
ENV ACCEPT_EULA=Y
ENV MSSQL_PID=Express
ENV CSPROJ_PATH=""
ENV DOTNET_ENVIRONMENT=Production

# CI/CD Environment variables (GitHub Deploy Key handled securely via volume mount)
ENV GITHUB_REPO=""
ENV GITHUB_BRANCH=main
ENV POLL_INTERVAL=60
ENV BUILD_SCRIPT=deploy.sh
ENV ENABLE_AUTO_BUILD=true
ENV ENABLE_CI_CD=false

# Expose ports
EXPOSE 1433 80 443

# Set startup script as entrypoint
ENTRYPOINT ["/startup.sh"]

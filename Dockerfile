# Multi-stage Dockerfile for .NET Application with GitHub CI/CD

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

# Install dependencies for CI/CD functionality
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    unzip \
    git \
    jq \
    openssh-client \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy published app
COPY --from=build /app/publish .

# Copy CI/CD and deployment scripts
COPY scripts/ci-cd.sh /ci-cd.sh
COPY scripts/deploy.sh /deploy.sh
COPY scripts/startup.sh /startup.sh
RUN chmod +x /ci-cd.sh /deploy.sh /startup.sh

# Environment variables with defaults
ENV ASPNETCORE_ENVIRONMENT=Production

# CI/CD Environment variables (GitHub Deploy Key handled securely via volume mount)
ENV GITHUB_REPO=""
ENV GITHUB_BRANCH=main
ENV PROJECT_PATH=""
ENV POLL_INTERVAL=60
ENV BUILD_SCRIPT=deploy.sh
ENV ENABLE_AUTO_BUILD=true
ENV ENABLE_CI_CD=false

# Expose standard web ports
EXPOSE 8080 443

# Set startup script as entrypoint
ENTRYPOINT ["/startup.sh"]

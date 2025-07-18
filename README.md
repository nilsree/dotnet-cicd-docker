# .NET GitHub CI/CD Docker Image for Unraid

**Repository:** `nilsree/dotnet-cicd-docker`

This Docker image provides a streamlined solution for running .NET applications with GitHub CI/CD integration, optimized for Unraid and container environments.

## Features

- ✅ Runs .NET applications (supports .NET 6, 7, 8, 9)
- ✅ **GitHub CI/CD integration with automatic deployment**
- ✅ **Monorepo support with PROJECT_PATH**
- ✅ Multi-architecture support (linux/amd64, linux/arm64)
- ✅ Configurable .csproj path via build argument
- ✅ Secure SSH Deploy Key handling via volume mounts
- ✅ **Automatic build and restart on GitHub changes**
- ✅ **Configurable polling intervals and build scripts**
- ✅ Unraid template included
- ✅ Professional English documentation
- ✅ Safe shutdown of all services

## Use Cases

### Standalone .NET Applications:
- ✅ Web APIs and services
- ✅ Background services and workers
- ✅ Console applications with web interfaces

### CI/CD Integration:
- ✅ Automatic deployment from GitHub
- ✅ Development and staging environments
- ✅ Rapid prototyping and testing
## Usage

### 1. Build Docker Image

```bash
# Basic build with example app
./build.sh "test-examples/TestApp/TestApp.csproj" "your-app-name" "latest"

# Or with your own app
./build.sh "YourApp/YourApp.csproj" "your-app-name" "latest"

# Or manually
docker build --build-arg CSPROJ_PATH="test-examples/TestApp/TestApp.csproj" -t your-app-name .
```

### 2. Run with Docker Compose

```bash
# Edit docker-compose.yml first
docker-compose up -d
```

### 3. Install on Unraid

1. Copy `unraid-template.xml` to your Unraid Community Applications template folder
2. Or add template URL to Community Applications
3. Install from Apps tab

## Configuration

### Environment Variables

#### .NET Application
- `ASPNETCORE_ENVIRONMENT`: ASP.NET Core environment (Production, Test, Development)
- `ASPNETCORE_URLS`: Listening URLs
- `ConnectionStrings__DefaultConnection`: Database connection string (if using external database)

#### Custom Variables
You can add your own environment variables by defining them in docker-compose.yml or Unraid template.

#### CI/CD Configuration
- `ENABLE_CI_CD`: Enable automatic deployment from GitHub (true/false)
- `GITHUB_REPO`: GitHub repository in format "owner/repo"
- `GITHUB_BRANCH`: GitHub branch to monitor for changes (default: main)
- `PROJECT_PATH`: Path to .csproj or .sln file in repository (optional, auto-detects if not specified)
- `POLL_INTERVAL`: Interval in seconds to check for updates (default: 60)
- `BUILD_SCRIPT`: Build script to run after code update (default: deploy.sh)
- `ENABLE_AUTO_BUILD`: Enable automatic build after code update (true/false)

> **Security Note**: GitHub Deploy Key is provided via volume mount at `/secrets/github_deploy_key`, not environment variables for better security.

### Volumes

- `/app/data`: Application data directory
- `/secrets/github_deploy_key`: SSH Deploy Key for GitHub access (read-only)

### Ports

- `80`: HTTP web application
- `443`: HTTPS web application

## CI/CD and Automatic Deployment

The container supports automatic deployment from GitHub repositories:

### Setup
1. Set `ENABLE_CI_CD=true`
2. Configure `GITHUB_REPO` to your repository (format: "owner/repo")
3. Set `GITHUB_BRANCH` to desired branch (default: main)
4. **For monorepos**: Set `PROJECT_PATH` to specific project file (e.g., `src/WebApi/WebApi.csproj`)
5. **For private repositories only**: Mount SSH deploy key at `/secrets/github_deploy_key`
6. Adjust `POLL_INTERVAL` for how often to check for updates

> **Note**: Public repositories work without any authentication. SSH deploy keys are only needed for private repositories.

### Monorepo Support
The container can work with monorepos by specifying the exact project to build:

```bash
# Example: Public repository (no authentication needed)
GITHUB_REPO=mycompany/public-monorepo
PROJECT_PATH=backend/webapi/WebApi.csproj

# Example: Private repository (requires SSH deploy key)
GITHUB_REPO=mycompany/private-monorepo
PROJECT_PATH=backend/webapi/WebApi.csproj
# + volume mount: ./secrets:/secrets:ro
```

If `PROJECT_PATH` is not specified, the container will auto-detect the first `.sln` or `.csproj` file in the repository root.

### Build Script
The container will run `deploy.sh` (or script defined in `BUILD_SCRIPT`) after each update.

Standard `deploy.sh` performs:
- `dotnet restore`
- `dotnet build -c Release`
- `dotnet publish -c Release`
- Entity Framework migrations (if available)

### Customize Build Script
You can customize the build process by:
1. Modifying `deploy.sh` in repository
2. Or specify custom script with `BUILD_SCRIPT` variable

```bash
# Example of custom build script
#!/bin/bash
echo "Custom build process"
dotnet restore
dotnet build -c Release
# Custom build steps here
```

## Security

- **GitHub Deploy Keys**: Store SSH keys securely via volume mounts, not environment variables
- **Environment Variables**: Use Docker secrets or secure volume mounts for sensitive configuration
- **Network Security**: Limit container network access as needed
- **Regular Updates**: Keep base images and dependencies updated

## .NET Version

The container uses .NET 9.0 by default. To upgrade to newer versions, see `DOTNET-VERSION.md` for instructions.

## Troubleshooting

### Container logs
```bash
docker logs -f your-container-name
```

### Connect to Application
```bash
```bash
curl http://localhost:8080/
```

### Debug CI/CD process
```bash
docker exec -it your-container-name /ci-cd.sh
```

## Unraid Specific Info

### Recommended mappings
- Host: `/mnt/user/appdata/dotnet-cicd-docker/data` → Container: `/app/data`
- Host: `/mnt/user/appdata/dotnet-cicd-docker/secrets` → Container: `/secrets`

### Resources
- Minimum RAM: 512MB
- Recommended RAM: 1-2GB
- CPU: 1 core

## Development

To develop and test:

1. Clone repository
2. Place your .NET application in a subfolder
3. Update CSPROJ_PATH in build.sh
4. Build and test locally
5. Deploy to Unraid
```

### Check CI/CD status
```bash
docker logs -f your-container-name | grep "CD:"
```

### Manual deployment trigger
```bash
docker exec -it your-container-name /ci-cd.sh
```

## Unraid Specific Info

### Recommended mappings
- Host: `/mnt/user/appdata/dotnet-cicd-docker/data` → Container: `/var/opt/mssql/data`
- Host: `/mnt/user/appdata/dotnet-cicd-docker/log` → Container: `/var/opt/mssql/log`
- Host: `/mnt/user/appdata/dotnet-cicd-docker/backup` → Container: `/var/opt/mssql/backup`

### Resources
- Minimum RAM: 1GB
- Recommended RAM: 2-4GB
- CPU: 1-2 cores

## Development

To develop and test:

1. Clone repository
2. Place your .NET application in a subfolder
3. Update CSPROJ_PATH in build.sh
4. Build and test locally
5. Deploy to Unraid

## License

MIT License - see LICENSE file for details.

## Contributing

Pull requests and issues are welcome! Follow standard GitHub workflow.

## Support

For support, create an issue in the GitHub repository or visit Unraid community forums.

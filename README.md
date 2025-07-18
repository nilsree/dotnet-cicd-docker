# .NET MSSQL Docker Image for Unraid

This Docker image allows you to run a .NET application together with an MSSQL Server database in a single container, optimized for Unraid.

## Features

- ✅ Runs .NET applications (supports .NET 6, 7, 8, 9)
- ✅ Integrated MSSQL Server Express (amd64 only)
- ✅ Multi-architecture support (linux/amd64, linux/arm64)
- ✅ ARM64 support with external database option
- ✅ Configurable .csproj path via build argument
- ✅ Volumes for database data files
- ✅ Custom environment variables
- ✅ **CI/CD with GitHub integration**
- ✅ **Automatic deployment from GitHub repository**
- ✅ **Configurable build script**
- ✅ Unraid template included
- ✅ Automatic database initialization
- ✅ Safe shutdown of all services

## Architecture Support

### AMD64 (x86_64):
- ✅ Native SQL Server 2022 Express
- ✅ Optimal performance
- ✅ All features supported

### ARM64 (Apple Silicon, ARM servers):
- ✅ .NET application runs natively
- ✅ SQL Server runs via x86_64 emulation (Docker Desktop)
- ⚠️ Slightly reduced SQL Server performance due to emulation
- ✅ Full feature compatibility

> **Note for ARM64**: SQL Server runs through x86_64 emulation on ARM64 platforms. While fully functional, there may be a performance impact. For production ARM64 deployments, consider using Azure SQL Database or an external SQL Server instance for optimal performance.

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

### ARM64 Performance Considerations

While this container works on ARM64 (Apple Silicon, ARM servers), SQL Server runs via x86_64 emulation:

- **Development**: Works perfectly fine for development and testing
- **Production**: Consider external SQL Server or Azure SQL for better performance
- **Docker Desktop**: Handles emulation automatically on Apple Silicon

### Environment Variables

#### SQL Server
- `SA_PASSWORD`: SQL Server SA password (required, min 8 characters with upper/lower case, numbers and special characters)
- `ACCEPT_EULA`: Accept SQL Server EULA (must be 'Y')
- `MSSQL_PID`: SQL Server edition (Express, Developer, Standard, Enterprise)

#### .NET Application
- `DOTNET_ENVIRONMENT`: .NET environment (Production, Test, Development)
- `ASPNETCORE_ENVIRONMENT`: ASP.NET Core environment (Production, Test, Development)
- `ASPNETCORE_URLS`: Listening URLs
- `ConnectionStrings__DefaultConnection`: Database connection string

#### Custom Variables
You can add your own environment variables by defining them in docker-compose.yml or Unraid template.

#### CI/CD Configuration
- `ENABLE_CI_CD`: Enable automatic deployment from GitHub (true/false)
- `GITHUB_REPO`: GitHub repository in format "owner/repo"
- `GITHUB_BRANCH`: GitHub branch to monitor for changes (default: main)
- `POLL_INTERVAL`: Interval in seconds to check for updates (default: 60)
- `BUILD_SCRIPT`: Build script to run after code update (default: deploy.sh)
- `ENABLE_AUTO_BUILD`: Enable automatic build after code update (true/false)

> **Security Note**: GitHub Deploy Key is provided via volume mount at `/secrets/github_deploy_key`, not environment variables for better security.

### Volumes

- `/var/opt/mssql/data`: SQL Server data files
- `/var/opt/mssql/log`: SQL Server log files  
- `/var/opt/mssql/backup`: SQL Server backup files
- `/docker-entrypoint-initdb.d`: SQL initialization scripts

### Ports

- `80`: HTTP web application
- `443`: HTTPS web application
- `1433`: SQL Server database

## CI/CD and Automatic Deployment

The container supports automatic deployment from GitHub repositories:

### Setup
1. Set `ENABLE_CI_CD=true`
2. Configure `GITHUB_REPO` to your repository (format: "owner/repo")
3. Set `GITHUB_BRANCH` to desired branch (default: main)
4. For private repositories, set `GITHUB_DEPLOY_KEY` to your SSH private key
5. Adjust `POLL_INTERVAL` for how often to check for updates

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

## Database Initialization

Place SQL scripts in the `sql-scripts/` folder or mount them to `/docker-entrypoint-initdb.d` in the container. Scripts are executed automatically on first startup.

Example:
```sql
-- init.sql
CREATE DATABASE MyApp;
GO
USE MyApp;
GO
CREATE TABLE Users (Id INT IDENTITY(1,1) PRIMARY KEY, Name NVARCHAR(100));
GO
```

## Security

- **IMPORTANT**: Change SA_PASSWORD before production - this is required!
- Use strong passwords (minimum 8 characters, upper/lower case, numbers, special characters)
- Update ConnectionStrings__DefaultConnection to match your SA_PASSWORD
- Consider using SQL Server authentication instead of SA
- Limit network access to SQL Server port (1433)

## .NET Version

The container uses .NET 9.0 by default. To upgrade to newer versions, see `DOTNET-VERSION.md` for instructions.

## Troubleshooting

### Container logs
```bash
docker logs -f your-container-name
```

### Connect to SQL Server
```bash
docker exec -it your-container-name /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourPassword" -C
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
- Host: `/mnt/user/appdata/dotnet-mssql-docker/data` → Container: `/var/opt/mssql/data`
- Host: `/mnt/user/appdata/dotnet-mssql-docker/log` → Container: `/var/opt/mssql/log`
- Host: `/mnt/user/appdata/dotnet-mssql-docker/backup` → Container: `/var/opt/mssql/backup`

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

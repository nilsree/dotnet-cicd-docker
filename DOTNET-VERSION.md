# .NET Version Configuration

This project is configured for .NET 9.0 by default. To update to a new .NET version, follow these steps:

## Upgrading to .NET 10 (or newer version)

### 1. Update Dockerfile

In `Dockerfile`, change the following lines:

```dockerfile
# From:
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# To:
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

# And:
FROM mcr.microsoft.com/dotnet/aspnet:9.0

# To:
FROM mcr.microsoft.com/dotnet/aspnet:10.0
```

### 2. Update README.md

In `README.md`, update the features section:

```markdown
# From:
- ✅ Runs .NET applications (supports .NET 6, 7, 8, 9)

# To:
- ✅ Runs .NET applications (supports .NET 6, 7, 8, 9, 10)
```

### 3. Test with your application

Make sure your .NET application is compatible with the new version:

```bash
# Build and test locally
./build.sh "YourApp/YourApp.csproj" "test-image" "latest"

# Test run
docker run -it --rm test-image
```

### 4. Update documentation

Update any references to .NET version in:
- `README.md`
- `CI-CD-SETUP.md`
- `docker-compose.yml` comments

## Backward Compatibility

The container still supports older .NET applications, but it's recommended to upgrade your application to the latest LTS version for best performance and security.

## Version Strategy

- **Current**: .NET 9.0 (current version)
- **LTS**: .NET 8.0 (Long Term Support)
- **Next**: .NET 10.0 (planned November 2025)

For production environments, consider using LTS versions for stability.

# CI/CD Setup Guide

## GitHub Repository Setup

### 1. Prepare your repository
Make sure your .NET repository has:
- `.csproj` or `.sln` file in root or specify path with PROJECT_PATH
- `deploy.sh` script (optional, automatic .NET build is used if not present)
- Any database migration scripts (if using external database)

### 2. GitHub Deploy Key (Only for Private Repositories)
For **private repositories** you need a GitHub Deploy Key. **Public repositories work without any authentication.**

#### For Private Repositories:

1. Generate SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/github_deploy_key
   ```

2. Add public key to GitHub:
   - Go to your repository → Settings → Deploy keys
   - Click "Add deploy key"
   - Title: "Docker Container Deploy Key"
   - Key: Copy content from `~/.ssh/github_deploy_key.pub`
   - Check "Allow write access" if you need push capabilities
   - Click "Add key"

3. Use private key in container:
   - Copy content from `~/.ssh/github_deploy_key` (private key)
   - Mount as volume at `/secrets/github_deploy_key`

#### For Public Repositories:
No authentication needed! Just set `GITHUB_REPO` and the container will automatically use HTTPS to access your public repository.

### 3. Repository structure
```
your-repo/
├── YourApp/                    # Your .NET application folder
│   ├── YourApp.csproj
│   ├── Program.cs
│   └── ...
├── deploy.sh (optional)        # Custom build script
└── README.md
```

**Example with test app:**
```
dotnet-cicd-docker/
├── test-examples/
│   └── TestApp/
│       ├── TestApp.csproj
│       ├── Program.cs
│       └── Controllers/
├── deploy.sh
└── README.md
```

**Monorepo example:**
```
my-company-monorepo/
├── backend/
│   ├── WebApi/
│   │   ├── WebApi.csproj         # Set PROJECT_PATH=backend/WebApi/WebApi.csproj
│   │   └── Program.cs
│   └── Services/
├── frontend/
├── mobile/
└── deploy.sh
```

## Docker Compose Example

### For Public Repository:
```yaml
version: '3.8'
services:
  app:
    image: nilsree/dotnet-cicd-docker
    environment:
      # CI/CD configuration (public repo)
      - ENABLE_CI_CD=true
      - GITHUB_REPO=your-username/your-public-repo
      - GITHUB_BRANCH=main
      - PROJECT_PATH=src/MyApp/MyApp.csproj  # Optional: path to specific project in monorepo
      - POLL_INTERVAL=30
      - BUILD_SCRIPT=deploy.sh
      - ENABLE_AUTO_BUILD=true
      
      # ASP.NET Core configuration
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:8080
      - ConnectionStrings__DefaultConnection=Server=your-external-db;Database=YourApp;User Id=username;Password=password;TrustServerCertificate=true;
    volumes:
      - ./data:/app/data
    ports:
      - "8080:8080"
      - "8443:443"
```

### For Private Repository:
```yaml
version: '3.8'
services:
  app:
    image: nilsree/dotnet-cicd-docker
    environment:
      # CI/CD configuration (private repo)
      - ENABLE_CI_CD=true
      - GITHUB_REPO=your-username/your-private-repo
      - GITHUB_BRANCH=main
      - PROJECT_PATH=src/MyApp/MyApp.csproj  # Optional: path to specific project in monorepo
      - POLL_INTERVAL=30
      - BUILD_SCRIPT=deploy.sh
      - ENABLE_AUTO_BUILD=true
      
      # ASP.NET Core configuration
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:8080
      - ConnectionStrings__DefaultConnection=Server=your-external-db;Database=YourApp;User Id=username;Password=password;TrustServerCertificate=true;
    volumes:
      - ./data:/app/data
      - ./secrets:/secrets:ro  # SSH deploy key for private repos
    ports:
      - "8080:8080"
      - "8443:443"
```

## Unraid Setup

### 1. Install template
1. Copy `unraid-template.xml` to `/boot/config/plugins/dockerMan/templates-user/`
2. Or add repository URL to Community Applications

### 2. Configure variables

#### For Public Repository:
In Unraid Docker settings:
- **Enable CI/CD**: `true`
- **GitHub Repository**: `your-username/your-public-repo`
- **GitHub Branch**: `main`
- **Project Path**: `src/MyApp/MyApp.csproj` (optional for monorepos)
- **Poll Interval**: `60`
- **Build Script**: `deploy.sh`
- **Enable Auto Build**: `true`

#### For Private Repository:
In Unraid Docker settings (additional volume required):
- **Enable CI/CD**: `true`
- **GitHub Repository**: `your-username/your-private-repo`
- **GitHub Branch**: `main`
- **Project Path**: `src/MyApp/MyApp.csproj` (optional for monorepos)
- **Poll Interval**: `60`
- **Build Script**: `deploy.sh`
- **Enable Auto Build**: `true`
- **Volume**: `/mnt/user/appdata/secrets:/secrets:ro` (for SSH deploy key)

## Deployment Workflow

### Automatic deployment
1. Push changes to GitHub repository
2. Container detects changes within `POLL_INTERVAL` seconds
3. Downloads new code
4. Runs build script (`deploy.sh`)
5. Restarts .NET application
6. Application is updated

### Manual deployment
```bash
# Trigger manual deployment
docker exec -it container-name /ci-cd.sh

# Or restart container
docker restart container-name
```

## Build Script Customization

### Standard deploy.sh
```bash
#!/bin/bash
cd /app
dotnet restore
dotnet build -c Release
dotnet publish -c Release -o /app/publish
cp -r /app/publish/* /app/
```

### Custom build script
```bash
#!/bin/bash
echo "Starting custom build process"

# Restore packages
dotnet restore

# Build solution
dotnet build -c Release

# Run tests
dotnet test

# Publish application
dotnet publish -c Release -o /app/publish

# Copy published files
cp -r /app/publish/* /app/

# Run database migrations (if using Entity Framework)
# dotnet ef database update

echo "Build completed successfully"
```

## Security

### GitHub Deploy Key
- Use deploy keys with minimal access (read-only unless write is needed)
- Rotate deploy keys regularly
- Don't share private keys in logs or code
- Store private keys securely

### External Database
- Use strong passwords
- Consider secure authentication methods
- Limit network access
- Use connection string encryption

### Container security
- Run as non-root user if possible
- Use secrets management
- Monitor container logs

## Troubleshooting

### CI/CD logs
```bash
docker logs container-name | grep "CD:"
```

### GitHub API issues
```bash
# Test GitHub SSH access
ssh -T git@github.com -i /path/to/deploy/key
```

### Build errors
```bash
# Check build script
docker exec -it container-name cat /app/deploy.sh
docker exec -it container-name /app/deploy.sh
```

### Common Issues

#### Repository Access Error
If you see "ERROR: Could not access repository":

1. **For Private Repositories**: 
   - Ensure SSH deploy key is properly mounted at `/secrets/github_deploy_key`
   - Verify the deploy key is added to your GitHub repository
   - Check key permissions: `chmod 600 /secrets/github_deploy_key`

2. **For Public Repositories**:
   - Verify the repository URL format: `owner/repo` (no https:// prefix)
   - Check if repository exists and is public
   - Ensure GITHUB_REPO environment variable is set correctly

#### Build Script Issues
If you see "Build script not found" or "ERROR: Build script failed":

1. **No deploy.sh needed**:
   - Container automatically builds .NET projects if no `deploy.sh` is found
   - Just ensure your repository has a `.csproj` or `.sln` file
   - Set `PROJECT_PATH` if your project is in a subdirectory

2. **Custom deploy.sh (optional)**:
   - Create a `deploy.sh` file in your repository root for custom build steps
   - Or change `BUILD_SCRIPT` environment variable to point to your script

3. **Example deploy.sh for custom builds**:
   ```bash
   #!/bin/bash
   echo "Starting build process..."
   
   # Find the .NET project file
   PROJECT_FILE=$(find . -name "*.csproj" | head -1)
   
   if [ -z "$PROJECT_FILE" ]; then
       echo "No .csproj file found"
       exit 1
   fi
   
   echo "Building project: $PROJECT_FILE"
   
   # Restore and build
   dotnet restore "$PROJECT_FILE"
   dotnet build "$PROJECT_FILE" -c Release
   dotnet publish "$PROJECT_FILE" -c Release -o /app/publish
   
   # Copy published files
   cp -r /app/publish/* /app/
   
   echo "Build completed successfully"
   ```

#### Container Connection Issues
```bash
# Check if container is listening on correct port
docker exec -it container-name netstat -tlnp | grep :8080

# Test HTTP endpoint
curl http://localhost:8080
```

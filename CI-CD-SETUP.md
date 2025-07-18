# CI/CD Setup Guide

## GitHub Repository Setup

### 1. Prepare your repository
Make sure your .NET repository has:
- `.csproj` or `.sln` file in root
- `deploy.sh` script (optional, default script is used if not present)
- Any database migration scripts

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
├── sql-scripts/               # Database initialization
│   └── migrations.sql
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
└── sql-scripts/
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
```
your-repo/
├── YourApp/                    # Your .NET application folder
│   ├── YourApp.csproj
│   ├── Program.cs
│   └── ...
├── deploy.sh (optional)        # Custom build script
├── sql-scripts/               # Database initialization
│   └── migrations.sql
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
└── sql-scripts/
```
└── README.md
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
      
      # Database
      - SA_PASSWORD=YourStrong@Passw0rd123
      - ConnectionStrings__DefaultConnection=Server=localhost;Database=YourApp;User Id=sa;Password=YourStrong@Passw0rd123;TrustServerCertificate=true;
    volumes:
      - ./data:/var/opt/mssql/data
    ports:
      - "8080:80"
      - "1433:1433"
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
      
      # Database
      - SA_PASSWORD=YourStrong@Passw0rd123
      - ConnectionStrings__DefaultConnection=Server=localhost;Database=YourApp;User Id=sa;Password=YourStrong@Passw0rd123;TrustServerCertificate=true;
    volumes:
      - ./data:/var/opt/mssql/data
      - ./secrets:/secrets:ro  # SSH deploy key for private repos
    ports:
      - "8080:80"
      - "1433:1433"
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

# Run database migrations
dotnet ef database update

echo "Build completed successfully"
```

## Security

### GitHub Deploy Key
- Use deploy keys with minimal access (read-only unless write is needed)
- Rotate deploy keys regularly
- Don't share private keys in logs or code
- Store private keys securely

### Database
- Use strong passwords
- Consider SQL Server authentication
- Limit network access

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

### Database issues
```bash
# Check SQL Server status
docker exec -it container-name /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "PASSWORD" -C -Q "SELECT @@VERSION"
```

# Testing on Your Unraid Server

## Step 1: Prepare Your .NET Application

First, you need a .NET application to test with. Here's a minimal example:

### Create a test .NET application
```bash
# On your development machine
dotnet new webapi -n TestApp
cd TestApp

# Add Entity Framework (optional, for database testing)
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Tools
```

### Simple Program.cs for testing
```csharp
var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();

var app = builder.Build();

// Configure pipeline
app.UseRouting();
app.MapControllers();

// Simple health check endpoint
app.MapGet("/", () => "Hello from .NET in Docker!");
app.MapGet("/health", () => new { Status = "Healthy", Time = DateTime.Now });

app.Run();
```

## Step 2: Build and Push Docker Image

### Option A: Build locally and push to Docker Hub
```bash
# Build the image
./build.sh "TestApp/TestApp.csproj" "yourusername/dotnet-mssql-test" "latest"

# Push to Docker Hub
docker push yourusername/dotnet-mssql-test:latest
```

### Option B: Use GitHub Actions (recommended)
Create `.github/workflows/docker.yml` in your repository:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: .
        file: ./Dockerfile
        push: true
        tags: yourusername/dotnet-mssql-test:latest
        build-args: |
          CSPROJ_PATH=TestApp/TestApp.csproj
```

## Step 3: Install on Unraid

### Method 1: Using the template file
1. Copy your `unraid-template.xml` to `/mnt/user/appdata/community.applications/templates/`
2. Edit the template to point to your Docker Hub image:
   ```xml
   <Repository>yourusername/dotnet-mssql-test</Repository>
   ```

### Method 2: Manual Docker configuration
1. Go to Docker tab in Unraid
2. Click "Add Container"
3. Configure manually:

**Basic Settings:**
- Name: `dotnet-mssql-test`
- Repository: `yourusername/dotnet-mssql-test:latest`
- Network Type: `bridge`

**Port Mappings:**
- Container Port: `80` → Host Port: `8080`
- Container Port: `1433` → Host Port: `1433`

**Volume Mappings:**
- Container Path: `/var/opt/mssql/data` → Host Path: `/mnt/user/appdata/dotnet-mssql-test/data`
- Container Path: `/var/opt/mssql/log` → Host Path: `/mnt/user/appdata/dotnet-mssql-test/log`
- Container Path: `/var/opt/mssql/backup` → Host Path: `/mnt/user/appdata/dotnet-mssql-test/backup`

**Environment Variables:**
- `SA_PASSWORD`: `YourStrong@Passw0rd123`
- `ACCEPT_EULA`: `Y`
- `MSSQL_PID`: `Express`
- `DOTNET_ENVIRONMENT`: `Development`
- `ASPNETCORE_ENVIRONMENT`: `Development`
- `ENABLE_CI_CD`: `false` (for initial testing)

## Step 4: Testing Steps

### 1. Start the container
```bash
# Check if container is running
docker ps | grep dotnet-mssql-test

# View logs
docker logs -f dotnet-mssql-test
```

### 2. Test web application
```bash
# Test from Unraid terminal
curl http://localhost:8080/
curl http://localhost:8080/health

# Or open in browser
# http://YOUR_UNRAID_IP:8080/
```

### 3. Test SQL Server connection
```bash
# Connect to SQL Server from Unraid terminal
docker exec -it dotnet-mssql-test /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd123" -C

# Run a test query
SELECT @@VERSION;
GO
```

### 4. Test CI/CD (optional)
Once basic functionality works, enable CI/CD:

```bash
# Update container environment variables
docker stop dotnet-mssql-test
# Edit container settings in Unraid UI:
# - ENABLE_CI_CD=true
# - GITHUB_REPO=yourusername/your-test-repo
# - GITHUB_TOKEN=your_token
docker start dotnet-mssql-test

# Monitor CI/CD logs
docker logs -f dotnet-mssql-test | grep "CD:"
```

## Step 5: Troubleshooting

### Common Issues:

**Container won't start:**
```bash
# Check container logs
docker logs dotnet-mssql-test

# Check if ports are available
netstat -tlnp | grep :8080
netstat -tlnp | grep :1433
```

**SQL Server connection fails:**
```bash
# Check SQL Server process
docker exec -it dotnet-mssql-test ps aux | grep sql

# Check SQL Server logs
docker exec -it dotnet-mssql-test cat /var/opt/mssql/log/errorlog
```

**CI/CD not working:**
```bash
# Test GitHub API access
docker exec -it dotnet-mssql-test curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/repos/owner/repo

# Check network connectivity
docker exec -it dotnet-mssql-test ping github.com
```

## Step 6: Monitor and Validate

### Health Checks:
```bash
# Application health
curl http://YOUR_UNRAID_IP:8080/health

# SQL Server health
docker exec -it dotnet-mssql-test /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "PASSWORD" -C -Q "SELECT GETDATE()"

# Container resource usage
docker stats dotnet-mssql-test
```

### Log Monitoring:
```bash
# Real-time logs
docker logs -f dotnet-mssql-test

# Filter specific logs
docker logs dotnet-mssql-test | grep ERROR
docker logs dotnet-mssql-test | grep "CD:"
```

## Quick Start Test Repository

I recommend creating a simple test repository structure:

```
test-repo/
├── TestApp/
│   ├── TestApp.csproj
│   ├── Program.cs
│   └── Controllers/
│       └── HealthController.cs
├── sql-scripts/
│   └── init.sql
├── deploy.sh
└── README.md
```

This gives you a complete testing environment to validate all features before deploying your real application.

## Expected Results

When everything is working correctly:
- ✅ Web application accessible at `http://UNRAID_IP:8080`
- ✅ SQL Server accessible at `UNRAID_IP:1433`
- ✅ Database initialized with test data
- ✅ CI/CD monitoring GitHub for changes (if enabled)
- ✅ Container logs showing successful startup of all services

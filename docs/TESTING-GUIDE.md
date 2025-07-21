# Testing .NET CI/CD Docker Container

## Step 1: Prepare Your .NET Application

First, you need a .NET application to test with. Here's a minimal example:

### Create a test .NET application
```bash
# On your development machine
dotnet new webapi -n TestApp
cd TestApp

# Add Entity Framework (optional, for external database testing)
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
app.MapGet("/", () => "Hello from .NET CI/CD Container!");
app.MapGet("/health", () => new { Status = "Healthy", Time = DateTime.Now, Version = "1.0.0" });

app.Run();
```

## Step 2: Build and Push Docker Image

### Option A: Build locally and push to Docker Hub
```bash
# Build the image using the build script
./scripts/build.sh "TestApp/TestApp.csproj" "yourusername/dotnet-cicd-test" "latest"

# Push to Docker Hub
docker push yourusername/dotnet-cicd-test:latest
```

### Option B: Use GitHub Actions (recommended)
The repository already includes GitHub Actions workflow in `.github/workflows/docker-publish.yml`.

Just push to your repository and create a release:
```bash
git add .
git commit -m "Add test application"
git push origin main

# Create a release to trigger Docker Hub publishing
git tag v1.0.0
git push origin v1.0.0
```

## Step 3: Install on Unraid

### Method 1: Using the Community Apps template
1. Search for "DotNet-CICD-Docker" in Community Apps
2. Or manually add template URL: `https://raw.githubusercontent.com/nilsree/dotnet-cicd-docker/main/templates/unraid-template.xml`

### Method 2: Manual Docker configuration
1. Go to Docker tab in Unraid
2. Click "Add Container"
3. Configure manually:

**Basic Settings:**
- Name: `dotnet-cicd-test`
- Repository: `nilsree/dotnet-cicd-docker:latest`
- Network Type: `bridge`

**Port Mappings:**
- Container Port: `8080` → Host Port: `8080`
- Container Port: `443` → Host Port: `8443` (optional HTTPS)

**Volume Mappings:**
- Container Path: `/app/data` → Host Path: `/mnt/user/appdata/dotnet-cicd-test/data`
- Container Path: `/secrets` → Host Path: `/mnt/user/appdata/dotnet-cicd-test/secrets` (for private repos)

**Environment Variables:**
- `ASPNETCORE_ENVIRONMENT`: `Production`
- `ASPNETCORE_URLS`: `http://+:8080`
- `ENABLE_CI_CD`: `true`
- `GITHUB_REPO`: `your-username/your-test-repo`
- `GITHUB_BRANCH`: `main`
- `POLL_INTERVAL`: `60`

## Step 4: Testing Steps

### 1. Start the container
```bash
# Check if container is running
docker ps | grep dotnet-cicd

# View logs
docker logs -f dotnet-cicd-test
```

### 2. Test web application
```bash
# Test from Unraid terminal
curl http://localhost:8080/
curl http://localhost:8080/health

# Or open in browser
# http://YOUR_UNRAID_IP:8080/
```

### 3. Test CI/CD functionality
Once basic functionality works, test the CI/CD features:

```bash
# Check CI/CD logs
docker logs -f dotnet-cicd-test | grep "CD:"

# You should see logs like:
# [2025-07-21 XX:XX:XX] CD: Starting CI/CD polling for repository: your-username/your-repo
# [2025-07-21 XX:XX:XX] CD: No new commits detected
```

### 4. Test automatic deployment
Make a change to your repository and push:

```bash
# In your test repository
echo "Updated at $(date)" >> README.md
git add .
git commit -m "Test CI/CD deployment"
git push

# Monitor container logs for automatic deployment
docker logs -f dotnet-cicd-test | grep "CD:"
```

## Step 5: Troubleshooting

### Common Issues:

**Container won't start:**
```bash
# Check container logs
docker logs dotnet-cicd-test

# Check if ports are available
netstat -tlnp | grep :8080
```

**Application not accessible:**
```bash
# Check if app is listening on correct port
docker exec -it dotnet-cicd-test netstat -tlnp | grep :8080

# Check container networking
docker exec -it dotnet-cicd-test curl http://localhost:8080
```

**CI/CD not working:**
```bash
# Test GitHub API access for public repos
docker exec -it dotnet-cicd-test curl https://api.github.com/repos/owner/repo

# For private repos, check SSH key setup
docker exec -it dotnet-cicd-test ssh -T git@github.com -i /secrets/github_deploy_key

# Check network connectivity
docker exec -it dotnet-cicd-test ping github.com
```

**Build failures:**
```bash
# Check build logs
docker logs dotnet-cicd-test | grep "ERROR"

# Check if .NET project files exist
docker exec -it dotnet-cicd-test find /app -name "*.csproj" -o -name "*.sln"
```

## Step 6: Monitor and Validate

### Health Checks:
```bash
# Application health
curl http://YOUR_UNRAID_IP:8080/health

# Container resource usage
docker stats dotnet-cicd-test

# Check .NET application process
docker exec -it dotnet-cicd-test ps aux | grep dotnet
```

### Log Monitoring:
```bash
# Real-time logs
docker logs -f dotnet-cicd-test

# Filter specific logs
docker logs dotnet-cicd-test | grep ERROR
docker logs dotnet-cicd-test | grep "CD:"
docker logs dotnet-cicd-test | grep "DEPLOY:"
```

## Quick Start Test Repository

I recommend creating a simple test repository structure:

```
test-repo/
├── src/
│   └── TestApp/
│       ├── TestApp.csproj
│       ├── Program.cs
│       └── Controllers/
│           └── HealthController.cs
├── deploy.sh (optional - custom build script)
└── README.md
```

This gives you a complete testing environment to validate all features before deploying your real application.

## Expected Results

When everything is working correctly:
- ✅ Web application accessible at `http://UNRAID_IP:8080`
- ✅ Health endpoint returns JSON with status and timestamp
- ✅ CI/CD monitoring GitHub for changes (if enabled)
- ✅ Automatic deployment when repository changes are detected
- ✅ Container logs showing successful startup of .NET application

## Private Repository Testing

For testing private repositories:

1. **Generate SSH key**:
   ```bash
   ssh-keygen -t ed25519 -f /mnt/user/appdata/dotnet-cicd-test/secrets/github_deploy_key
   ```

2. **Add public key to GitHub**:
   - Go to your repository → Settings → Deploy keys
   - Add content of `github_deploy_key.pub`

3. **Mount secrets volume**:
   - Container Path: `/secrets`
   - Host Path: `/mnt/user/appdata/dotnet-cicd-test/secrets`

4. **Test SSH access**:
   ```bash
   docker exec -it dotnet-cicd-test ssh -T git@github.com -i /secrets/github_deploy_key
   ```

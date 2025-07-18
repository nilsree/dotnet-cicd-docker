# Quick Test Setup

## 1. Create test repository on GitHub
```bash
# Create new repository: dotnet-mssql-test
```

## 2. Upload test files
Copy these files to your test repository:
- `TestApp/` folder with all files
- `deploy.sh`
- `sql-scripts/init.sql` (from main project)

## 3. Build Docker image
```bash
# Clone this repository
git clone https://github.com/yourusername/dotnet-mssql-app.git
cd dotnet-mssql-app

# Build with test app
./build.sh "TestApp/TestApp.csproj" "yourusername/dotnet-mssql-test" "latest"

# Push to Docker Hub
docker push yourusername/dotnet-mssql-test:latest
```

## 4. Test on Unraid

### Manual Docker Setup:
1. **Add Container** in Unraid Docker tab
2. **Repository**: `yourusername/dotnet-mssql-test:latest`
3. **Ports**: `8080:80`, `1433:1433`
4. **Volumes**: 
   - `/mnt/user/appdata/test-app/data:/var/opt/mssql/data`
   - `/mnt/user/appdata/test-app/log:/var/opt/mssql/log`
5. **Environment Variables**:
   - `SA_PASSWORD=TestPassword123!`
   - `ACCEPT_EULA=Y`
   - `ASPNETCORE_ENVIRONMENT=Development`

### Test Endpoints:
- `http://UNRAID_IP:8080/` - Basic info
- `http://UNRAID_IP:8080/api/health` - Health check
- `http://UNRAID_IP:8080/api/health/database` - Database test
- `http://UNRAID_IP:8080/env` - Environment variables
- `http://UNRAID_IP:8080/swagger` - API documentation

### Test CI/CD:
1. Enable CI/CD in container settings
2. Set `GITHUB_REPO=yourusername/dotnet-mssql-test`
3. Set `GITHUB_TOKEN=your_token`
4. Make a change to `Program.cs` and push to GitHub
5. Watch logs: `docker logs -f test-container-name | grep "CD:"`

## Expected Results:
- ✅ Container starts successfully
- ✅ Web API responds on port 8080
- ✅ SQL Server accessible on port 1433
- ✅ Database initialization script runs
- ✅ CI/CD detects GitHub changes (if enabled)

# GitHub Actions Setup Guide

This guide explains how to set up automated Docker image publishing to Docker Hub using GitHub Actions.

## Prerequisites

- Docker Hub account
- GitHub repository with admin access
- .NET project with Dockerfile

## Setup Steps

### 1. Create Docker Hub Access Token

1. Log in to [Docker Hub](https://hub.docker.com/)
2. Go to **Account Settings** → **Security** → **Access Tokens**
3. Click **New Access Token**
4. **Description**: `GitHub Actions - dotnet-mssql-docker`
5. **Permissions**: `Read, Write, Delete` (or `Read, Write` if you prefer)
6. Click **Generate**
7. **Copy the token** - you won't see it again!

### 2. Configure GitHub Secrets

1. Go to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add these secrets:

   | Secret Name | Value | Description |
   |-------------|-------|-------------|
   | `DOCKERHUB_USERNAME` | `nilsree` | Your Docker Hub username |
   | `DOCKERHUB_TOKEN` | `dckr_pat_xxx...` | The access token from step 1 |

### 3. Test the Workflow

#### Option A: Push to main branch (Test Build Only)
```bash
git add .
git commit -m "Add GitHub Actions workflow"
git push origin main
```
This will trigger a **test build only** - no Docker Hub push.

#### Option B: Create a release (Recommended for Publishing)
1. Go to your GitHub repository
2. Click **Releases** → **Create a new release**
3. **Tag version**: `v1.0.0`
4. **Release title**: `v1.0.0 - Initial Release`
5. **Description**: Brief description of features
6. Click **Publish release**

This will trigger a build and push multiple tags:
- `nilsree/dotnet-mssql-docker:latest`
- `nilsree/dotnet-mssql-docker:1.0.0`
- `nilsree/dotnet-mssql-docker:1.0`
- `nilsree/dotnet-mssql-docker:1`

## What the Workflow Does

### On Push to Main:
- ✅ Builds Docker image (test only)
- ❌ Does not push to Docker Hub

### On Release:
- ✅ Builds Docker image
- ✅ Pushes with semantic version tags
- ✅ Updates `latest` tag
- ✅ Updates Docker Hub description
- ✅ Supports multi-platform (linux/amd64, linux/arm64)

### On Pull Request:
- ✅ Builds Docker image (test only)
- ❌ Does not push to Docker Hub

## Versioning Strategy

The workflow uses semantic versioning based on your Git tags:

- `v1.0.0` → `1.0.0`, `1.0`, `1`, `latest`
- `v1.2.3` → `1.2.3`, `1.2`, `1`, `latest`
- `v2.0.0-beta.1` → `2.0.0-beta.1`

## Security Benefits

✅ **Access Tokens vs Passwords:**
- Access tokens can be revoked without changing your password
- Tokens have specific permissions (read/write/delete)
- Tokens can be set to expire automatically
- Better audit trail of token usage

✅ **GitHub Secrets:**
- Encrypted storage in GitHub
- Only accessible by workflows
- Hidden in workflow logs
- Can be rotated easily

## Troubleshooting

### Build fails with authentication error:
1. Check that `DOCKERHUB_USERNAME` matches your Docker Hub username exactly
2. Verify `DOCKERHUB_TOKEN` is correct and not expired
3. Ensure token has `Read, Write` permissions

### Multi-platform build fails:
The workflow builds for both `linux/amd64` and `linux/arm64`. If you only need x86_64:
```yaml
platforms: linux/amd64
```

### Build context issues:
Make sure your Dockerfile is in the repository root, or adjust the context:
```yaml
context: ./subfolder
```

## Manual Docker Hub Description Update

If you want to update the Docker Hub description manually:
```bash
# Install docker-hub-description tool
npm install -g docker-hub-description

# Update description
docker-hub-description nilsree/dotnet-mssql-docker README.md
```

## Next Steps

1. **Set up the secrets** as described above
2. **Create your first release** to test the automation
3. **Monitor the Actions tab** in your GitHub repository to see the workflow progress
4. **Check Docker Hub** to verify the image was pushed successfully

The workflow is now ready for production use! 🚀

### **Usage Examples**

Using specific version:
```yaml
services:
  app:
    image: nilsree/dotnet-mssql-docker:1.0.0
```

Using major version:
```yaml
services:
  app:
    image: nilsree/dotnet-mssql-docker:1
```

## 🎯 Release Process

1. **Develop** on feature branch
2. **Merge** to main (triggers test build)
3. **Create release** on GitHub (triggers production build)
4. **Image is published** automatically to Docker Hub
5. **Users can update** to new version

Perfect! Everything is now ready for automatic publishing! 🚀

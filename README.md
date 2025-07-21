# .NET CI/CD Docker Container

[![Docker Hub](https://img.shields.io/docker/pulls/nilsree/dotnet-cicd-docker)](https://hub.docker.com/r/nilsree/dotnet-cicd-docker)
[![GitHub Release](https://img.shields.io/github/release/nilsree/dotnet-cicd-docker)](https://github.com/nilsree/dotnet-cicd-docker/releases)
[![Build Status](https://github.com/nilsree/dotnet-cicd-docker/workflows/Build%20and%20Push%20Docker%20Image/badge.svg)](https://github.com/nilsree/dotnet-cicd-docker/actions)

A lightweight Docker container that automatically builds and deploys .NET applications from GitHub repositories. Perfect for Unraid, Portainer, or any Docker environment.

## ✨ Features

- **🚀 Automatic GitHub CI/CD**: Polls your repository and auto-deploys on changes
- **🔄 Smart Build Detection**: Automatically detects `.csproj` and `.sln` files
- **🔐 Private Repository Support**: SSH deploy keys for private GitHub repos
- **📦 Multi-Architecture**: Supports both AMD64 and ARM64 platforms
- **⚙️ Monorepo Friendly**: `PROJECT_PATH` support for complex repository structures
- **🛡️ Secure**: No hardcoded credentials, uses volume-mounted SSH keys

## 🚀 Quick Start

### Docker Compose (Public Repository)
```yaml
version: '3.8'
services:
  app:
    image: nilsree/dotnet-cicd-docker
    environment:
      - ENABLE_CI_CD=true
      - GITHUB_REPO=your-username/your-repo
      - GITHUB_BRANCH=main
      - POLL_INTERVAL=60
    ports:
      - "8080:8080"
    volumes:
      - ./data:/app/data
```

### Docker Compose (Private Repository)
```yaml
version: '3.8'
services:
  app:
    image: nilsree/dotnet-cicd-docker
    environment:
      - ENABLE_CI_CD=true
      - GITHUB_REPO=your-username/your-private-repo
      - GITHUB_BRANCH=main
      - POLL_INTERVAL=60
    ports:
      - "8080:8080"
    volumes:
      - ./data:/app/data
      - ./secrets:/secrets:ro  # SSH deploy key
```

## 📖 Documentation

- **[CI/CD Setup Guide](docs/CI-CD-SETUP.md)** - Complete setup instructions
- **[GitHub Actions Setup](docs/GITHUB-ACTIONS-SETUP.md)** - Docker Hub publishing automation
- **[.NET Version Info](docs/DOTNET-VERSION.md)** - .NET version details
- **[Testing Guide](docs/TESTING-GUIDE.md)** - How to test the container
- **[Unraid Template](templates/unraid-template.xml)** - Ready-to-use Unraid template

## 📁 Repository Structure

```
.
├── README.md                    # Project overview and quick start
├── LICENSE                      # MIT license
├── Dockerfile                   # Container definition
├── docs/                       # 📚 All documentation
│   ├── CI-CD-SETUP.md          # Detailed setup guide
│   ├── GITHUB-ACTIONS-SETUP.md # Docker Hub publishing
│   ├── DOTNET-VERSION.md       # .NET version information
│   └── TESTING-GUIDE.md        # Testing instructions
├── scripts/                    # 🔧 All container scripts
│   ├── startup.sh              # Container entrypoint
│   ├── ci-cd.sh               # CI/CD automation
│   ├── deploy.sh              # Default build script
│   └── build.sh               # Development build script
├── templates/                  # 📋 Templates and examples
│   ├── unraid-template.xml    # Unraid Community Apps
│   ├── docker-compose.yml     # Docker Compose example
│   └── .env.example          # Environment variables example
├── test-examples/              # 🧪 Example applications
│   └── TestApp/               # Sample .NET app for testing
└── .github/workflows/         # ⚙️ GitHub Actions
    └── docker-publish.yml     # Automated Docker building
```

## ⚙️ Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ENABLE_CI_CD` | Enable automatic deployment | `false` | No |
| `GITHUB_REPO` | Repository (format: `owner/repo`) | - | Yes |
| `GITHUB_BRANCH` | Git branch to monitor | `main` | No |
| `PROJECT_PATH` | Path to .csproj/.sln in monorepos | - | No |
| `POLL_INTERVAL` | Check interval in seconds | `60` | No |
| `BUILD_SCRIPT` | Custom build script name | `deploy.sh` | No |
| `ENABLE_AUTO_BUILD` | Enable automatic building | `true` | No |
| `ASPNETCORE_URLS` | ASP.NET Core URLs | `http://+:8080` | No |

## 🔧 Advanced Usage

### Monorepo Projects
```bash
# For projects in subdirectories
PROJECT_PATH=src/MyApp/MyApp.csproj
```

### Custom Build Scripts
Create a `deploy.sh` in your repository root:
```bash
#!/bin/bash
echo "Custom build process"
dotnet restore
dotnet build -c Release
dotnet publish -c Release -o /app/publish
cp -r /app/publish/* /app/
```

### Private Repository Setup
1. Generate SSH deploy key: `ssh-keygen -t ed25519 -f deploy_key`
2. Add public key to GitHub repository → Settings → Deploy keys
3. Mount private key: `/path/to/deploy_key:/secrets/github_deploy_key:ro`

## 🏠 Unraid Integration

1. Install from Community Applications
2. Or manually add template URL: `https://raw.githubusercontent.com/nilsree/dotnet-cicd-docker/main/templates/unraid-template.xml`

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test with example app
5. Submit pull request

## 📋 Requirements

- Docker or compatible runtime
- .NET project with `.csproj` or `.sln` file
- GitHub repository (public or private with deploy key)

## 🐛 Troubleshooting

Common issues and solutions in [docs/CI-CD-SETUP.md](docs/CI-CD-SETUP.md#troubleshooting)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for the Unraid community
- Inspired by GitOps principles
- Uses semantic versioning

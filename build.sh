#!/bin/bash

# Build script for Docker image
# Note: For production, use GitHub Actions instead of manual building

# Set default values
CSPROJ_PATH=${1:-"test-examples/TestApp/TestApp.csproj"}
IMAGE_NAME=${2:-"nilsree/dotnet-cicd-docker"}
IMAGE_TAG=${3:-"dev"}

echo "Building Docker image locally (development only)..."
echo "CSPROJ_PATH: $CSPROJ_PATH"
echo "IMAGE_NAME: $IMAGE_NAME"
echo "IMAGE_TAG: $IMAGE_TAG"
echo ""
echo "⚠️  For production builds, use GitHub Actions by creating a release!"
echo ""

# Build the Docker image
docker build \
  --build-arg CSPROJ_PATH="$CSPROJ_PATH" \
  -t "$IMAGE_NAME:$IMAGE_TAG" \
  .

if [ $? -eq 0 ]; then
    echo "Docker image built successfully!"
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo ""
    echo "⚠️  IMPORTANT: Remember to set SA_PASSWORD environment variable!"
    echo ""
    echo "To run the container locally:"
    echo "docker run -d --name dotnet-cicd-docker \\"
    echo "  -p 8080:80 -p 1433:1433 \\"
    echo "  -v mssql-data:/var/opt/mssql/data \\"
    echo "  -e SA_PASSWORD=YourStrong@Passw0rd123 \\"
    echo "  -e ACCEPT_EULA=Y \\"
    echo "  -e DOTNET_ENVIRONMENT=Development \\"
    echo "  $IMAGE_NAME:$IMAGE_TAG"
    echo ""
    echo "🚀 For production: Create a release on GitHub to trigger automatic Docker Hub publishing!"
    echo "📖 See GITHUB-ACTIONS-SETUP.md for details"
else
    echo "Docker build failed!"
    exit 1
fi

#!/bin/bash
set -e

# Sentinel Linux - One-Command Deployment Script

# Configuration
# Default to current user/repo if git is available, otherwise user must set it
REPO_NAME=$(git config --get remote.origin.url | sed 's/.*github.com[:\/]\(.*\).git/\1/' || echo "")

if [ -z "$REPO_NAME" ]; then
    echo "Error: Could not detect GitHub repository name from git config."
    echo "Please export REPO_NAME='owner/repo' before running this script."
    exit 1
fi

IMAGE_NAME="ghcr.io/$REPO_NAME:main"
# Lowercase image name
IMAGE_NAME=$(echo "$IMAGE_NAME" | tr '[:upper:]' '[:lower:]')

echo "---------------------------------------------------"
echo "Deploying Sentinel Linux Agent"
echo "Repository: $REPO_NAME"
echo "Image:      $IMAGE_NAME"
echo "---------------------------------------------------"

# 1. Update Code
echo "[1/4] Updating repository..."
git pull

# 2. Pull latest Docker image
echo "[2/4] Pulling latest image..."
export IMAGE_NAME
sudo -E docker compose -f docker-compose.prod.yml pull

# 3. Stop existing services
echo "[3/4] Stopping existing services..."
sudo -E docker compose -f docker-compose.prod.yml down

# 4. Start services
echo "[4/4] Starting services..."
sudo -E docker compose -f docker-compose.prod.yml up -d

echo "---------------------------------------------------"
echo "Deployment Complete!"
echo "Check logs with: sudo docker compose -f docker-compose.prod.yml logs -f sentinel-agent"

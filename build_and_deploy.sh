#!/bin/bash
set -e

# Sentinel Linux - Build and Deploy Script (Local Development)

echo "---------------------------------------------------"
echo "Building and Deploying Sentinel Linux Agent (Local)"
echo "---------------------------------------------------"

# 1. Build the Docker image locally
echo "[1/3] Building Docker image..."
# Use the same image name variable logic or just let docker-compose handle it via .env
docker compose -f docker-compose.prod.yml build

# 2. Stop existing services
echo "[2/3] Stopping existing services..."
docker compose -f docker-compose.prod.yml down

# 3. Start services
echo "[3/3] Starting services..."
docker compose -f docker-compose.prod.yml up -d

echo "---------------------------------------------------"
echo "Deployment Complete!"
echo "Check logs with: docker compose -f docker-compose.prod.yml logs -f sentinel-agent"

# Deployment Guide for Sentinel Linux Agent

This guide details how to deploy the Sentinel Linux Agent on a target Linux machine (Ubuntu/Debian preferred).

## Prerequisites

*   A Linux machine (VM or physical) running Ubuntu 20.04/22.04 LTS.
*   Root or sudo access.
*   Docker & Docker Compose installed.

## 1. Install Docker & Docker Compose (if not already installed)

Run the following commands on your Linux machine:

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
sudo docker --version
sudo docker compose version
```

## 2. Prepare the Environment

Transfer the project files to your Linux machine. You can use `git` (if hosted) or `scp`/`rsync`.

Assuming you are in the project directory `Sentinel.AgentLinux/`:

```bash
# Create project directory on target
mkdir -p ~/sentinel-agent
cd ~/sentinel-agent
```

Copy the following files/directories to `~/sentinel-agent`:
*   `Dockerfile`
*   `docker-compose.yml`
*   `scripts/`
*   `configs/`

## 3. Deployment

### Option A: One-Command Automated Deployment (Recommended)

This method pulls the pre-built image from the GitHub Container Registry (GHCR) configured in the CI pipeline.

1.  Run the deployment script:
    ```bash
    ./deploy.sh
    ```

### Option B: Build Locally

Build and start the agent using the standard Docker Compose file.

```bash
# Navigate to the directory
cd ~/sentinel-agent

# Build and start in detached mode
sudo docker compose up -d --build
```

## 4. Verification

1.  **Check Status**: Ensure all containers are running.
    ```bash
    sudo docker compose ps
    ```

2.  **Check Agent Logs**:
    ```bash
    sudo docker compose logs -f sentinel-agent
    ```
    You should see:
    *   [INFO] Starting rsyslog...
    *   [INFO] Starting Sysmon...
    *   [INFO] Starting Fluent Bit...

3.  **Verify Kafka Data** (if running the full stack):
    ```bash
    sudo docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic linux-logs --from-beginning
    ```

## 5. Troubleshooting

*   **Sysmon fails to start**: Ensure the container is running with `--privileged`.
*   **No logs in Kafka**: Check if `rsyslog` is running in the container:
    ```bash
    sudo docker compose exec sentinel-agent ps aux
    ```
    Ensure `/var/log/syslog` exists and is being written to.

## 6. Architecture Note
This deployment runs a local Kafka broker for demonstration. For production, update `configs/fluent-bit.conf` to point to your remote Kafka cluster and remove the `zookeeper` and `kafka` services from `docker-compose.yml`.

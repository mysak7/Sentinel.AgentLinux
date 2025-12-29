# Sentinel Linux - DevOps Project Specification

## 1. Project Overview
Sentinel Linux is a containerized security agent built using core DevOps principles:
1.  **Immutability**: The agent environment (OS, dependencies, configs) is baked into a Docker image.
2.  **Infrastructure as Code (IaC)**: The environment is defined in `Dockerfile` and `docker-compose.yml`.
3.  **CI/CD**: A GitHub Actions pipeline ensures code quality (linting) and security (scanning) on every change.

## 2. Architecture

### 2.1 The Agent Container
*   **Base Image**: Ubuntu 22.04 LTS
*   **Components**:
    *   **Sysmon for Linux**: Kernel-level monitoring (Process Create, Network Connect). Requires `--privileged` flag and debugfs mounts.
    *   **Fluent Bit**: Log processor. Reads Sysmon logs from `/var/log/syslog` (or journald) and forwards to Kafka.
    *   **Orchestrator**: A bash script (`orchestrator.sh`) that acts as the container entrypoint, managing the startup of Sysmon and Fluent Bit.

### 2.2 The Data Pipeline
`Sysmon (Kernel) -> Syslog/Journald -> Fluent Bit (Container) -> Kafka (Remote/Host)`

### 2.3 Directory Structure
```
linux-agent/
├── configs/
│   ├── sysmon.xml        # Security monitoring rules
│   └── fluent-bit.conf   # Log routing configuration
├── scripts/
│   └── orchestrator.sh   # Startup and management script
├── Dockerfile            # The build definition
└── docker-compose.yml    # Local development environment (Kafka + Agent)
```

## 3. DevOps Implementation

### CI/CD Pipeline (`.github/workflows/linux-ci.yml`)
The pipeline runs on every push:
1.  **Linting**:
    *   `hadolint`: Checks Dockerfile for best practices (e.g., pinning versions, cleaning apt cache).
    *   `shellcheck`: Static analysis for the bash orchestrator script.
2.  **Build**: Compiles the Docker image.
3.  **Scan**: Uses `trivy` to scan the built image for known CVEs (Common Vulnerabilities and Exposures).

## 4. Running the Project

### Prerequisites
*   Docker & Docker Compose
*   Linux Host (for full Sysmon functionality) OR Windows WSL2 with a custom kernel (advanced).

### Quick Start
```bash
cd linux-agent
docker-compose up -d
```
This starts:
1.  Zookeeper
2.  Kafka (accessible at localhost:9092)
3.  Sentinel Linux Agent (monitoring the container/host)

### Viewing Logs
To verify the pipeline is working, check the Kafka topic:
```bash
docker-compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic linux-logs --from-beginning
```

## 5. Project Scripts

This project includes several shell scripts to handle building, deploying, and running the agent.

### Deployment & Build
| Script | Environment | Description |
| :--- | :--- | :--- |
| **`build_and_deploy.sh`** | **Local Dev** | **Builds** the Docker image locally from source and restarts containers. Use this for rapid iteration when modifying code. |
| **`deploy.sh`** | **Production** | **Pulls** the latest pre-built image from the container registry (GHCR) and restarts containers. Updates the git repository first. Uses `docker-compose.prod.yml`. |

### Internal Utilities
*   **`scripts/orchestrator.sh`**: The container entrypoint. It handles runtime configuration (injecting environment variables into config templates) and manages the startup of rsyslog, Sysmon, and Fluent Bit.
*   **`test_config_gen.sh`**: A utility script to verify the variable substitution logic (used in `orchestrator.sh`) works correctly without needing to run the full container.


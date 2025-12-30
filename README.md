# Linux Log Agent

This agent monitors system logs on Linux (Debian/Ubuntu) and forwards them to a Kafka topic for threat analysis.

## Prerequisites

*   Python 3.6+
*   `pip` package manager
*   Access to system logs (may require sudo privileges)
*   A Kafka cluster (e.g., Confluent Cloud)

## Installation

1.  **Clone the repository** (if applicable) or navigate to the project directory.

2.  **Install dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

## Configuration

1.  **Create the environment file**:
    Copy the example configuration to a new file named `.env`:
    ```bash
    cp .env.example .env
    ```

2.  **Edit the `.env` file**:
    Fill in your Kafka cluster details:
    ```ini
    BOOTSTRAP_SERVER=your_kafka_bootstrap_server:9092
    PRODUCER_API_KEY=your_api_key
    PRODUCER_API_SECRET=your_api_secret
    ```

## Usage

Run the agent with Python. Note that reading system logs like `/var/log/auth.log` usually requires root privileges.

```bash
sudo python3 agent.py
```

The agent will start monitoring the configured log files and stream new entries to the `threats` Kafka topic.

## Running as a Service (Systemd)

To run the agent in the background as a system service (automatically starts on boot), use the provided helper script:

1.  **Install the service**:
    ```bash
    sudo ./manage_service.sh install
    ```

2.  **Check status**:
    ```bash
    systemctl status sentinel-agent
    ```

3.  **View logs**:
    ```bash
    journalctl -u sentinel-agent -f
    ```

4.  **Uninstall the service**:
    ```bash
    sudo ./manage_service.sh uninstall
    ```

## Log Files Monitored

By default, the agent monitors:
*   `/var/log/auth.log` (Authentication logs)
*   `/var/log/syslog` (System logs)
*   `/var/log/kern.log` (Kernel logs)

To modify this, edit the `LOG_FILES` list in `agent.py`. For RHEL/CentOS systems, you may need to change these to `/var/log/secure` and `/var/log/messages`.

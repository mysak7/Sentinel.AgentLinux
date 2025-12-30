#!/bin/bash

SERVICE_NAME="sentinel-agent"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

install_service() {
    echo "Installing $SERVICE_NAME service..."

    # Check if venv exists
    if [ ! -d "$SCRIPT_DIR/venv" ]; then
        echo "Error: Virtual environment not found at $SCRIPT_DIR/venv"
        echo "Please run ./setup.sh first."
        exit 1
    fi

    # Check if .env exists
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        echo "Error: .env file not found at $SCRIPT_DIR/.env"
        echo "Please configure your environment variables first."
        exit 1
    fi

    # Create systemd service file
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Sentinel Linux Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/venv/bin/python $SCRIPT_DIR/agent.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    echo "Created $SERVICE_FILE"

    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start service
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    
    echo "Service installed and started successfully."
    echo "Check status with: systemctl status $SERVICE_NAME"
    echo "View logs with: journalctl -u $SERVICE_NAME -f"
}

uninstall_service() {
    echo "Uninstalling $SERVICE_NAME service..."
    
    # Stop and disable if running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
    fi
    systemctl disable "$SERVICE_NAME" 2>/dev/null
    
    # Remove service file
    if [ -f "$SERVICE_FILE" ]; then
        rm "$SERVICE_FILE"
        echo "Removed $SERVICE_FILE"
    else
        echo "Service file not found."
    fi
    
    systemctl daemon-reload
    echo "Service uninstalled."
}

case "$1" in
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    *)
        echo "Usage: $0 {install|uninstall}"
        exit 1
        ;;
esac

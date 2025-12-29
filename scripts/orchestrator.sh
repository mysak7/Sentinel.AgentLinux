#!/bin/bash
set -e

# Sentinel Linux - Container Orchestrator
# Starts Sysmon and Fluent Bit

CONFIG_DIR="/opt/sentinel/configs"
SYSMON_CONFIG="$CONFIG_DIR/sysmon.xml"
FLUENT_BIT_CONFIG="$CONFIG_DIR/fluent-bit.conf"

echo "[INFO] Starting Sentinel Linux Agent..."

# 1. Start rsyslog
echo "[INFO] Starting rsyslog..."
service rsyslog start

# 2. Start Sysmon
if command -v sysmon &> /dev/null; then
    echo "[INFO] Starting Sysmon..."
    # We accept the EULA automatically
    sysmon -accepteula -i "$SYSMON_CONFIG" || echo "[WARN] Sysmon failed to start. Is the container privileged?"
else
    echo "[ERROR] Sysmon binary not found!"
    exit 1
fi

# 3. Start Fluent Bit
if command -v fluent-bit &> /dev/null; then
    echo "[INFO] Starting Fluent Bit..."
    # Run in background so we can monitor it or just exec it
    # Ideally, we want this to be the main process.
    exec fluent-bit -c "$FLUENT_BIT_CONFIG"
else
    echo "[ERROR] Fluent Bit binary not found!"
    exit 1
fi

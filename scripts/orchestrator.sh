#!/bin/bash
set -e

# Sentinel Linux - Container Orchestrator
# Starts Sysmon and Fluent Bit

CONFIG_DIR="/opt/sentinel/configs"
SYSMON_CONFIG="$CONFIG_DIR/sysmon.xml"
FLUENT_BIT_CONFIG="$CONFIG_DIR/fluent-bit.conf"
FLUENT_BIT_TPL="$CONFIG_DIR/agent-config.tpl"

echo "[INFO] Starting Sentinel Linux Agent..."

# --- Configuration Generation ---

# Load .env if present (useful for local testing)
if [ -f "/opt/sentinel/.env" ]; then
    echo "[INFO] Loading .env file..."
    # Export variables from .env, ignoring comments
    set -a
    . /opt/sentinel/.env
    set +a
fi

# Generate Fluent Bit Config if template exists
if [ -f "$FLUENT_BIT_TPL" ]; then
    echo "[INFO] Generating Fluent Bit configuration from template..."
    
    # Check for required variables
    if [ -z "$PRODUCER_API_KEY" ] || [ -z "$PRODUCER_API_SECRET" ] || [ -z "$BOOTSTRAP_SERVER" ]; then
        echo "[WARN] One or more Kafka credentials (PRODUCER_API_KEY, PRODUCER_API_SECRET, BOOTSTRAP_SERVER) are missing."
        echo "[WARN] Using placeholders or default environment variables."
    fi

    # Escape special characters for sed if necessary, but for now simple replacement
    # Using python or perl would be safer for complex passwords, but sticking to bash/sed as standard
    # Use | as delimiter to avoid issues with / in URLs
    
    cp "$FLUENT_BIT_TPL" "$FLUENT_BIT_CONFIG"
    
    sed -i "s|{{KAFKA_USER}}|$PRODUCER_API_KEY|g" "$FLUENT_BIT_CONFIG"
    sed -i "s|{{KAFKA_PASS}}|$PRODUCER_API_SECRET|g" "$FLUENT_BIT_CONFIG"
    sed -i "s|{{BROKER_URL}}|$BOOTSTRAP_SERVER|g" "$FLUENT_BIT_CONFIG"
    
    echo "[INFO] Configuration generated at $FLUENT_BIT_CONFIG"
else
    echo "[INFO] No template found at $FLUENT_BIT_TPL. Using existing $FLUENT_BIT_CONFIG if it exists."
fi

# --- End Configuration Generation ---

# 1. Start rsyslog
echo "[INFO] Starting rsyslog..."
if [ -f /etc/init.d/rsyslog ]; then
    /etc/init.d/rsyslog start
elif command -v rsyslogd &> /dev/null; then
    rsyslogd
else
    echo "[WARN] rsyslog not found or not startable"
fi

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
# Add /opt/fluent-bit/bin to PATH just in case, though Dockerfile ENV should handle it
export PATH="/opt/fluent-bit/bin:$PATH"

if command -v fluent-bit &> /dev/null; then
    echo "[INFO] Starting Fluent Bit..."
    # Run in background so we can monitor it or just exec it
    # Ideally, we want this to be the main process.
    exec fluent-bit -c "$FLUENT_BIT_CONFIG"
elif [ -f "/opt/fluent-bit/bin/fluent-bit" ]; then
    echo "[INFO] Starting Fluent Bit (explicit path)..."
    exec /opt/fluent-bit/bin/fluent-bit -c "$FLUENT_BIT_CONFIG"
else
    echo "[ERROR] Fluent Bit binary not found!"
    exit 1
fi

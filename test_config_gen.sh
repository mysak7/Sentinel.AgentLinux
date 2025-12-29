#!/bin/bash
# Test script to verify configuration generation logic

# Create a dummy template
cat > test_agent_config.tpl <<EOF
[OUTPUT]
    Name        kafka
    Brokers     {{BROKER_URL}}
    rdkafka.sasl.username     {{KAFKA_USER}}
    rdkafka.sasl.password     {{KAFKA_PASS}}
EOF

# Set dummy environment variables
export PRODUCER_API_KEY="my-api-key"
export PRODUCER_API_SECRET="my-secret-key-with-special-chars/&"
export BOOTSTRAP_SERVER="pkc-12345.region.cloud.confluent.io:9092"

FLUENT_BIT_TPL="test_agent_config.tpl"
FLUENT_BIT_CONFIG="test_fluent_bit.conf"

echo "Testing substitution..."

cp "$FLUENT_BIT_TPL" "$FLUENT_BIT_CONFIG"

sed -i "s|{{KAFKA_USER}}|$PRODUCER_API_KEY|g" "$FLUENT_BIT_CONFIG"
sed -i "s|{{KAFKA_PASS}}|$PRODUCER_API_SECRET|g" "$FLUENT_BIT_CONFIG"
sed -i "s|{{BROKER_URL}}|$BOOTSTRAP_SERVER|g" "$FLUENT_BIT_CONFIG"

echo "--- Generated Config ---"
cat "$FLUENT_BIT_CONFIG"

# Cleanup
rm test_agent_config.tpl test_fluent_bit.conf

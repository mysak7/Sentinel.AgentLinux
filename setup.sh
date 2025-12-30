#!/bin/bash

# Update package lists
sudo apt update

# Install rsyslog and python3-venv
sudo apt install -y rsyslog python3-venv

# Enable rsyslog to start on boot
sudo systemctl enable rsyslog
sudo systemctl start rsyslog

# Install Python requirements
if [ -f "requirements.txt" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv

    echo "Installing requirements from requirements.txt..."
    ./venv/bin/pip install -r requirements.txt

    echo ""
    echo "Setup complete."
    echo "To run the agent:"
    echo "1. Copy .env.example to .env and configure it"
    echo "2. Run: source venv/bin/activate"
    echo "3. Run: python agent.py"
else
    echo "requirements.txt not found!"
fi

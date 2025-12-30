#!/bin/bash

# Update package lists
sudo apt update

# Install rsyslog
sudo apt install -y rsyslog

# Enable rsyslog to start on boot
sudo systemctl enable rsyslog
sudo systemctl start rsyslog

# Install Python requirements
if [ -f "requirements.txt" ]; then
    echo "Installing requirements from requirements.txt..."
    pip install -r requirements.txt
else
    echo "requirements.txt not found!"
fi

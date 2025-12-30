#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found!"
    echo "Please run ./setup.sh first to create the environment and install dependencies."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Run the agent
echo "Starting Sentinel Agent..."
python agent.py "$@"

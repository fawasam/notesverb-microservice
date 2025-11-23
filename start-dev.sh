#!/bin/bash

# Function to run a command in a new Terminal tab
run_in_tab() {
    local DIR=$1
    local CMD=$2
    local NAME=$3
    local ABS_DIR="$PWD/$DIR"
    
    osascript -e "tell application \"Terminal\"
        activate
        tell application \"System Events\" to keystroke \"t\" using command down
        delay 0.5
        do script \"cd '$ABS_DIR' && $CMD\" in front window
    end tell"
}

# Ensure shared dependencies are installed
echo "Checking shared dependencies..."
if [ ! -d "shared/node_modules" ]; then
    echo "Installing dependencies in shared directory..."
    cd shared && npm install
    cd ..
else
    echo "Shared dependencies found."
fi

# Open the first service in the current window (or a new one if we want to keep the runner separate)
# Let's open everything in new tabs/windows to keep the runner clean.

echo "Starting services..."

# Auth Service
run_in_tab "services/auth-service" "npm run dev" "Auth Service"

# User Service
run_in_tab "services/user-service" "npm run dev" "User Service"

# Notes Service
run_in_tab "services/notes-service" "npm run dev" "Notes Service"

# Tags Service
run_in_tab "services/tags-service" "npm run dev" "Tags Service"

# API Gateway
run_in_tab "api-gateway" "npm run dev" "API Gateway"

echo "All services have been triggered to start in new tabs."

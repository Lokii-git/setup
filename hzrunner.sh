#!/bin/bash

echo "[+] Paste your Horizon curl command (right-click to paste in terminal):"
read -r HORIZON_CURL

# Extract the URL from the provided curl command
HORIZON_URL=$(echo "$HORIZON_CURL" | grep -oP '(?<=curl ")[^"]+')

# Validate if we extracted a URL
if [[ -z "$HORIZON_URL" ]]; then
    echo "[!] Error: Could not extract URL. Please ensure you pasted a valid Horizon curl command."
    exit 1
fi

echo "[+] Extracted URL:"
echo "$HORIZON_URL"

# Run the command in the correct format
echo "[+] Running Horizon script..."
sudo bash -c "$(curl -fsSL '$HORIZON_URL')"

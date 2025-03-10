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

# Run the command with standard curl options
echo "[+] Running Horizon script..."
sudo bash -c "$(curl -fsSL "$HORIZON_URL")"

# Capture exit status
EXIT_CODE=$?

# Check for failure
if [[ $EXIT_CODE -ne 0 ]]; then
    echo "[!] Initial execution failed. Checking for SSL issues..."

    # Retry with -k if it failed due to SSL issues
    SSL_ERROR=$(curl -fsSL "$HORIZON_URL" 2>&1 | grep -i "certificate" || true)

    if [[ -n "$SSL_ERROR" ]]; then
        echo "[!] SSL certificate verification failed. Retrying with -k (insecure mode)..."
        sudo bash -c "$(curl -fsSLk "$HORIZON_URL")"
    else
        echo "[!] Retrying with raw curl command..."
        curl "$HORIZON_URL" | bash
    fi
fi

#!/bin/bash
# Runs default-http-login-hunter on alive hosts
# Author: Philip Burnham
# Purpose: Finds alive hosts and runs default-http-login-hunter against them

# Variables
RESULTS_DIR="http_login_results"
NMAP_RESULTS_FILE="nmap_alive_hosts_scan.nmap"
ALIVE_HOSTS_FILE="alive_hosts.txt"
TOOL_DIR="default-http-login-hunter"
TOOL_REPO="https://github.com/InfosecMatter/default-http-login-hunter.git"
IPLIST="iplist.txt"

# Step 0: Check if iplist.txt exists
if [[ ! -f $IPLIST ]]; then
    echo "Error: $IPLIST file not found."
    exit 1
fi

# Step 1: Check if default-http-login-hunter is downloaded
if [[ ! -d $TOOL_DIR ]]; then
    echo "default-http-login-hunter not found. Cloning from GitHub..."
    git clone "$TOOL_REPO" || { echo "Failed to clone default-http-login-hunter. Exiting."; exit 1; }
    echo "default-http-login-hunter successfully downloaded."
fi

# Ensure the tool script is executable
chmod +x "$TOOL_DIR/default-http-login-hunter.sh"

# Step 2: Create results folder if it doesn't exist
mkdir -p "$RESULTS_DIR"

# Step 3: Scan for alive hosts using nmap
echo "Scanning for alive hosts in $IPLIST..."
nmap -sn -iL "$IPLIST" -oA "$NMAP_RESULTS_FILE" >/dev/null

# Extract alive hosts from the nmap results
grep "Nmap scan report for" "${NMAP_RESULTS_FILE}.nmap" | awk '{print $5}' > "$ALIVE_HOSTS_FILE"

# Check if any alive hosts were found
if [[ ! -s $ALIVE_HOSTS_FILE ]]; then
    echo "No alive hosts found. Exiting."
    exit 0
fi

echo "Alive hosts saved to $ALIVE_HOSTS_FILE."
echo "Starting default-http-login-hunter scans on alive hosts..."

# Step 4: Run default-http-login-hunter against each alive host
while IFS= read -r host; do
    if [[ -n "$host" ]]; then
        OUTPUT_FILE="$RESULTS_DIR/${host//[:]/_}_http_login_results.txt"
        echo "Running default-http-login-hunter against $host..."
        
        # Run the tool and save output while displaying it
        "$TOOL_DIR/default-http-login-hunter.sh" "$host" | tee "$OUTPUT_FILE"
        
        echo "Results for $host saved in $OUTPUT_FILE."
    fi
done < "$ALIVE_HOSTS_FILE"

echo "All scans completed. Results saved in the $RESULTS_DIR folder."

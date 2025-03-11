#!/bin/bash
# Test SSL on iplist.txt
# Author: Philip Burnham
# Purpose: NMAP scan of alive hosts, and runs testssl.sh against each IP.

# Variables
RESULTS_DIR="testssl_results"
NMAP_RESULTS_FILE="nmap_alive_hosts_scan.nmap"
ALIVE_HOSTS_FILE="alive_hosts.txt"
TESTSSL_DIR="testssl.sh"
TESTSSL_REPO="https://github.com/drwetter/testssl.sh.git"
IPLIST="iplist.txt"

# Step 0: Check if iplist.txt exists
if [[ ! -f $IPLIST ]]; then
    echo "Error: $IPLIST file not found."
    exit 1
fi

# Step 1: Check if testssl.sh is downloaded
if [[ ! -d $TESTSSL_DIR ]]; then
    echo "testssl.sh not found. Cloning from GitHub..."
    git clone "$TESTSSL_REPO" || { echo "Failed to clone testssl.sh. Exiting."; exit 1; }
    echo "testssl.sh successfully downloaded."
fi

# Ensure testssl.sh is executable
chmod +x "$TESTSSL_DIR/testssl.sh"

# Step 2: Create results folders if they don't exist
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
echo "Starting testssl.sh scans on alive hosts..."

# Step 4: Run testssl.sh against each alive host
while IFS= read -r host; do
    # Check if the host is not empty
    if [[ -n "$host" ]]; then
        # Define the output file
        OUTPUT_FILE="$RESULTS_DIR/${host//[:]/_}_testssl.txt"
        
        echo "Running testssl.sh against $host..."
        
        # Run testssl.sh and save the output while displaying it on screen
        "$TESTSSL_DIR/testssl.sh" --openssl=/usr/bin/openssl --outfile="$OUTPUT_FILE" -n=none -S -U "$host" | tee "$OUTPUT_FILE"
        
        echo "Results for $host saved in $OUTPUT_FILE."
    fi
done < "$ALIVE_HOSTS_FILE"

echo "All scans completed. Results saved in the $RESULTS_DIR folder."

# Step 5: Parse results with Python script
python3 testsslenum.py

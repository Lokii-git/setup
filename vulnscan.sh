#!/bin/bash
# Eternal Blue Scanner
# Author: Philip Burnham
# Purpose: Uses metasploit to run vulnerability scans against each IP, automating the process.

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo."
    exit 1
fi

echo "[*] Checking for Metasploit Framework installation..."
# Check for Metasploit Framework installation
if ! command -v msfconsole &> /dev/null; then
    echo "Metasploit Framework not installed. Installing now..."
    sudo apt update && sudo apt install -y metasploit-framework
    if [ $? -ne 0 ]; then
        echo "Failed to install Metasploit Framework. Exiting."
        exit 1
    fi
fi

# Check for Nmap installation
echo "[*] Checking for Nmap installation..."
if ! command -v nmap &> /dev/null; then
    echo "Nmap not installed. Installing now..."
    sudo apt update && sudo apt install -y nmap
    if [ $? -ne 0 ]; then
        echo "Failed to install Nmap. Exiting."
        exit 1
    fi
fi

# Check for required input file
input_file="iplist.txt"
if [ ! -f "$input_file" ]; then
    echo "Input file '$input_file' not found. Exiting."
    exit 1
fi

# Set variables
results_dir="metasploit_results"
nmap_smb_scan="nmap_smb_alive"
alive_hosts_445="$results_dir/alive_hosts.txt"
msf_log="$results_dir/metasploit_scan.log"

# Create results directory if needed
echo "[*] Creating results directory..."
mkdir -p "$results_dir"

# Run Nmap SMB scan if results do not exist
if [ ! -f "$nmap_smb_scan.gnmap" ]; then
    echo "[*] Running Nmap SMB scan..."
    nmap -p 445 --open -iL "$input_file" -oA "$nmap_smb_scan"
    if [ $? -ne 0 ]; then
        echo "Nmap scan failed. Exiting."
        exit 1
    fi
fi

# Extract hosts with port 445 explicitly open
echo "[*] Extracting alive hosts with port 445 open..."
awk '/445\/open/{print $2}' "$nmap_smb_scan.gnmap" | sort -u > "$alive_hosts_445"

# Check if any hosts found
if [ ! -s "$alive_hosts_445" ]; then
    echo "No hosts with port 445 open. Exiting."
    exit 1
fi

# Generate Metasploit resource script
echo "[*] Generating Metasploit resource script..."
cat << EOF > "$results_dir/eternalblue_scan.rc"
spool $results_dir/metasploit_scan.log
use auxiliary/scanner/smb/smb_ms17_010
set RHOSTS file:$results_dir/alive_hosts.txt
run
spool off
exit
EOF

# Display config for screenshots
echo "[*] Metasploit Configuration (resource script):"
cat "$results_dir/eternalblue_scan.rc"

#!/bin/bash
# Eternal Blue Scanner
# Author: Philip Burnham
# Purpose: Uses metasploit to run vulnerability scans against each IP, automating the process.

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Check for required tools
if ! command -v nmap &>/dev/null || ! command -v msfconsole &>/dev/null; then
    echo "Nmap or Metasploit Framework not installed. Please install them first."
    exit 1
fi

# Set variables
input_file="iplist.txt"
results_dir="metasploit_results"
nmap_smb_scan="nmap_smb_alive"
all_alive_hosts="all_alive_hosts.txt"
alive_hosts_445="$results_dir/alive_hosts.txt"
msf_log="$results_dir/metasploit_scan.log"

# Ensure input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file 'iplist.txt' not found. Please create the file and list IPs or networks."
    exit 1
fi

# Create results directory if it doesn't exist
mkdir -p "$results_dir"

# Check if Nmap SMB scan already exists
if [ -f "$nmap_smb_scan.gnmap" ]; then
    echo "Nmap SMB scan results already exist at '$nmap_smb_scan.gnmap'. Skipping Nmap scan."
else
    echo "Running Nmap to identify alive hosts with port 445 open..."
    nmap -p445 --open -iL "$input_file" -oA "$nmap_smb_scan"
fi

# Extract alive hosts from Nmap SMB scan
awk '/Up$/{print $2}' "$nmap_smb_scan.gnmap" > "$alive_hosts_445"

# Check for alive hosts with port 445 open
if [ ! -s "$alive_hosts_445" ]; then
    echo "No hosts with port 445 open were found."
    echo "Scanning for any alive hosts for demonstration purposes..."
    nmap -sn -iL "$input_file" -oG - | awk '/Up$/{print $2}' > "$all_alive_hosts"

    if [ -s "$all_alive_hosts" ]; then
        echo "Using an alive host for demonstration testing."
        single_ip=$(head -n 1 "$all_alive_hosts")
        echo "$single_ip" > "$alive_hosts_445"
    else
        echo "No alive hosts were found in the input. Exiting."
        exit 1
    fi
else
    echo "Found the following hosts with port 445 open:"
    cat "$alive_hosts_445"
fi

# Create a Metasploit resource script
msf_resource="$results_dir/metasploit_script.rc"
echo "Generating Metasploit resource script..."

cat > "$msf_resource" <<EOL
spool $msf_log
use auxiliary/scanner/smb/smb_ms17_010
set RHOSTS file:$alive_hosts_445
run
spool off
exit
EOL

# Display Metasploit configuration for screenshots
echo "Metasploit Configuration (resource script):"
cat "$msf_resource"
echo "--------------------------------------------"
read -p "Press Enter to continue with Metasploit execution..."

# Run Metasploit Framework
echo "Starting Metasploit scan..."
msfconsole -q -r "$msf_resource"

echo "Metasploit scan completed. Results saved in '$results_dir'."

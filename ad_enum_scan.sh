#!/bin/bash

# Define variables
INPUT_FILE="iplist.txt"             # Input file containing a list of IPs or subnets to scan
NMAP_OUTPUT="ad_scan_results"       # Base name for Nmap output files (no extension)
ENUM_OUTPUT="enum4linux_results"    # Output directory for enum4linux results

# Ensure the output directory exists
mkdir -p "$ENUM_OUTPUT"

# Step 1: Check if the Nmap scan results already exist
if [[ -f "$NMAP_OUTPUT.gnmap" ]]; then
  echo "[*] Nmap scan results found. Using existing data from $NMAP_OUTPUT.gnmap"
else
  # Run Nmap scan if no previous results are found
  echo "[*] Running Nmap scan for Active Directory and file servers..."
  nmap -p 88,135,139,389,445,464,636,3268,3269 -sV -iL "$INPUT_FILE" -oA "$NMAP_OUTPUT" --open
  echo "[*] Nmap scan complete. Results saved to $NMAP_OUTPUT.gnmap"
fi

# Step 2: Parse the .gnmap file for IPs with Active Directory and SMB-related services
echo "[*] Analyzing results for Active Directory and SMB services..."

# Debug: Print lines containing open ports to check format
grep "Ports:.*open" "$NMAP_OUTPUT.gnmap"

# Extract IPs of interest based on open ports (using regex for common AD and SMB services)
grep "Ports:.*open.*\(microsoft-ds\|msrpc\|ldap\|kerberos\|netbios-ssn\)" "$NMAP_OUTPUT.gnmap" | awk '{print $2}' | sort -u > ad_file_servers.txt

# Check if ad_file_servers.txt was populated
if [[ ! -s ad_file_servers.txt ]]; then
  echo "[!] No Active Directory or file servers found. Exiting."
  exit 1
fi

echo "[*] Identified potential AD/File servers:"
cat ad_file_servers.txt

# Step 3: Run enum4linux on identified AD/File servers
echo "[*] Running enum4linux on identified servers..."
while read -r server_ip; do
  # Skip empty lines and ensure a valid IP format
  if [[ -n "$server_ip" && "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[*] Enumerating $server_ip with enum4linux..."
    enum4linux -a "$server_ip" > "$ENUM_OUTPUT/$server_ip.enum4linux.txt"
    echo "[*] Results saved to $ENUM_OUTPUT/$server_ip.enum4linux.txt"
  else
    echo "[!] Skipping invalid or empty entry: '$server_ip'"
  fi
done < ad_file_servers.txt

echo "[*] Enumeration complete. Results are saved in the '$ENUM_OUTPUT' directory."

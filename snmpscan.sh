#!/bin/bash

# Define variables
IPLIST="iplist.txt"
OUTPUT_DIR="snmp_results"
NMAP_OUTPUT="$OUTPUT_DIR/snmp_scan_results.nmap"
COMMUNITY_LIST="$OUTPUT_DIR/community_strings.txt"
SNMP_PORT=161
SNMP_VERSION="1"

# Default SNMP community string wordlist
DEFAULT_COMMUNITIES=(
    "public"
    "private"
    "manager"
    "admin"
    "read-only"
    "readwrite"
    "default"
    "root"
    "system"
)

# Create results directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Step 1: Generate the community strings wordlist
echo "Generating SNMP community string wordlist..."
> "$COMMUNITY_LIST"  # Clear any existing file
for word in "${DEFAULT_COMMUNITIES[@]}"; do
    echo "$word" >> "$COMMUNITY_LIST"
done
echo "Wordlist created at $COMMUNITY_LIST."

# Step 2: Run Nmap Scan (or skip if already done)
if [[ -f "$NMAP_OUTPUT" ]]; then
    echo "Nmap SNMP scan results already exist at $NMAP_OUTPUT."
else
    echo "Running Nmap to scan for SNMP (UDP port $SNMP_PORT)..."
    nmap -sU -p $SNMP_PORT -iL "$IPLIST" --open -oA "$OUTPUT_DIR/snmp_scan_results"
    echo "Nmap scan completed. Results saved in $OUTPUT_DIR."
fi

# Step 3: Extract IPs with SNMP open or ambiguous state
echo "Extracting IPs to check for SNMP..."
grep -E "Ports: 161/(open|open\|filtered)/udp" "$OUTPUT_DIR/snmp_scan_results.gnmap" | awk -F '[ 	:]+' '{print $2}' > "$OUTPUT_DIR/snmp_open_ips.txt"

echo "IPs to check for SNMP:"
cat "$OUTPUT_DIR/snmp_open_ips.txt"

# Step 4: Brute-force community strings using Nmap's snmp-brute script
echo "Brute-forcing SNMP community strings using Nmap..."
while read -r IP; do
    echo "Brute-forcing SNMP on $IP..."
    nmap -sU -p $SNMP_PORT --script=snmp-brute --script-args=snmp-brute.communitiesdb="$COMMUNITY_LIST" -oN "$OUTPUT_DIR/$IP.snmp_brute.log" "$IP"
done < "$OUTPUT_DIR/snmp_open_ips.txt"
echo "SNMP brute-forcing completed. Check logs in $OUTPUT_DIR."

# Step 5: Run snmp-check on discovered IPs
echo "Running snmp-check on all target IPs..."
while read -r IP; do
    echo "Running snmp-check on $IP..."
    snmp-check -v "$SNMP_VERSION" -t 60 -r 3 -d -w -c "public" "$IP" | tee "$OUTPUT_DIR/$IP.snmp_check.log"
done < "$OUTPUT_DIR/snmp_open_ips.txt"

# Step 6: Run snmpwalk on discovered IPs
echo "Running snmpwalk on all target IPs..."
while read -r IP; do
    echo "Running snmpwalk on $IP..."
    snmpwalk -v2c -c "public" "$IP" | tee "$OUTPUT_DIR/$IP.snmpwalk.log"
done < "$OUTPUT_DIR/snmp_open_ips.txt"

echo "SNMP enumeration completed. Logs are saved in $OUTPUT_DIR."

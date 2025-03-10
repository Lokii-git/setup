#!/bin/bash

# Define variables
IPLIST="iplist.txt"
OUTPUT_DIR="snmp_results"
NMAP_OUTPUT="$OUTPUT_DIR/snmp_scan_results.nmap"
COMMUNITY_LIST="$OUTPUT_DIR/community_strings.txt"
SNMP_PORT=161
SNMP_VERSION="1"
PRIPS_SCRIPT="prips.sh"
PRIPS_URL="https://raw.githubusercontent.com/honzahommer/prips.sh/main/prips.sh"

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

# Ensure the script is run as root/sudo
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (using sudo)." >&2
    exit 1
fi

# Function to download prips.sh if not available
download_prips() {
    if [[ ! -f "$PRIPS_SCRIPT" ]]; then
        echo "Downloading prips.sh from GitHub..."
        curl -fsSL "$PRIPS_URL" -o "$PRIPS_SCRIPT"
        chmod +x "$PRIPS_SCRIPT"
    fi
}

# Function to expand CIDR ranges to IPs using prips.sh
expand_cidr() {
    local input_file="$1"
    local output_file="$2"

    echo "Expanding CIDR ranges to individual IPs using prips.sh..."
    > "$output_file"  # Clear any existing file

    while read -r line; do
        if [[ "$line" == *"/"* ]]; then
            # CIDR range detected, expand it using prips.sh
            ./$PRIPS_SCRIPT "$line" >> "$output_file"
        else
            # Single IP, add it directly
            echo "$line" >> "$output_file"
        fi
    done < "$input_file"

    echo "Expanded IP list saved to $output_file."
}

# Create results directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Step 1: Download prips.sh if not available
download_prips

# Step 2: Generate the community strings wordlist
echo "Generating SNMP community string wordlist..."
> "$COMMUNITY_LIST"  # Clear any existing file
for word in "${DEFAULT_COMMUNITIES[@]}"; do
    echo "$word" >> "$COMMUNITY_LIST"
done
echo "Wordlist created at $COMMUNITY_LIST."

# Step 3: Run Nmap Scan (or skip if already done)
if [[ -f "$NMAP_OUTPUT" ]]; then
    echo "Nmap SNMP scan results already exist at $NMAP_OUTPUT."
else
    echo "Running Nmap to scan for SNMP (UDP port $SNMP_PORT)..."
    nmap -sU -p $SNMP_PORT -iL "$IPLIST" --open -oA "$OUTPUT_DIR/snmp_scan_results"
    echo "Nmap scan completed. Results saved in $OUTPUT_DIR."
fi

# Step 4: Extract IPs with SNMP open or ambiguous state
echo "Extracting IPs to check for SNMP..."
grep -E "161/udp (open|open|filtered)" "$OUTPUT_DIR/snmp_scan_results.gnmap" | awk '{print $2}' > "$OUTPUT_DIR/snmp_open_ips.txt"

# Expand IPs if no clear results found
if [[ ! -s "$OUTPUT_DIR/snmp_open_ips.txt" ]]; then
    echo "No clear SNMP ports found in Nmap scan. Expanding all IPs from iplist.txt..."
    expand_cidr "$IPLIST" "$OUTPUT_DIR/snmp_open_ips.txt"
fi

echo "IPs to check for SNMP:"
cat "$OUTPUT_DIR/snmp_open_ips.txt"

# Step 5: Brute-force community strings using Nmap's snmp-brute script
echo "Brute-forcing SNMP community strings using Nmap..."
while read -r IP; do
    echo "Brute-forcing SNMP on $IP..."
    nmap -sU -p $SNMP_PORT --script=snmp-brute --script-args=snmp-brute.communitiesdb="$COMMUNITY_LIST" -oN "$OUTPUT_DIR/$IP.snmp_brute.log" "$IP"
done < "$OUTPUT_DIR/snmp_open_ips.txt"
echo "SNMP brute-forcing completed. Check logs in $OUTPUT_DIR."

# Step 6: Run snmp-check on discovered IPs
echo "Running snmp-check on all target IPs..."
while read -r IP; do
    echo "Running snmp-check on $IP..."
    snmp-check -v "$SNMP_VERSION" -t 60 -r 3 -d -w -c "public" "$IP" | tee "$OUTPUT_DIR/$IP.snmp_check.log"
done < "$OUTPUT_DIR/snmp_open_ips.txt"

# Step 7: Run snmpwalk on discovered IPs
echo "Running snmpwalk on all target IPs..."
while read -r IP; do
    echo "Running snmpwalk on $IP..."
    snmpwalk -v2c -c "public" "$IP" | tee "$OUTPUT_DIR/$IP.snmpwalk.log"
done < "$OUTPUT_DIR/snmp_open_ips.txt"

echo "SNMP enumeration completed. Logs are saved in $OUTPUT_DIR."

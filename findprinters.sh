#!/bin/bash

# Enhanced Internal Printer Discovery Script
# Author: Philip Burnham
# Purpose: Locate and enumerate printers on internal network

# Input Variables
IP_LIST="iplist.txt"
OUTPUT_DIR="printer_results"
LOG_FILE="$OUTPUT_DIR/printer_scan_$(date +%Y-%m-%d).log"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Install missing tools
install_tools() {
    declare -A tools=(
        ["nmap"]="nmap"
        ["snmpwalk"]="snmp"
        ["snmp-mibs-downloader"]="snmp-mibs-downloader"
        ["parallel"]="parallel"
        ["nc"]="netcat"
        ["unzip"]="unzip"
        ["httpx"]="httpx"
        ["aquatone"]="aquatone"
    )

    for tool in "${!tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "[!] $tool not found, installing..."
            if [[ "$tool" == "httpx" ]]; then
                sudo apt update && sudo apt install -y httpx-toolkit
            elif [[ "$tool" == "aquatone" ]]; then
                wget "https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip" -O /tmp/aquatone.zip
                unzip /tmp/aquatone.zip -d /tmp/aquatone-bin
                sudo mv /tmp/aquatone/aquatone /usr/local/bin/aquatone
                sudo chmod +x /usr/local/bin/aquatone
                rm -rf /tmp/aquatone*
            else
                sudo apt update && sudo apt install -y "${tools[$tool]}"
            fi
        fi
    done
}

# Sanitize IP list
clean_ip_list() {
    sed -i '/^$/d;s/ //g' "$IP_LIST"
}

# Scan common printer ports
scan_printer_ports() {
    echo "[+] Scanning common printer ports..."
    PRINTER_PORTS="80,443,161,515,631,8080,5357,8000,9100-9103"
    while read -r range; do
        safe_range=$(echo "$range" | sed 's/[\/]/_/g')
        nmap -sV --open -p "$PRINTER_PORTS" "$range" -oG "$OUTPUT_DIR/${safe_range}_printer_ports.gnmap" &
    done < "$IP_LIST"
    wait
    grep "Ports" "$OUTPUT_DIR"/*.gnmap | awk '{print $2}' | sort -u > "$OUTPUT_DIR/printer_hosts.txt"
}

# Banner grabbing on port 9100
grab_jetdirect_banners() {
    while read -r host; do
        timeout 5 bash -c "echo | nc -vn $host 9100" &>> "$OUTPUT_DIR/jetdirect_banners.txt" &
    done < "$OUTPUT_DIR/port9100_hosts.txt"
    wait
}

# SNMP Enumeration
snmp_enumeration() {
    local COMMUNITIES=("public" "private" "community" "printers" "read")
    while read -r HOST; do
        for COMM in "${COMMUNITIES[@]}"; do
            snmpwalk -v2c -c "$COMM" "$HOST" 1.3.6.1.2.1.43 &>> "$OUTPUT_DIR/snmp_printers.log" &
        done
    done < "$OUTPUT_DIR/port9100_hosts.txt"
    wait
}

# HTTP Title Grabbing
http_title_grabbing() {
    httpx -l "$OUTPUT_DIR/printer_hosts.txt" -title -status-code -o "$OUTPUT_DIR/http_printer_titles.txt"
}

# Aquatone screenshots
aquatone_screenshots() {
    cat "$OUTPUT_DIR/printer_hosts.txt" | aquatone -out "$OUTPUT_DIR/aquatone_results"
}

# Summarize results
summarize_results() {
    echo "--- Printer Discovery Summary ---" > "$LOG_FILE"
    echo -e "\n--- Discovered Printer IPs ---" >> "$LOG_FILE"
    cat "$OUTPUT_DIR/printer_hosts.txt" >> "$LOG_FILE"
    echo -e "\n--- SNMP Printer Results ---" >> "$LOG_FILE"
    cat "$OUTPUT_DIR/snmp_printers.log" >> "$LOG_FILE"
    echo -e "\n--- HTTP Printer Hosts ---" >> "$LOG_FILE"
    cat "$OUTPUT_DIR/http_printer_titles.txt" >> "$LOG_FILE"
    echo "[+] Summary written to: $LOG_FILE"
}

# Main Execution
if [ ! -f "$IP_LIST" ]; then
    echo "IP list file ($IP_LIST) missing!"; exit 1
fi

install_tools
clean_ip_list
scan_printer_ports
grep -rl '9100/open' "$OUTPUT_DIR"/*.gnmap | xargs -I{} grep "Ports" {} | awk '{print $2}' > "$OUTPUT_DIR/port9100_hosts.txt"
grab_jetdirect_banners
snmp_enumeration
http_title_grabbing
aquatone_screenshots
summarize_results

echo "[+] Printer discovery completed. Results saved in $OUTPUT_DIR."

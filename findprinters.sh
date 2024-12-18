#!/bin/bash

# Internal Printer Discovery Script
# Author: Clearwater
# Purpose: Locate printers on the network during an internal penetration test

# Input Variables
IP_LIST="iplist.txt"   # Text file with IP ranges
OUTPUT_DIR="printer_results"
LOG_FILE="$OUTPUT_DIR/printer_scan_$(date +%F).log"

# Ensure Output Directory Exists
mkdir -p "$OUTPUT_DIR"

# Function to clean carriage return characters from input file
clean_input_file() {
    echo "[+] Cleaning input file to remove carriage returns..."
    sed -i 's/\r//g' "$IP_LIST"
}

# Function to scan for port 9100 (JetDirect)
scan_port9100() {
    echo "[+] Scanning for port 9100 (JetDirect printers)..."
    while read -r IP_RANGE; do
        CLEAN_RANGE=$(echo "$IP_RANGE" | sed 's/\r//g')
        echo "    [-] Scanning range: $CLEAN_RANGE"
        OUTPUT_FILE="$OUTPUT_DIR/port9100_scan_${CLEAN_RANGE//\//_}.txt"
        nmap -sV -p 9100 --open "$CLEAN_RANGE" -oG "$OUTPUT_FILE"
        cat "$OUTPUT_FILE" | grep Ports | awk '{print $2}' >> "$OUTPUT_DIR/port9100_hosts.txt"
    done < "$IP_LIST"
    echo "[+] Port 9100 results saved to: $OUTPUT_DIR/port9100_hosts.txt"
}

# Function to discover printers using SNMP
scan_snmp_printers() {
    echo "[+] Scanning for SNMP printers..."
    while read -r host; do
        echo "    [-] Querying $host via SNMP..."
        snmpwalk -v2c -c public "$host" 1.3.6.1.2.1.43 2>/dev/null | grep "prtMarker" >> "$OUTPUT_DIR/snmp_printers.log"
    done < "$OUTPUT_DIR/port9100_hosts.txt"
    echo "[+] SNMP results saved to: $OUTPUT_DIR/snmp_printers.log"
}

# Function to identify HTTP-based printer interfaces
scan_http_printers() {
    echo "[+] Scanning for HTTP-based printer interfaces..."
    while read -r IP_RANGE; do
        CLEAN_RANGE=$(echo "$IP_RANGE" | sed 's/\r//g')
        echo "    [-] Scanning range: $CLEAN_RANGE"
        OUTPUT_FILE="$OUTPUT_DIR/http_printer_scan_${CLEAN_RANGE//\//_}.txt"
        nmap -sV -p 80,443,8080 --open "$CLEAN_RANGE" -oG "$OUTPUT_FILE"
        cat "$OUTPUT_FILE" | grep Ports | awk '{print $2, $4}' | grep -E "(80|443|8080)/open" >> "$OUTPUT_DIR/http_printer_hosts.txt"
    done < "$IP_LIST"
    echo "[+] HTTP printer results saved to: $OUTPUT_DIR/http_printer_hosts.txt"
}

# Function to summarize findings
summarize_results() {
    echo "[+] Generating printer summary..."
    echo "--- Printer Discovery Summary ---" > "$LOG_FILE"
    echo "\nPort 9100 Printers:" >> "$LOG_FILE"
    cat "$OUTPUT_DIR/port9100_hosts.txt" >> "$LOG_FILE"
    echo "\nSNMP Discovered Printers:" >> "$LOG_FILE"
    cat "$OUTPUT_DIR/snmp_printers.log" >> "$LOG_FILE"
    echo "\nHTTP Interfaces (Potential Printers):" >> "$LOG_FILE"
    cat "$OUTPUT_DIR/http_printer_hosts.txt" >> "$LOG_FILE"
    echo "[+] Summary written to: $LOG_FILE"
}

# Main Execution
if [ ! -f "$IP_LIST" ]; then
    echo "Error: IP list file '$IP_LIST' not found."
    exit 1
fi

clean_input_file
scan_port9100
scan_snmp_printers
scan_http_printers
summarize_results

echo "[+] Printer Discovery Complete. Check logs in: $OUTPUT_DIR"

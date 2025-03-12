# Netexec SMB Enumeration Script
# Author: Philip Burnham
# Purpose: Identifies hosts with SMB Signing Disabled or SMBv1 Enabled

import re
import subprocess
import os
import argparse
import logging
from datetime import datetime

def display_banner():
    banner = r'''
    =============================================
          Netexec SMB Enumeration Tool
    =============================================
    This script scans a list of IP addresses using NetExec
    to detect SMB hosts with the following issues:

    - SMB Signing set to FALSE (disabled)
    - SMBv1 set to TRUE (enabled)

    Results are parsed and saved for easy review.

    Available Flags:
    -i, --iplist    Path to the IP list file (default: iplist.txt)
    -l, --log       Log file for NetExec scan output (default: smb_results.log)
    --cleanup       Clean up old log files after parsing
    =============================================
    '''
    print(banner)

def run_netexec_smb(iplist_file, log_file):
    command = [
        "netexec", "smb", iplist_file, "-t", "10", "--timeout", "5", "--jitter", "2",
        "--verbose", "--log", log_file
    ]
    logging.info("Running NetExec SMB scan...")
    
    try:
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as proc:
            for line in proc.stdout:
                print(line, end="")
    except Exception as e:
        logging.error(f"An error occurred during NetExec execution: {e}")
        exit(1)

    logging.info(f"NetExec results logged to {log_file}")

def parse_netexec_smb(file_path):
    signing_issues = []
    smbv1_issues = []

    signing_false = re.compile(r"signing:\s*False", re.IGNORECASE)
    smbv1_true = re.compile(r"SMBv1:\s*True", re.IGNORECASE)

    try:
        with open(file_path, 'r') as f:
            for line in f:
                if signing_false.search(line):
                    signing_issues.append(line.strip())
                if smbv1_true.search(line):
                    smbv1_issues.append(line.strip())
    except FileNotFoundError:
        logging.error(f"Log file '{file_path}' not found.")
        exit(1)

    return signing_issues, smbv1_issues

def save_parsed_results(output_file, signing_issues, smbv1_issues):
    try:
        with open(output_file, "w") as f:
            f.write("=== SMB Signing Issues ===\n")
            for issue in signing_issues:
                f.write(issue + "\n")
            f.write("\n=== SMBv1 Issues ===\n")
            for issue in smbv1_issues:
                f.write(issue + "\n")
        logging.info(f"Parsed results saved to {output_file}")
    except Exception as e:
        logging.error(f"Failed to save parsed results: {e}")
        exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NetExec SMB Enumeration Tool")
    parser.add_argument("-i", "--iplist", default="iplist.txt", help="Path to the IP list file")
    parser.add_argument("-l", "--log", default="smb_results.log", help="Log file for NetExec scan output")
    parser.add_argument("--cleanup", action="store_true", help="Clean up old log files after parsing")
    args = parser.parse_args()

    logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s', level=logging.INFO)

    display_banner()

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"parsed_results_{timestamp}.log"

    if os.path.exists(args.log):
        logging.info(f"Log file '{args.log}' already exists. Skipping NetExec scan.")
    else:
        run_netexec_smb(args.iplist, args.log)

    signing_issues, smbv1_issues = parse_netexec_smb(args.log)

    if signing_issues or smbv1_issues:
        if signing_issues:
            logging.info("Identified SMB Signing issues:")
            for issue in signing_issues:
                print(issue)
        if smbv1_issues:
            logging.info("Identified SMBv1 issues:")
            for issue in smbv1_issues:
                print(issue)
    else:
        logging.info("No SMB issues detected.")

    save_parsed_results(output_file, signing_issues, smbv1_issues)

    total_issues = len(signing_issues) + len(smbv1_issues)
    logging.info(f"Total issues found: {total_issues}")

    if args.cleanup:
        try:
            os.remove(args.log)
            logging.info(f"Cleaned up log file: {args.log}")
        except Exception as e:
            logging.error(f"Failed to clean up log file: {e}")

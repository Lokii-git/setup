#!/usr/bin/env python3
# Parses default-http-login-hunter results
# Author: Philip Burnham
# Purpose: Extracts useful findings for easy review

import os

# Define directories and output file
RESULTS_DIR = "loginhunter_results"
OUTPUT_FILE = "loginhunter_summary.txt"

def parse_results():
    """Parses result files and extracts login details."""
    findings = []

    for root, _, files in os.walk(RESULTS_DIR):
        for file in files:
            if file.endswith(".txt"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    lines = f.readlines()
                    
                    # Ignore files with only one line (no credentials found)
                    if len(lines) < 2:
                        continue
                    
                    # Extract IP:Port from filename
                    ip_port = file.replace("_http_login_results.txt", "").replace("_", ":")
                    
                    # Collect non-empty lines after the first one
                    creds_found = []
                    for line in lines[1:]:  # Skip first line
                        clean_line = line.strip()
                        if clean_line:  # Ignore empty lines
                            creds_found.append(clean_line)

                    if creds_found:
                        findings.append(f"{ip_port} - Credentials Found:")
                        findings.extend([f"  {cred}" for cred in creds_found])

    return findings

def save_results(findings):
    """Saves formatted results to a text file."""
    with open(OUTPUT_FILE, "w") as f:
        if findings:
            f.write("Default Credentials Found:\n")
            for finding in findings:
                f.write(f"{finding}\n")
        else:
            f.write("No default credentials found.\n")

    print("\n--- SUMMARY REPORT ---")
    if findings:
        for finding in findings:
            print(finding)
    else:
        print("No default credentials found.")

if __name__ == "__main__":
    findings = parse_results()
    save_results(findings)

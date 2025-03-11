#!/usr/bin/env python3
# Parses default-http-login-hunter results
# Author: Philip Burnham
# Purpose: Extracts useful findings for easy review

import os

# Define directories and output file
RESULTS_DIR = "http_login_results"
OUTPUT_FILE = "http_login_summary.txt"

def parse_results():
    """Parses result files and extracts login details."""
    findings = []

    for root, _, files in os.walk(RESULTS_DIR):
        for file in files:
            if file.endswith(".txt"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    lines = f.readlines()
                    
                    # If the file has only one line, skip it (no credentials found)
                    if len(lines) < 2:
                        continue
                    
                    ip_port = file.replace("_http_login_results.txt", "").replace("_", ":")
                    findings.append(f"{ip_port} - Credentials Found:")

                    # Extract login details (all lines except the first)
                    for line in lines[1:]:  
                        clean_line = line.strip()
                        if clean_line:  # Ignore empty lines
                            findings.append(f"  {clean_line}")

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

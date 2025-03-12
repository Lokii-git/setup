import re
import subprocess
import os

def run_netexec_smb(iplist_file, log_file):
    command = [
        "netexec", "smb", iplist_file, "-t", "10", "--timeout", "5", "--jitter", "2",
        "--verbose", "--log", log_file
    ]
    print("Running NetExec SMB scan...")
    
    # Stream NetExec output in real-time
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as proc:
        for line in proc.stdout:
            print(line, end="")
    
    print(f"NetExec results logged to {log_file}\n")

def parse_netexec_smb(file_path):
    results = []

    # Regular expressions for SMB Signing and SMBv1 status in the log file
    signing_false = re.compile(r"signing:\s*False", re.IGNORECASE)
    smbv1_true = re.compile(r"SMBv1:\s*True", re.IGNORECASE)

    with open(file_path, 'r') as f:
        for line in f:
            if signing_false.search(line) or smbv1_true.search(line):
                results.append(line.strip())

    return results

def save_parsed_results(output_file, results):
    with open(output_file, "w") as f:
        for result in results:
            f.write(result + "\n")
    print(f"Parsed results saved to {output_file}\n")

# File paths
iplist_file = "iplist.txt"  # Input file containing IP addresses
log_file = "smb_results.log"  # Log file for NetExec results
output_file = "parsed_results.log"  # Output file for parsed results

# Check if log file exists
if os.path.exists(log_file):
    print(f"Log file '{log_file}' already exists. Skipping NetExec scan.")
else:
    run_netexec_smb(iplist_file, log_file)

# Parse results from log file
parsed_results = parse_netexec_smb(log_file)

# Save parsed results to file and display
save_parsed_results(output_file, parsed_results)
print("Filtered Results (Signing: False or SMBv1: True):\n")
for result in parsed_results:
    print(result)

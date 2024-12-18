import os
import re
import shutil

# Directory containing the testssl.sh result files
RESULTS_DIR = "testssl_results"
OUTPUT_FILE = "expired_certificates_report.txt"
EXPIRED_LOG_DIR = "expired_cert_logs"
VULNERABILITIES_FILE = "vulnerabilities_report.txt"
VULNERABILITY_LOG_DIR = "vulnerability_logs"

# Regular expressions to match expired certificate lines and extract hostname/IP
EXPIRED_CERT_PATTERN = re.compile(r"\b(expired|certificate has expired)\b", re.IGNORECASE)
VULNERABILITY_PATTERN = re.compile(r"(?<!not\s)(?<!no\s)\b(VULNERABLE|potentially VULNERABLE)\b", re.IGNORECASE)
VULN_NAME_PATTERN = re.compile(r"^\x1b\[1m\s*(.*?)\s*\x1b\[m")

def strip_ansi(line):
    """Remove ANSI color codes from a line for clean matching."""
    return re.sub(r'\x1b\[.*?m', '', line)

def get_ip_from_filename(file_path):
    """Extract IP/host from the file name."""
    filename = os.path.basename(file_path)
    return filename.split("_")[0]  # Extract part before '_'

def parse_txt_file(file_path, expired_hosts, log_files, vulnerabilities, vuln_log_files):
    """Parse .txt files for expired certificates and vulnerabilities."""
    host = get_ip_from_filename(file_path)  # Default host from filename
    current_vuln = None

    with open(file_path, "r", encoding="utf-8", errors="ignore") as file:
        for line in file:
            clean_line = strip_ansi(line)  # Strip ANSI codes for clean matching

            if EXPIRED_CERT_PATTERN.search(clean_line):
                expired_hosts.add(host)

            vuln_match = VULNERABILITY_PATTERN.search(clean_line)
            vuln_name_match = VULN_NAME_PATTERN.search(line)  # Keep color for vuln name
            if vuln_name_match:
                current_vuln = vuln_name_match.group(1)

            if vuln_match and current_vuln:
                # Detailed vulnerability message
                print(
                    f"Vulnerability Found: {current_vuln} -> {line.strip()} in {file_path}"
                )
                vulnerabilities.append((file_path, current_vuln, line.strip()))

                # Add the .txt file to the vulnerability log folder
                vuln_log_files.setdefault(current_vuln, set()).add(file_path)

                # Also associate the log file with the vulnerability
                log_file = os.path.join(
                    os.path.dirname(file_path),
                    os.path.basename(file_path).replace(".txt", ".log"),
                )
                if os.path.exists(log_file):
                    vuln_log_files[current_vuln].add(log_file)

    # Add log file to global log list if it exists
    log_file = os.path.join(
        os.path.dirname(file_path), os.path.basename(file_path).replace(".txt", ".log")
    )
    if os.path.exists(log_file):
        log_files.add(log_file)

def copy_log_files(log_files, output_dir):
    """Copy log files of hosts with expired certificates to a new directory."""
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    for log_file in log_files:
        try:
            shutil.copy(log_file, output_dir)
        except Exception as e:
            print(f"Failed to copy {log_file}: {e}")

def copy_vuln_log_files(vuln_log_files, base_output_dir):
    """Copy txt and log files into separate folders named after vulnerabilities."""
    for vuln_name, files in vuln_log_files.items():
        vuln_dir = os.path.join(base_output_dir, vuln_name.replace(" ", "_"))
        if not os.path.exists(vuln_dir):
            os.makedirs(vuln_dir)
        for file in files:
            if os.path.exists(file):
                try:
                    shutil.copy(file, vuln_dir)
                except Exception as e:
                    print(f"Failed to copy {file}: {e}")

def write_vulnerabilities_report(vulnerabilities, output_file):
    """Write vulnerabilities to a report file."""
    with open(output_file, "w") as out:
        if vulnerabilities:
            out.write("Hosts with Vulnerabilities:\n")
            for file_path, vuln_name, details in vulnerabilities:
                out.write(f"{file_path}: {vuln_name} -> {details}\n")
        else:
            out.write("No vulnerabilities found.\n")

def parse_expired_certificates_and_vulns(results_dir, output_file, expired_log_dir, vulnerabilities_file, vuln_log_dir):
    expired_hosts = set()
    log_files = set()
    vulnerabilities = []
    vuln_log_files = {}

    # Iterate through all .txt files in the directory
    for root, _, files in os.walk(results_dir):
        for filename in files:
            if filename.endswith(".txt"):
                file_path = os.path.join(root, filename)
                parse_txt_file(file_path, expired_hosts, log_files, vulnerabilities, vuln_log_files)

    # Write results for expired certificates
    with open(output_file, "w") as out:
        if expired_hosts:
            out.write("Hosts with Expired Certificates:\n")
            for host in sorted(expired_hosts):
                out.write(f"{host}\n")
        else:
            out.write("No expired certificates found.\n")
            print("No expired certificates found.")

    # Copy relevant log files for expired certificates
    if log_files:
        copy_log_files(log_files, expired_log_dir)

    # Write vulnerabilities report and copy logs
    write_vulnerabilities_report(vulnerabilities, vulnerabilities_file)
    copy_vuln_log_files(vuln_log_files, vuln_log_dir)

    # Summary Output
    print(f"Found {len(expired_hosts)} expired certificates.")
    print(f"Found {len(vulnerabilities)} vulnerabilities.")
    print(f"Results saved to {output_file}")
    print(f"Log files copied to {expired_log_dir}")
    print(f"Vulnerabilities saved to {vulnerabilities_file}")
    print(f"Vulnerability logs copied to {vuln_log_dir}")

if __name__ == "__main__":
    parse_expired_certificates_and_vulns(RESULTS_DIR, OUTPUT_FILE, EXPIRED_LOG_DIR, VULNERABILITIES_FILE, VULNERABILITY_LOG_DIR)

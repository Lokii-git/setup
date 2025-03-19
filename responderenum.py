import argparse
import re

def extract_poisoned_hosts(log_file):
    poisoned_hosts = set()
    
    with open(log_file, 'r', encoding='utf-8') as file:
        for line in file:
            match = re.search(r'\[SMB\] NTLMv2-SSP Client\s+:\s+([\da-fA-F:.]+)', line)
            if match:
                poisoned_hosts.add(match.group(1))
    
    return poisoned_hosts

def main():
    parser = argparse.ArgumentParser(description='Extract poisoned hosts from Responder logs.')
    parser.add_argument('-f', '--file', required=True, help='Path to the Responder log file')
    args = parser.parse_args()
    
    poisoned_hosts = extract_poisoned_hosts(args.file)
    
    if poisoned_hosts:
        print("Poisoned hosts found:")
        for host in poisoned_hosts:
            print(host)
        
        with open('poisonedclients.txt', 'w', encoding='utf-8') as output_file:
            for host in poisoned_hosts:
                output_file.write(host + '\n')
        print("Poisoned hosts saved to poisonedclients.txt")
    else:
        print("No poisoned hosts found.")

if __name__ == '__main__':
    main()

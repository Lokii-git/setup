#!/bin/bash
# Internal AD Scan
# Author: Philip Burnham
# Purpose: Ran after ad_enum_scan.sh to do a deeper dive for usernames

IP_LIST="ad_file_servers.txt"
OUTPUT_DIR="enum4linux_results_usernames"
USERNAMES_FILE="extracted_usernames.txt"

mkdir -p "$OUTPUT_DIR"
> "$USERNAMES_FILE"

echo "[*] Running enum4linux with enhanced flags for usernames on each IP..."
while read -r ip; do
  echo "[*] Enumerating $ip..."
  enum4linux -U -G -r "$ip" > "$OUTPUT_DIR/$ip.enum4linux.txt"
done < "$IP_LIST"

# Extract usernames from the updated enum4linux results
echo "[*] Extracting usernames from results..."
for file in "$OUTPUT_DIR"/*.enum4linux.txt; do
  grep -E "User:\s|Group:\s|RID\ cycling|Name:" "$file" | awk '{print $2}' | sort -u >> "$USERNAMES_FILE"
done

# Remove duplicates and empty lines
sort -u "$USERNAMES_FILE" -o "$USERNAMES_FILE"
sed -i '/^$/d' "$USERNAMES_FILE"

echo "[*] Usernames extraction complete. Results saved to $USERNAMES_FILE"
cat "$USERNAMES_FILE"

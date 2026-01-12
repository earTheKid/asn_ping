#!/bin/bash

# Usage: nmap_company.sh <company_keyword>
# Searches ASNs whose names/descriptions match the keyword (BGPView + RIPE Stat),
# then runs nmap port scans across each ASN's routed IP ranges using get_ip_ranges_for_asn.sh.
# Respects MAX_ASNS (default 200) to avoid runaway scans.

if [ -z "$1" ]; then
  echo "please set company keyword (e.g. nmap_company.sh acme)"
  exit 1
fi

keyword="$1"
MAX_ASNS=${MAX_ASNS:-200}

# Scan tuning (override via env):
# PORT_SPEC="80,443,22"  SCAN_OPTS="-Pn -sS --open"  RATE_OPTS="--min-rate 500 --max-retries 1"
# Default covers common web/app, mail, DB, cache, VNC/RDP/WinRM, message queue, and popular admin ports.
PORT_SPEC=${PORT_SPEC:-"21,22,23,25,53,80,110,111,123,135,139,143,389,443,445,465,500,587,631,636,993,995,1433,1521,2049,2375,2376,2379,2380,3000,3128,3306,3389,5000,5432,5671,5672,5900,5985,5986,6379,6443,6666,7001,7002,7443,8000,8008,8080,8081,8088,8089,8161,8443,8500,8880,8888,9000,9001,9090,9200,9300,9443,10000,11211,15672,27017,27018,27019"}
SCAN_OPTS=${SCAN_OPTS:-"-Pn -sS --open"}
RATE_OPTS=${RATE_OPTS:-""}

# Make filenames safe
safe_keyword=$(echo "$keyword" | tr ' /' '__')
month_year=$(date +"%m%Y")
asn_file="./data/${safe_keyword}_${month_year}_company_asns.txt"
output_dir="./results/${safe_keyword}/nmap_output_$(date +"%m%d%y")"
mkdir -p "./data" "$output_dir"

echo "Searching ASNs for keyword: $keyword"

# Ensure dependencies
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is not installed (needed to parse API responses)."
  if command -v brew >/dev/null 2>&1; then
    echo "Install with: brew install jq"
  fi
  exit 1
fi

if ! command -v nmap >/dev/null 2>&1; then
  echo "Error: nmap is not installed."
  if command -v brew >/dev/null 2>&1; then
    echo "Install with: brew install nmap"
  fi
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Warning: nmap -sn may need sudo/root for raw ping/ARP on some systems. Continuing..."
fi

asn_tmp=$(mktemp /tmp/company_asns.XXXXXX)

# Collect ASNs from BGPView search
curl --silent "https://api.bgpview.io/search?query_term=${keyword}" \
  | jq -r '.data.asns[]? | .asn' 2>/dev/null \
  >> "$asn_tmp"

# Collect ASNs from RIPE Stat search (RIPE region only)
curl --silent "https://stat.ripe.net/data/search/data.json?query=${keyword}" \
  | jq -r '.data.resources[]? | select(.type == "asn") | .resource | sub("^AS"; "")' 2>/dev/null \
  >> "$asn_tmp"

# Fallback: use local asn_keyword_search if API results are empty
if [ ! -s "$asn_tmp" ]; then
  echo "API searches returned no results; trying local ASN name search..."
  bash ./asn_keyword_search.sh "$keyword" >> "$asn_tmp"
fi

# Deduplicate (no cap)
sort -u "$asn_tmp" | sed '/^$/d' > "${asn_tmp}.uniq"
asn_count=$(wc -l < "${asn_tmp}.uniq")

if [ "$asn_count" -eq 0 ]; then
  echo "No ASNs found for keyword '$keyword'."
  rm -f "$asn_tmp" "${asn_tmp}.uniq"
  exit 1
fi

mv "${asn_tmp}.uniq" "$asn_file"

rm -f "$asn_tmp"
asn_count_final=$(wc -l < "$asn_file")
echo "Using $asn_count_final ASNs (written to $asn_file)"

# Function to get ASN name from cache or whois
get_asn_name() {
  local asn="$1"
  local asnames_cache="./data/asnames.txt"
  
  # Try cache first
  local cached_name=$(grep "^AS$asn " "$asnames_cache" 2>/dev/null | sed "s/^AS$asn //")
  if [ -n "$cached_name" ]; then
    echo "$cached_name"
    return
  fi
  
  # Fallback: query whois
  local whois_name=$(whois -h whois.radb.net "AS$asn" 2>/dev/null | grep "^as-name:" | head -1 | sed 's/as-name:[[:space:]]*//')
  if [ -n "$whois_name" ]; then
    echo "$whois_name"
    return
  fi
  
  echo "(unknown)"
}

# Function to get ASN country
get_asn_country() {
  local asn="$1"
  
  # Try RIPE Stat API first (most reliable)
  local country=$(curl -s "https://stat.ripe.net/data/as-overview/data.json?resource=AS$asn" 2>/dev/null | jq -r '.data.country // empty' 2>/dev/null)
  if [ -n "$country" ]; then
    echo "$country"
    return
  fi
  
  # Fallback: try whois
  country=$(whois -h whois.radb.net "AS$asn" 2>/dev/null | grep "^country:" | head -1 | sed 's/country:[[:space:]]*//')
  if [ -n "$country" ]; then
    echo "$country"
    return
  fi
  
  echo "??"
}

# Function to calculate number of IPs in a CIDR range
cidr_to_ips() {
  local cidr="$1"
  local prefix="${cidr##*/}"
  if [ -z "$prefix" ] || [ "$prefix" = "$cidr" ]; then
    echo 1
    return
  fi
  echo $((2 ** (32 - prefix)))
}

# Convert nmap greppable output (.gnmap) to CSV rows
# Output columns: asn,ip,port,proto,state,service (open ports only)
parse_gnmap_to_csv() {
  local gnmap_file="$1"
  local asn="$2"
  [ ! -f "$gnmap_file" ] && return
  awk -v asn="$asn" '
    /^Host:/ && /Ports:/ {
      # Extract IP
      ip = ""
      if (match($0, /^Host: ([^ ]+)/, m)) { ip = m[1] }

      # Extract Ports section
      split($0, arr, "Ports: ")
      ports = arr[2]
      n = split(ports, plist, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^ +| +$/, "", plist[i])
        split(plist[i], f, "/")
        port = f[1]
        state = f[2]
        proto = f[3]
        service = f[5]
        if (port ~ /^[0-9]+$/ && state == "open") {
          print asn "," ip "," port "," proto "," state "," service
        }
      }
    }
  ' "$gnmap_file"
}

# Display ASN names and IP counts
echo ""
echo "=== ASN Summary ==="
total_ips=0

# Store ASN info for later reuse
asn_info_file=$(mktemp /tmp/asn_info.XXXXXX)

while IFS= read -r asn; do
  [ -z "$asn" ] && continue
  
  # Look up ASN name and country
  asn_name=$(get_asn_name "$asn")
  asn_country=$(get_asn_country "$asn")
  
  # Count IPs for this ASN
  tmp_ranges=$(mktemp /tmp/nmap_ranges.XXXXXX)
  ./get_ip_ranges_for_asn.sh "$asn" > "$tmp_ranges"
  asn_ip_count=0
  while IFS= read -r range; do
    [ -z "$range" ] && continue
    asn_ip_count=$((asn_ip_count + $(cidr_to_ips "$range")))
  done < "$tmp_ranges"
  rm -f "$tmp_ranges"
  
  total_ips=$((total_ips + asn_ip_count))
  
  # Store info: asn|name|country|ip_count
  printf "%s|%s|%s|%d\n" "$asn" "$asn_name" "$asn_country" "$asn_ip_count" >> "$asn_info_file"
  
  printf "%-40s  %10d IPs   %s   (AS%s)\n" "$asn_name" "$asn_ip_count" "$asn_country" "$asn"
done < "$asn_file"

echo "=== Total: $asn_count_final ASNs, ~$total_ips IPs ==="
echo ""

# Display numbered menu using stored info
echo "Select ASNs to scan:"
echo ""
declare -a asn_array
line_num=1
while IFS='|' read -r asn asn_name asn_country asn_ip_count; do
  [ -z "$asn" ] && continue
  asn_array+=("$asn")
  printf "[%2d]  %-40s  %10d IPs   %s   (AS%s)\n" "$line_num" "$asn_name" "$asn_ip_count" "$asn_country" "$asn"
  ((line_num++))
done < "$asn_info_file"

echo ""
echo "Options:"
echo "  'a' - scan all"
echo "  '1,3,5' - scan specific numbers (comma-separated)"
echo "  '1-3' - scan range"
echo "  '1,3-5,7' - combination"
read -p "Choice: " scan_choice

# Parse selection
scan_file=$(mktemp /tmp/selected_asns.XXXXXX)

if [ "$scan_choice" = "a" ] || [ "$scan_choice" = "A" ]; then
  cp "$asn_file" "$scan_file"
else
  # Parse comma and range syntax
  IFS=',' read -ra selections <<< "$scan_choice"
  for sel in "${selections[@]}"; do
    sel=$(echo "$sel" | xargs)  # trim whitespace
    
    if [[ "$sel" == *"-"* ]]; then
      # Handle range like "1-3"
      start=$(echo "$sel" | cut -d'-' -f1 | xargs)
      end=$(echo "$sel" | cut -d'-' -f2 | xargs)
      for idx in $(seq "$start" "$end"); do
        if [ "$idx" -ge 1 ] && [ "$idx" -le "${#asn_array[@]}" ]; then
          echo "${asn_array[$((idx-1))]}" >> "$scan_file"
        fi
      done
    else
      # Handle single number
      if [ "$sel" -ge 1 ] && [ "$sel" -le "${#asn_array[@]}" ]; then
        echo "${asn_array[$((sel-1))]}" >> "$scan_file"
      fi
    fi
  done
  
  if [ ! -s "$scan_file" ]; then
    echo "No valid selections made"
    rm -f "$scan_file"
    exit 1
  fi
  
  # Deduplicate
  sort -u "$scan_file" > "${scan_file}.uniq"
  mv "${scan_file}.uniq" "$scan_file"
fi

# Show selected ASNs for confirmation
echo ""
echo "Selected ASNs:"
while IFS= read -r asn; do
  asn_name=$(get_asn_name "$asn")
  printf "  AS%-6s  %s\n" "$asn" "$asn_name"
done < "$scan_file"
echo ""

read -p 'Proceed with scan? (y/n): ' confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Scan cancelled"
  rm -f "$scan_file"
  exit 0
fi

echo "Starting nmap scans..."
echo ""

# Prepare aggregate CSV for parse-friendly output
aggregate_csv="$output_dir/open_ports_all.csv"
echo "asn,ip,port,proto,state,service" > "$aggregate_csv"

while IFS= read -r asn; do
  [ -z "$asn" ] && continue
  tmp_ranges=$(mktemp /tmp/nmap_ranges.XXXXXX)
  ./get_ip_ranges_for_asn.sh "$asn" > "$tmp_ranges"

  if [ ! -s "$tmp_ranges" ]; then
    echo "No ranges found for ASN $asn; skipping."
    rm -f "$tmp_ranges"
    continue
  fi

  # Run a single nmap scan per ASN over all ranges, outputting parse-friendly files (.gnmap, .nmap, .xml)
  echo "nmap port scan for ASN $asn over $(wc -l < "$tmp_ranges") ranges; ports: $PORT_SPEC"
  nmap $SCAN_OPTS $RATE_OPTS -p "$PORT_SPEC" -iL "$tmp_ranges" -oA "$output_dir/${asn}"

  # Parse .gnmap to per-ASN CSV and append to aggregate
  gnmap_file="$output_dir/${asn}.gnmap"
  if [ -f "$gnmap_file" ]; then
    per_asn_csv="$output_dir/${asn}_open_ports.csv"
    echo "asn,ip,port,proto,state,service" > "$per_asn_csv"
    parse_gnmap_to_csv "$gnmap_file" "$asn" >> "$per_asn_csv"
    parse_gnmap_to_csv "$gnmap_file" "$asn" >> "$aggregate_csv"
  else
    echo "Warning: missing gnmap output for AS$asn; skipping CSV parse."
  fi

  rm -f "$tmp_ranges"
done < "$scan_file"

# Clean up temp file
rm -f "$scan_file" "$asn_info_file"

#!/bin/bash

# Usage: nmap_country.sh <countrycode>
# Mirrors ping_country.sh but uses nmap -sn over each ASN's routed IP ranges.

if [ -z "$1" ]; then
  echo "please set countrycode (e.g. nmap_country.sh ye)"
  exit 1
fi

country="$1"
echo "getting ip ranges for country with countrycode $country"

# Ensure nmap is available
if ! command -v nmap >/dev/null 2>&1; then
  echo "Error: nmap is not installed."
  if command -v brew >/dev/null 2>&1; then
    echo "Install with: brew install nmap"
  fi
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Warning: nmap -sn may need sudo/root for raw ping on some systems. Continuing..."
fi

bash ./get_asns_for_country.sh "$country"

filepath=./data/$(date +"%m%Y")
asn_file="$filepath/${country}_$(date +"%m%Y")_asns.txt"
output_dir="./results/$country/nmap_output_$(date +"%m%d%y")"
mkdir -p "$output_dir"

if [ ! -s "$asn_file" ]; then
  echo "No ASN list found at $asn_file; aborting."
  exit 1
fi

while IFS= read -r asn; do
  [ -z "$asn" ] && continue
  tmp_ranges=$(mktemp /tmp/nmap_ranges.XXXXXX)
  ./get_ip_ranges_for_asn.sh "$asn" > "$tmp_ranges"

  if [ ! -s "$tmp_ranges" ]; then
    echo "No ranges found for ASN $asn; skipping."
    rm -f "$tmp_ranges"
    continue
  fi

  while IFS= read -r range; do
    [ -z "$range" ] && continue
    echo "nmap ping sweep for $range (ASN $asn)"
    nmap -sn "$range" -oG "$output_dir/${asn}.txt" --append-output
  done < "$tmp_ranges"

  rm -f "$tmp_ranges"
done < "$asn_file"

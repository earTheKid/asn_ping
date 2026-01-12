#!/bin/bash
# Usage: asn_keyword_search.sh <keyword>
# Downloads a global ASN name list (RIPE asnames) and searches for case-insensitive keyword matches.
# Output: matching ASNs (one per line) to stdout.
# Cache: stores the asnames file under ./data/asnames.txt and refreshes if older than 7 days.

if [ -z "$1" ]; then
  echo "please set keyword (e.g. asn_keyword_search.sh arvan)"
  exit 1
fi

keyword="$1"
data_dir=./data
cache_file="$data_dir/asnames.txt"
max_age_days=7

mkdir -p "$data_dir"

need_fetch=true
if [ -f "$cache_file" ]; then
  file_age_days=$(( ( $(date +%s) - $(stat -f %m "$cache_file") ) / 86400 ))
  if [ "$file_age_days" -lt "$max_age_days" ]; then
    need_fetch=false
  fi
fi

if $need_fetch; then
  echo "Downloading ASN name list..."
  curl -s "https://ftp.ripe.net/ripe/asnames/asn.txt" -o "$cache_file" || {
    echo "Failed to download ASN list";
    exit 1;
  }
fi

grep -i "$keyword" "$cache_file" | awk '{print $1}' | sed 's/^AS//' | sed '/^$/d' 

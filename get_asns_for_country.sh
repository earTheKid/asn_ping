#
#  Usage: get_asns_for_country.sh ye
#  Gets all asns_for_country
#

if [ -z "$1" ]
then
      echo "please set countrycode (e.g  get_asns_for_country.sh ye)"
      exit
fi


# keep_ip_database=true

echo "getting ip ranges for country with countrycode $1"

filepath=./data/$(date  +'%m%Y')
mkdir  -p $filepath

echo "get asns from ripe"

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
   echo "Error: jq is not installed."
   if command -v brew >/dev/null 2>&1; then
      echo "Attempting to install jq via Homebrew..."
      brew install jq || { echo "Failed to install jq via Homebrew. Please install jq and retry."; exit 1; }
   else
      echo "Please install jq (e.g., via Homebrew: brew install jq) and rerun."
      exit 1
   fi
fi

# Fetch and parse ASNs (routed + non_routed) into one-per-line list
curl --location --silent "https://stat.ripe.net/data/country-asns/data.json?resource=$1&lod=1" \
  | jq -r '.data.countries[] | (.routed + "," + .non_routed) | gsub("AsnSingle\\("; "") | gsub("\\)"; "") | gsub("[{} ]"; "") | split(",")[]' \
  > "$filepath/$1_$(date  +'%m%Y')_asns.txt"



#if [ ! -d .ip-location-db ]
#then
   #git clone https://github.com/sapics/ip-location-db.git .ip-location-db
#fi
#cat .ip-location-db/geo-whois-asn-country/geo-whois-asn-country-ipv4-num.csv| grep $1 > "$1_asns.txt"

#if [ "$keep_ip_database" = false ] ; then
   #rm -rf .ip-location-db/
#fi

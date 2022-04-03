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

ripe_data=$(curl --location --request GET "https://stat.ripe.net/data/country-asns/data.json?resource=$1&lod=1")
# get routed asns
echo $ripe_data |jq '.data.countries'|grep '"routed"'|awk '{gsub("), AsnSingle\(",","); print}'|awk '{gsub("\"routed\": \"\{AsnSingle\(",""); print}'|awk '{gsub("\"routed\": \"\{AsnSingle\(",","); print}'|awk 'gsub("\)\}\".","")'| awk '{gsub(",","\n"); print;}' > "$filepath/$1_$(date  +'%m%Y')_asns.txt"
## get non routed asns
echo $ripe_data |jq '.data.countries'|grep '"non_routed"'|awk '{gsub("), AsnSingle\(",","); print}'|awk '{gsub("\"non_routed\": \"\{AsnSingle\(",""); print}'|awk '{gsub("\"non_routed\": \"\{AsnSingle\(",","); print}'|awk 'gsub("\)\}\".","")'| awk '{gsub(",","\n"); print;}' >> "$filepath/$1_$(date  +'%m%Y')_asns.txt"



#if [ ! -d .ip-location-db ]
#then
   #git clone https://github.com/sapics/ip-location-db.git .ip-location-db
#fi
#cat .ip-location-db/geo-whois-asn-country/geo-whois-asn-country-ipv4-num.csv| grep $1 > "$1_asns.txt"

#if [ "$keep_ip_database" = false ] ; then
   #rm -rf .ip-location-db/
#fi

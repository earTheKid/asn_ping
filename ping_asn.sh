#
# Usage ping_asn.sh countrycode/scrape_name asnumber
#
if [ -z "$1" ]
then
      echo "please set countrycode (e.g  ping_asn.sh ye 5234)"
      exit
fi

rm -rf .ranges.txt

mkdir -p "./results/$1/output_$(date  +'%m%d%y')/"

# Try to pick the default outbound interface automatically (macOS-friendly)
DEFAULT_IFACE=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')

echo "get ranges for ASN $2"
./get_ip_ranges_for_asn.sh $2 >> .ranges.txt
while IFS= read -r line; do
    echo "starting ping for range $line"
    if [ -n "$DEFAULT_IFACE" ]; then
        masscan -iL ./.ranges.txt --ping --max-rate 2000 -oL "./results/$1/output_$(date  +'%m%d%y')/$2.txt" --append-output -e "$DEFAULT_IFACE"
    else
        echo "Warning: could not detect default interface; running masscan without -e"
        masscan -iL ./.ranges.txt --ping --max-rate 2000 -oL "./results/$1/output_$(date  +'%m%d%y')/$2.txt" --append-output
    fi
done < .ranges.txt 

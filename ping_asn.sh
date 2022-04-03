
rm -rf .ranges.txt

mkdir -p ./output_$(date  +'%m%d%y')

echo "get ranges for ASN $1"
./get_ip_ranges_for_asn.sh $1 >> .ranges.txt
while IFS= read -r line; do
    echo "starting ping for range $line"
    masscan -iL ./.ranges.txt --ping --max-rate 2000 -oL output_$(date +'%m%d%y')/"$1.txt" --append-output
done < .ranges.txt 

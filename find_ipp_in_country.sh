if [ -z "$1" ]
then
      echo "please set countrycode (e.g  get_asns_for_country.sh ye)"
      exit
fi
echo "getting ip ranges for country with countrycode $1"

bash ./get_asns_for_country.sh $1

filepath=./data/$(date  +'%m%Y')

while IFS= read -r line; do
    ./get_ipp_for_asn.sh $1 $line 
done < "$filepath/$1_$(date  +'%m%Y')_asns.txt"

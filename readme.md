
This script is a masscan wrapper that sends icmp-echo requests to all know IPs of a country, based on the ASN locaton.

## Dependencies

## Usage
./ping_country.sh YE
 

## To Do
- update get_asns_for_country.sh to store result file every day (but still only create a new dir every month)
- script to get asns and ip ranges for country to have final command like "ping_country.sh  ye 500"  

## Limitations
- Cannot verify real physical location - output based on asn whois information.

## Other interesting rsources

https://stat.ripe.net/widget/country-routing-stats#w.resource=ua
https://stat-ui.stat.ripe.net/data/country-routing-stats/data.json?resource=ua&starttime=2022-01-15T22:00&endtime=2022-04-04T15:00&resolution=1h&callback=jQuery111208226661882290299_1648911337229&_=1648911337234

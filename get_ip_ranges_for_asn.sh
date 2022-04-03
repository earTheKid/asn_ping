#!/bin/bash   
ASN_ID=$1
whois -h whois.radb.net -- "-i origin AS$ASN_ID" | grep -Eo "([0-9.]+){4}/[0-9]+" | head

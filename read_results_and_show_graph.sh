#!/bin/bash
# NOTE : Quote it else use array to avoid problems #
rm -f active_pings.csv
FILES="./output*"
for f in $FILES
do
  date=${f##*_}
  # take action on each file. $f store current file name
  f+="/*.txt"
  lines=$(cat ${f} | wc -l)
  echo "$date: $lines"
  echo "$date, $lines" >> active_pings.csv
done
termgraph active_pings.csv

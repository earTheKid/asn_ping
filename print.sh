while read p; do
  python3 show_printer_for_ip.py "$p" >> print_log.txt
done <printers_ips_without_dups.txt

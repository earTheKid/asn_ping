import sys
import cups
import os

def printgt(printer):
    f = os.path.abspath("testreceipt.txt")     
    printer_returns = conn.printFile(printer, f, "testreceipt.txt", {})
    print(printer_returns)

print("Get printers for "+sys.argv[1])
conn = cups.Connection (sys.argv[1])
print("get printers")
printers = conn.getPrinters ()
print("loop through printers")
for printer in printers:
    printer_url = printer
    print(printer_url, printers[printer])
    ##printt(printer_url)

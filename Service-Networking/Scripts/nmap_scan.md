Before running the nmap_scan.sh make tsure to install the nmaptocsv in order to import to google sheets

`sudo apt install -y pipx`

`pipx install nmaptocsv`

`pipx ensurepath`

`nmaptocsv -x inventory_XXXXXXX_XXXX.xml -o inventory.csv`

`scp -P <port> user@public_ip:/home/user/nmap_inventory/inventory.csv .`
This md file contains a description of tools within the current directory

counts.py
Functionality:
counts.py takes in a .pcap file and a destination ip address and performs an analysis to see how often the ip address appears in the file.
Use Case During Event:
When the team wants to analyze network traffic looking for common ip addresses and their source.
Risk Assessment:
Low/no risk, this is just an analyzation script and doesnt make any changes to anything.

netplan.sh
Functionality:
netplan.sh takes in user input in a step by step process that is intended to autmatically make a netplan configuration for a system.
Use Case During Event:
When the team needs to make changes to network configurations this is an automated way to do so.
Risk:
Low, this script backs up the previous netplan file so in the case the network configuration fails that backup can be restored.

nmap_scan.sh
Functionality:
nmap_scan.sh is an automated way to perform a comprehensive nmap scan on one or more targets.
Use Case During Event:
When the team needs to do network reconaissance this script is an automated way to do so.
Risk:
Low. This scan is a step by step process and puts the infrastructure at little risk.

persistent.py
Functionality:
persitent.py takes in a pcap file and analyzes the file for persistent connections.
Use Case During Event:
When the team needs to analyze network traffic this is a nice tool to look at long persistent connections to the infrastructure.
Risk:
Low/none, this is analyzation script that makes no changes to anything on the infrastructure.
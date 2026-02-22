# UFW Firewall Setup Script

**Author:** Michael Leahy  
**Last Updated:** February 19, 2026

## Overview

This Bash script installs and configures UFW (Uncomplicated Firewall) on a Linux system.  
It performs the following actions:
- Installs UFW if not present
- Disables and masks Firewalld (if active)
- Sets strict default firewall policies
- Allows essential services (SSH, HTTP, HTTPS, DNS)
- Enables UFW  

This script sets default deny for both incoming and outgoing traffic. It is intended for Debian-based distributions. The script must be run with root privileges.

## Usage
```bash
sudo ./ufw-firewall-setup.sh
```
## Default Policis
- **Incoming:** Deny all
- **Outgoing:** Deny all  

No traffic is allowed unless explicitly permitted

## Allowed Rules
#### SSH
- **allow 22/tcp:** allow SSH connections from anywhere on port 22

#### HTTP/HTTPS
- **allow 80/tcp:** allows incoming HTTP traffic
- **allow out 80/tcp:** allows outgoing traffic to port 80
- **allow 443/tcp:** allows incoming HTTPS traffic
- **allow out 443/tcp:** allows outgoing traffic to port 443

#### DNS
- **allow out 53/udp:** allow outgoing DNS queries

## Notes
You must add additional outbound rules for each machine so that services will work correctly. To add allow rules, use:
```bash
sudo ufw allow <rule>
```
To add deny rules, use:
```bash
sudo ufw deny <rule>
```
To delete a rule, use:
```bash
sudo ufw delete <rule>
```

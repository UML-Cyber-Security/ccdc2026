# Micro-Segmentation Using iptables

## Overview

Micro-segmentation with `iptables` enforces **host-level zero-trust networking**, where each system explicitly defines who it can talk to and on which ports. Unlike network-based controls (pfSense), `iptables` travels with the workload itself—making it ideal for **defense-in-depth** and **CCDC environments** where attackers may bypass perimeter controls.

In short:
- pfSense controls *paths*
- iptables controls *permissions*

Used together, they dramatically reduce lateral movement.

---

## Why iptables for Micro-Segmentation

`iptables` is especially valuable in CCDC because:

- It remains effective even if firewall rules are misconfigured upstream
- It limits damage from stolen credentials
- It forces attackers to exploit services rather than pivot freely
- It creates visibility via logs on the host itself

iptables assumes **no implicit trust**, even from the same subnet.

---

## Design Philosophy

**Default deny. Explicit allow. Log everything else.**

Each host should:
1. Allow only required inbound traffic
2. Restrict outbound traffic to known dependencies
3. Drop and log all other east-west traffic

---

## CCDC Micro-Segmentation Scenarios

### Scenario 1: Web Server Containment

**Threat:**  
Web server exploited via RCE.

**iptables Goal:**  
Prevent pivoting to database, AD, or backups.

**Allowed Traffic:**
- Inbound: 80/443 from LB or trusted subnet
- Outbound: DB on TCP 3306, DNS, NTP

**Result:**  
Attacker gains shell but cannot move laterally.

---

### Scenario 2: Database Server Hardening

**Threat:**  
Credential reuse from compromised app server.

**iptables Goal:**  
Only allow DB traffic from application servers.

**Allowed Traffic:**
- Inbound: TCP 3306 from `APP_SERVER_IP`
- Outbound: DNS, NTP only

Result: Database becomes a dead-end target.

---

### Scenario 3: Active Directory Member Server

**Threat:**  
Malware spreading via SMB and RPC.

**iptables Goal:**  
Block all peer-to-peer SMB.

**Allowed Traffic:**
- Outbound: AD ports to DCs only
- Inbound: Management traffic only

---

## Baseline iptables Template (Linux)

```bash
#!/bin/bash

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Default deny
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established traffic
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

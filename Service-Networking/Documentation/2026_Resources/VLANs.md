# VLANs and Subnet Isolation Techniques

## Overview

VLANs (Virtual Local Area Networks) and subnet isolation are foundational network security techniques used to limit broadcast domains, reduce attack surface, and prevent lateral movement after a compromise. By logically separating systems based on function, trust level, or risk profile, defenders can enforce least-privilege network access and tightly control traffic flows.

In practice, VLANs provide Layer 2 segmentation, while subnets and firewall rules (Layer 3/4) enforce policy. When combined—especially with a stateful firewall like **pfSense**—they form a strong containment strategy against internal threats.

---

## Why VLANs Matter in Defensive Operations

Without segmentation:
- Any compromised host can scan, attack, or pivot to others
- Malware spreads quickly
- Credential harvesting impacts the entire environment

With VLANs + firewall enforcement:
- Compromise impact is contained
- Attack paths are predictable and auditable
- Detection becomes easier due to reduced noise

---

## Common VLAN Design Patterns

| VLAN | Purpose | Example Systems |
|----|------|----------------|
| VLAN 10 | User / Workstations | Employee PCs |
| VLAN 20 | Servers | AD, DB, Web |
| VLAN 30 | Management | pfSense, iDRAC, hypervisors |
| VLAN 40 | DMZ | Public-facing web/mail |
| VLAN 50 | Guest / Untrusted | BYOD, contractor devices |

Each VLAN maps to:
- A unique subnet
- A dedicated pfSense interface
- Explicit firewall rules

---

## CCDC Scenarios Using pfSense

### Scenario 1: Limiting Lateral Movement After Compromise

**Situation:**  
An attacker compromises a user workstation via phishing.

**Poor Design Outcome:**  
The attacker scans the entire /16 and reaches domain controllers, databases, and backups.

**Segmented Design Outcome:**  
- User VLAN (10.10.10.0/24)
- Server VLAN (10.10.20.0/24)
- pfSense blocks all inter-VLAN traffic by default

**pfSense Policy:**
- Default deny from Users → Servers
- Allow only specific ports (e.g., 443 to web app, 389/636 only from DC-required systems)

Result: The attacker is trapped inside a low-value VLAN.

---

### Scenario 2: DMZ Containment During Web Exploit

**Situation:**  
A public-facing web server is exploited via RCE.

**Design:**
- Web server lives in DMZ VLAN (10.10.40.0/24)
- Internal servers are unreachable unless explicitly allowed

**Firewall Rules:**
- Allow WAN → DMZ (80/443)
- Block DMZ → Internal (any)
- Allow DMZ → Internal DB only on TCP 3306 (if required)

Result: Web server compromise does not equal internal breach.

---

### Scenario 3: Protecting Management Interfaces

**Situation:**  
Blue team notices SSH brute-force attempts on infrastructure devices.

**Mitigation:**
- Management VLAN (10.10.30.0/24)
- pfSense GUI, switches, hypervisors only accessible from Mgmt VLAN

**Rules:**
- Block all VLANs → Mgmt
- Allow Mgmt → All (as needed)

Result: Even with stolen creds, attackers cannot reach management planes.

---

## pfSense Implementation Strategy

### Interface Setup
1. Create VLANs on the parent interface
2. Assign each VLAN to a pfSense interface
3. Give each interface:
   - Static IP
   - DHCP (if needed)

### Baseline Rule Philosophy (Recommended)
- **Default deny inbound and inter-VLAN**
- Explicit allow rules only
- Log denied traffic during CCDC

---

## Example pfSense Rule Logic (Pseudo-Policy)

```text
Users VLAN:
  - Allow DNS → pfSense
  - Allow HTTPS → Web VLAN
  - Block ALL → Any (log)

Servers VLAN:
  - Allow required east-west traffic
  - Block ALL → Users

DMZ VLAN:
  - Allow outbound DNS/NTP
  - Allow DB traffic (specific host/port)
  - Block ALL → Internal
```

`nmap -Pn -p 1-1024 10.10.20.0/24`

```
pfctl -sr
pfctl -ss | wc -l
```


# DNS Architecture and Segmentation Strategy

## Overview

DNS is one of the most critical—and most abused—services in an enterprise network. Nearly every system depends on it, and attackers routinely exploit DNS for **reconnaissance, lateral movement, command-and-control (C2), and data exfiltration**.

A secure DNS architecture separates responsibilities across **authoritative servers, recursive resolvers, and forwarders**, and enforces strict access controls between them. In a CCDC environment, proper DNS segmentation prevents DNS abuse from becoming a total-network compromise.

---

## Core DNS Roles Explained

### Authoritative DNS Servers
**Purpose:**  
- Provide official answers for domains you own
- Do *not* perform recursion

**Examples:**
- Internal AD-integrated DNS for `corp.local`
- External public DNS for `example.com`

**Security Principle:**  
Authoritative servers should **only answer**, never search.

---

### Recursive Resolvers
**Purpose:**  
- Resolve arbitrary DNS queries on behalf of clients
- Perform full recursion (root → TLD → authoritative)

**Examples:**
- Internal caching resolvers
- Unbound on pfSense

**Security Principle:**  
Only trusted clients may query recursion.

---

### DNS Forwarders
**Purpose:**  
- Forward queries to upstream resolvers
- Often used to centralize policy, logging, or filtering

**Examples:**
- pfSense forwarding to ISP DNS
- Internal resolver forwarding to DCs

**Security Principle:**  
Forwarders should be tightly scoped and monitored.

---

## Secure DNS Architecture Model

```text
Clients
   ↓
Internal Recursive Resolver (pfSense / Unbound)
   ↓
Internal Authoritative DNS (AD DNS)
   ↓
External Root / Internet DNS (if allowed)
```

Key idea: **Clients never talk directly to authoritative or external DNS servers.**

---

## DNS Architecture in a CCDC Setting

### Scenario 1: Preventing DNS-Based Reconnaissance

**Threat:**
Compromised host uses DNS to enumerate internal services or resolve arbitrary domains.

**Mitigation:**

* Only allow DNS queries to approved recursive resolvers
* Block outbound UDP/TCP 53 to everywhere else

**Result:**
Attacker cannot:

* Query internal DNS zones directly
* Use external DNS for C2

---

### Scenario 2: Protecting Authoritative DNS Servers

**Threat:**
Attacker targets AD DNS for zone transfers or poisoning.

**Mitigation:**

* Allow DNS queries only from recursive resolvers
* Disable recursion on authoritative servers
* Block AXFR except from secondary servers

**Result:**
Authoritative servers cannot be abused for recon or amplification.

---

### Scenario 3: DNS as a Command-and-Control Channel

**Threat:**
Malware uses DNS tunneling for exfiltration.

**Mitigation:**

* Force all DNS through monitored resolvers
* Log query volume, length, and entropy
* Block TXT and NULL records if not required

**Result:**
DNS tunneling becomes detectable and disruptable.

---

## pfSense DNS Architecture Best Practices

### pfSense as Recursive Resolver (Unbound)

Recommended:

* Enable Unbound DNS Resolver
* Disable DNS Resolver WAN access
* Enable DNSSEC validation
* Register DHCP leases in DNS

pfSense becomes the **only DNS endpoint** clients can use.

---

### pfSense as DNS Forwarder

If recursion is not desired:

* pfSense forwards queries to:

  * AD DNS
  * Trusted upstream resolvers
* Logging and filtering still centralized

---

## Network Segmentation Rules (pfSense)

### Clients VLAN

```text
Allow: Clients → pfSense UDP/TCP 53
Block: Clients → Any UDP/TCP 53
```

### DNS Servers VLAN

```text
Allow: Resolvers → Authoritative DNS UDP/TCP 53
Block: Any → Authoritative DNS (other than resolvers)
```

---

## DNS Micro-Segmentation with iptables

### Client Host DNS Enforcement

```bash
DNS_IP="10.10.10.1"

iptables -A OUTPUT -p udp --dport 53 -d $DNS_IP -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -d $DNS_IP -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j DROP
iptables -A OUTPUT -p tcp --dport 53 -j DROP
```

Forces DNS through approved resolver only.

---

### Authoritative DNS Server Hardening

```bash
# Disable recursion externally
iptables -A INPUT -p udp --dport 53 -s 10.10.10.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -s 10.10.10.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j DROP
iptables -A INPUT -p tcp --dport 53 -j DROP
```

---

## Detecting DNS Abuse (CCDC-Friendly)

### High-Volume Query Detection

```bash
tcpdump -ni any port 53
```

### Suspicious Record Types

```bash
tcpdump -ni any 'port 53 and (udp[10] & 0x80 = 0)'
```

### pfSense DNS Logs

* Services → DNS Resolver → Log Queries
* Look for:

  * Long labels
  * High-frequency TXT queries
  * Random-looking domains

---

## Emergency DNS Lockdown Play

**If DNS abuse is detected:**

1. Disable recursion temporarily
2. Force forward-only mode
3. Block all outbound DNS except to upstream
4. Whitelist known-good domains if necessary

This can instantly break C2 channels.

---

## Common DNS Architecture Mistakes

* Allowing clients to query external DNS directly
* Leaving recursion enabled on authoritative servers
* Allowing zone transfers to any host
* Not logging DNS queries
* Mixing authoritative and recursive roles on the same server
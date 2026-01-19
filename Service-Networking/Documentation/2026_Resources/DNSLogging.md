# Detecting DNS Anomalies and Suspicious Query Patterns

## Overview

DNS is a high-signal protocol for detecting compromise. Because nearly all malware, lateral movement, and command-and-control (C2) activity relies on DNS at some stage, **abnormal DNS behavior is often the earliest and clearest indicator of intrusion**.

In a CCDC environment, DNS anomaly detection provides:
- Early compromise detection
- Visibility into internal misuse
- Evidence for scoring and incident response
- Opportunities to disrupt attacker tooling

---

## What “Normal” DNS Looks Like

Baseline characteristics of healthy DNS traffic:
- Short, human-readable domain names
- Repeated queries to a small set of domains
- Mostly A/AAAA lookups
- Low TXT and NULL record usage
- Queries spread over time

Anything deviating from this baseline deserves scrutiny.

---

## Common DNS Anomaly Categories

### 1. High-Entropy Domain Names

**Description:**  
Domains with random-looking subdomains.

**Example:**
```text
k2fj39dksl0q8a.example.net
```

**Often Indicates:**

* DGA-based malware
* DNS tunneling

---

### 2. Excessive Query Volume

**Description:**
Single host generating hundreds or thousands of DNS queries per minute.

**Often Indicates:**

* Beaconing malware
* Misconfigured service loops
* Active scanning tools

---

### 3. Unusual Record Types

**Description:**
Frequent use of:

* TXT
* NULL
* CNAME chains

**Often Indicates:**

* DNS tunneling
* Data exfiltration
* C2 over DNS

---

### 4. NXDOMAIN Flooding

**Description:**
High rate of non-existent domain responses.

**Often Indicates:**

* Domain Generation Algorithms (DGAs)
* Reconnaissance activity

---

### 5. DNS Queries Bypassing Approved Resolvers

**Description:**
Hosts querying external DNS servers directly.

**Often Indicates:**

* Malware attempting evasion
* Misconfigured systems
* Policy violations

---

## CCDC Scenarios

### Scenario 1: DNS Tunneling Detection

**Observation:**
TXT queries every few seconds with long payloads.

**Response:**

* Identify source host
* Quarantine via firewall
* Block outbound DNS except approved resolver

---

### Scenario 2: Malware Beaconing

**Observation:**
Consistent queries every 60 seconds to same domain.

**Response:**

* Sinkhole domain internally
* Observe follow-on behavior
* Investigate host

---

### Scenario 3: DGA-Based Malware

**Observation:**
Hundreds of NXDOMAINs from a single host.

**Response:**

* Rate-limit DNS
* Block host
* Capture memory and disk artifacts

---

## Detection Using pfSense (Unbound)

### Enable DNS Query Logging

* Services → DNS Resolver
* Enable **Log Queries**

Look for:

* Long labels
* Repeated failures
* High query rates from single IPs

---

### pfSense Packet Capture

```sh
tcpdump -ni any port 53
```

Filter by host:

```sh
tcpdump -ni any port 53 and host 10.10.10.25
```

---

## iptables-Based DNS Monitoring

### Log DNS Queries Per Host

```bash
iptables -A OUTPUT -p udp --dport 53 -j LOG --log-prefix "DNS_OUT: "
```

Review logs:

```bash
journalctl -k | grep DNS_OUT
```

---

### Detect Resolver Bypass Attempts

```bash
iptables -A OUTPUT -p udp --dport 53 ! -d 10.10.10.1 -j LOG --log-prefix "DNS BYPASS: "
iptables -A OUTPUT -p udp --dport 53 ! -d 10.10.10.1 -j DROP
```

---

## Entropy and Length Heuristics

### Red Flags

* Label length > 50 characters
* Base64-like patterns
* Numeric-heavy subdomains

Example:

```text
bW9yZXNlY3JldGRhdGE=.malicious.net
```

---

## CLI-Based Analysis Tools

### dig for Manual Inspection

```bash
dig TXT suspicious.example.com
```

### Count Queries by Source (Quick Triage)

```bash
tcpdump -nn -l port 53 | awk '{print $3}' | sort | uniq -c | sort -nr
```

---

## DNS Sinkholing Strategy

### What Is Sinkholing?

Redirecting malicious domains to a controlled IP.

**Benefits:**

* Breaks C2
* Reveals infected hosts
* Preserves scoring

---

### Simple Sinkhole Entry

```text
malicious-domain.com   A   10.10.99.99
```

Monitor traffic to the sinkhole host.

---

## Emergency CCDC DNS Response Playbook

1. Identify suspicious domain or host
2. Confirm via query logs
3. Block or sinkhole domain
4. Quarantine affected host
5. Monitor for secondary infections

---

## Common Pitfalls

* Logging without reviewing
* Ignoring internal DNS traffic
* Blocking DNS too broadly
* Forgetting TCP 53 during analysis

---

## Key Takeaway

DNS anomalies are rarely benign. In a CCDC environment, disciplined DNS monitoring transforms DNS from a background service into a **real-time intrusion detection sensor**—often revealing attacks long before endpoints alert.

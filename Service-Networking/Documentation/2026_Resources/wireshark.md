# Packet Capture via Wireshark

## Overview

Packet capture (PCAP) is one of the most powerful tools available to defenders. Wireshark allows blue teams to **see exactly what is happening on the wire**, making it invaluable for detecting compromise, validating firewall rules, troubleshooting outages, and gathering evidence during incident response.

In a CCDC environment—where attackers are active and misconfigurations are common—Wireshark provides ground truth when logs and dashboards are misleading or incomplete.

---

## When to Use Wireshark

Wireshark is best used when:
- Network behavior is suspicious or unexplained
- Services appear up but are not functioning
- You suspect credential theft or plaintext protocols
- You need to confirm firewall, NAT, or segmentation behavior
- Scoring checks fail without clear logs

---

## Strategic Capture Locations (CCDC)

### 1. Firewall / Router Interfaces
- Validate allowed vs blocked traffic
- Observe lateral movement attempts
- Confirm NAT translations

### 2. Server NICs
- Detect malicious inbound connections
- Inspect application-layer behavior
- Validate service bindings

### 3. SPAN / Mirror Ports
- Monitor entire VLANs without endpoint impact
- Detect scanning and beaconing

---

## Common CCDC Scenarios

### Scenario 1: Detecting Lateral Movement

**Symptoms:**  
Unexpected authentication failures or scanning alerts.

**Wireshark Indicators:**
- SMB (445) or RDP (3389) attempts across hosts
- Rapid SYN packets across many IPs

Result: Confirms internal compromise.

---

### Scenario 2: Credential Exposure Detection

**Symptoms:**  
Suspicious account behavior.

**Wireshark Indicators:**
- Plaintext credentials in HTTP, FTP, SMTP
- NTLM authentication over SMB

Result: Confirms credential leakage path.

---

### Scenario 3: DNS-Based C2 Confirmation

**Symptoms:**  
Suspicious DNS logs.

**Wireshark Indicators:**
- Repeated DNS queries to same domain
- TXT record abuse
- Long, high-entropy labels

Result: Confirms malware communication channel.

---

## Wireshark Capture Best Practices

### Scope Your Capture

Never capture “everything” unless absolutely necessary.

Examples:
```text
host 10.10.10.25
port 53
net 10.10.20.0/24
```

---

### Capture Filters vs Display Filters

| Type           | Applied When   | Use Case         |
| -------------- | -------------- | ---------------- |
| Capture Filter | Before capture | Reduce noise     |
| Display Filter | After capture  | Analyze patterns |

Prefer capture filters to reduce file size.

---

## Useful Capture Filters (BPF)

### DNS Traffic

```text
port 53
```

### Suspicious Host

```text
host 10.10.10.25
```

### Lateral Movement (SMB + RDP)

```text
tcp port 445 or tcp port 3389
```

### Beaconing Detection

```text
tcp[tcpflags] & tcp-syn != 0
```

---

## Wireshark Display Filters (Examples)

### Failed Connections

```text
tcp.flags.reset == 1
```

### DNS NXDOMAIN Responses

```text
dns.flags.rcode == 3
```

### High-Entropy DNS Queries

```text
strlen(dns.qry.name) > 50
```

---

## Detecting Beaconing Behavior

**What to Look For:**

* Regular intervals between packets
* Small, consistent payload sizes
* Repeated destination IP/domain

Use:

* Statistics → Conversations
* Statistics → IO Graphs

---

## TLS and Encrypted Traffic Analysis

Even encrypted traffic leaks metadata:

* Server Name Indication (SNI)
* Certificate details
* Session frequency

Display filter:

```text
tls.handshake.extensions_server_name
```

Suspicious signs:

* Unknown domains
* Self-signed certs
* Frequent short-lived TLS sessions

---

## Credential and Auth Traffic Indicators

### NTLM Authentication

```text
ntlmssp
```

### Kerberos Activity

```text
kerberos
```

Look for:

* Excessive authentication attempts
* Cross-subnet authentication

---

## pfSense + Wireshark Workflow

1. Identify suspicious flow via logs
2. Capture traffic on pfSense interface
3. Validate rule hit behavior
4. Adjust firewall rules
5. Confirm resolution via follow-up capture

---

## Evidence Handling (CCDC)

* Save PCAPs with timestamps
* Label by incident
* Do not overwrite captures
* Keep chain-of-custody notes for judges

---

## Common Mistakes

* Capturing too broadly
* Forgetting time synchronization
* Ignoring outbound traffic
* Misreading retransmissions as attacks

---

## Emergency CCDC Playbook

**If active attack suspected:**

1. Start targeted capture immediately
2. Identify attacker IP/domain
3. Block or isolate via firewall
4. Capture post-mitigation traffic to confirm success

---

## Key Takeaway

Wireshark turns assumptions into facts. In a CCDC environment, disciplined packet capture provides unmatched visibility, enabling defenders to detect attacks, validate controls, and respond with confidence under pressure.
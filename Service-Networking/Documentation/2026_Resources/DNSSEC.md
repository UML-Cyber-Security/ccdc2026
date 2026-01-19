# DNSSEC Concepts and Implementation

## Overview

DNSSEC (Domain Name System Security Extensions) adds **cryptographic integrity and authenticity** to DNS responses. While traditional DNS blindly trusts responses, DNSSEC allows resolvers to verify that DNS data:

- Has not been modified in transit
- Comes from the legitimate authoritative source
- Is part of a validated chain of trust

In a CCDC environment, DNSSEC helps defend against **DNS spoofing, cache poisoning, and on-path attacks**, which are commonly used to redirect traffic, steal credentials, or deliver malware.

---

## What DNSSEC Does (and Does Not Do)

### DNSSEC Provides
- Data integrity
- Source authentication
- Trust chaining from root → TLD → zone

### DNSSEC Does NOT Provide
- Confidentiality (queries are still visible)
- Protection against malicious but valid domains
- Availability guarantees

DNSSEC ensures answers are **correct**, not **safe**.

---

## Core DNSSEC Components

### DNSKEY
- Public keys for a DNS zone
- Used to verify signatures

### RRSIG
- Cryptographic signatures for DNS records
- Proves authenticity of DNS data

### DS (Delegation Signer)
- Hash of child zone’s DNSKEY
- Stored in parent zone
- Links trust chain

### Chain of Trust
```text
Root Zone
  ↓ DS
TLD Zone
  ↓ DS
Authoritative Zone
```

If any link breaks, validation fails.

---

## DNSSEC in a Secure DNS Architecture

### Role Separation with DNSSEC

| DNS Role             | DNSSEC Responsibility        |
| -------------------- | ---------------------------- |
| Authoritative Server | Signs zones                  |
| Recursive Resolver   | Validates signatures         |
| Forwarder            | Passes DNSSEC data unchanged |
| Clients              | Trust resolver results       |

Clients **should not** validate DNSSEC directly—resolvers do it once, centrally.

---

## CCDC Scenarios Where DNSSEC Matters

### Scenario 1: Cache Poisoning Defense

**Threat:**
Attacker injects fake DNS responses to redirect traffic.

**Without DNSSEC:**
Resolver accepts forged records.

**With DNSSEC:**
Forged responses fail validation and are dropped.

Result: Traffic is not redirected to attacker infrastructure.

---

### Scenario 2: Man-in-the-Middle Credential Theft

**Threat:**
Attacker intercepts DNS to redirect users to fake login portals.

**DNSSEC Impact:**
DNS responses fail validation, breaking the attack chain.

Result: Attack fails silently.

---

### Scenario 3: Scoring Engine Trust

**Threat:**
CCDC scoring services rely on DNS resolution.

**DNSSEC Misconfiguration Risk:**
Broken DNSSEC causes outages.

**Mitigation:**
Test validation early and monitor failures.

---

## pfSense DNSSEC Implementation (Unbound)

### Recommended pfSense Configuration

* Enable **DNS Resolver (Unbound)**
* Enable **DNSSEC Support**
* Disable **DNS Resolver WAN Access**
* Enable **Query Logging** (during CCDC)

pfSense becomes a validating recursive resolver.

---

### Validation Flow in pfSense

```text
Client → pfSense Resolver
        → Root (DNSSEC validated)
        → TLD (DNSSEC validated)
        → Authoritative Zone
```

If validation fails, pfSense returns `SERVFAIL`.

---

## Authoritative DNS DNSSEC Implementation

### Internal Zones (AD DNS)

* DNSSEC optional but recommended for critical internal zones
* Protects against internal spoofing
* Especially useful in flat or partially segmented networks

### External/Public Zones

* DNSSEC strongly recommended
* Requires registrar support
* Incorrect DS records will cause outages

---

## iptables Enforcement for DNSSEC Integrity

DNSSEC requires **TCP 53 support** for large responses.

### Client Host Rules

```bash
DNS_IP="10.10.10.1"

iptables -A OUTPUT -p udp --dport 53 -d $DNS_IP -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -d $DNS_IP -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j DROP
iptables -A OUTPUT -p tcp --dport 53 -j DROP
```

Blocking TCP 53 will break DNSSEC validation.

---

### Resolver Hardening

```bash
# Allow DNSSEC-sized responses
iptables -A INPUT -p tcp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT
```

---

## Detecting DNSSEC Failures (CCDC)

### pfSense Indicators

* SERVFAIL responses increase
* DNS Resolver logs show validation errors

### CLI Testing

```bash
drill dnssec-failed.org
```

```bash
dig +dnssec example.com
```

Look for:

* `ad` (Authenticated Data) flag
* Absence of `SERVFAIL`

---

## Emergency DNSSEC Playbook

**If DNSSEC breaks production traffic:**

1. Confirm resolver time sync (NTP!)
2. Check MTU / TCP 53 blocking
3. Temporarily disable DNSSEC validation
4. Restore after stability

DNSSEC failure often looks like a network outage.

---

## Common DNSSEC Pitfalls

* Blocking TCP 53
* Broken DS records
* Unsynced system clocks
* Middleboxes modifying DNS responses
* Enabling DNSSEC on authoritative servers without testing

---

## CCDC-Specific Advice

* Enable DNSSEC early and test scoring services
* Monitor logs continuously
* Document rollback steps
* Never mix DNSSEC testing with live scoring windows
```

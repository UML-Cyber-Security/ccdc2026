# Split-Brain DNS (Internal vs. External DNS)

## Overview

Split-brain DNS (also called *split-horizon DNS*) is a DNS architecture where **the same domain name returns different answers depending on the source of the query**. Internal users receive private IPs and internal service records, while external users receive public-facing records only.

In a CCDC environment, split-brain DNS is critical for:
- Preventing internal infrastructure leakage
- Reducing attack surface
- Enforcing proper trust boundaries
- Maintaining service availability for both internal and external users

---

## Why Split-Brain DNS Matters

Without split-brain DNS:
- Internal hostnames and IPs leak externally
- Services may resolve to unreachable private IPs
- Attackers gain insight into internal topology

With split-brain DNS:
- Internal clients see full service mappings
- External clients see only what is intentionally exposed
- Internal services remain invisible from the Internet

---

## Core Split-Brain DNS Model

```text
Internal Clients
   ↓
Internal DNS Resolver
   ↓
Internal Authoritative Zone (corp.example.com)

External Clients
   ↓
Public DNS Resolver
   ↓
External Authoritative Zone (example.com)
```

Same domain, **different zone data**, different audiences.

---

## Split-Brain DNS in a CCDC Setting

### Scenario 1: Protecting Internal Service Discovery

**Threat:**
Attacker enumerates DNS records externally.

**Without Split-Brain:**
Public DNS reveals:

* `dc01.corp.example.com`
* `db01.corp.example.com`

**With Split-Brain:**
Public DNS exposes only:

* `www.example.com`
* `mail.example.com`

Result: Internal naming and structure remain hidden.

---

### Scenario 2: Preventing Service Misrouting

**Threat:**
Internal clients resolve services to public IPs.

**Impact:**

* Hairpin NAT
* Performance degradation
* TLS validation issues

**Split-Brain Solution:**
Internal DNS resolves services to private IPs.

Result: Correct routing and improved reliability.

---

### Scenario 3: CCDC Scoring Engine Stability

**Threat:**
Scoring engine resolves wrong IPs due to DNS confusion.

**Split-Brain Benefit:**

* Internal scoring checks resolve internal services correctly
* External checks hit public endpoints only

Result: Stable scoring and reduced troubleshooting time.

---

## pfSense Implementation Strategy

### Internal DNS (Unbound or AD DNS)

* Host internal zones:

  * `corp.example.com`
* Contain:

  * Private IPs
  * SRV records
  * Internal-only hostnames

### External DNS

* Hosted at registrar or public provider
* Contains:

  * Public IPs only
  * Minimal records
  * No internal naming patterns

---

## Example Zone Data

### Internal Zone (`example.com`)

```text
www     A   10.10.40.10
mail    A   10.10.40.20
dc01    A   10.10.20.5
```

### External Zone (`example.com`)

```text
www     A   198.51.100.10
mail    A   198.51.100.20
```

Same names, different answers.

---

## Firewall Enforcement (pfSense)

### Client DNS Rules

```text
Allow: Clients → Internal DNS UDP/TCP 53
Block: Clients → Any UDP/TCP 53
```

### External Access Control

```text
Block: WAN → Internal DNS
Allow: WAN → Public Services Only
```

Internal DNS servers should never be reachable externally.

---

## iptables Hardening for Split-Brain DNS

### Internal DNS Server

```bash
# Allow internal queries only
iptables -A INPUT -p udp --dport 53 -s 10.10.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -s 10.10.0.0/16 -j ACCEPT

# Block external DNS queries
iptables -A INPUT -p udp --dport 53 -j DROP
iptables -A INPUT -p tcp --dport 53 -j DROP
```

---

## DNSSEC and Split-Brain DNS

* External zones: DNSSEC strongly recommended
* Internal zones:

  * Optional
  * Useful against internal spoofing
* Do NOT mix DS records between internal and external zones

Each zone signs independently.

---

## Common Split-Brain DNS Mistakes

* Publishing internal records externally
* Allowing recursion on public DNS servers
* Using the same DNS servers for internal and external zones
* Forgetting to block WAN access to internal DNS
* Not documenting zone differences

---

## Detection & Validation (CCDC)

### Test Internal vs External Resolution

```bash
dig @10.10.10.1 www.example.com
dig @8.8.8.8 www.example.com
```

Results should differ.

---

## Emergency CCDC Playbook

**If internal records leak externally:**

1. Remove records from public zone immediately
2. Flush public DNS caches if possible
3. Rotate exposed IPs or credentials if necessary
4. Review zone transfer permissions

```

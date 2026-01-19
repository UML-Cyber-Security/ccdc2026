# IPv6 in Network Security and CCDC Environments

## What is IPv6?

**IPv6** (Internet Protocol version 6) is the successor to IPv4, designed to solve the IPv4 address exhaustion problem. Instead of 32-bit addresses (4.3 billion), IPv6 uses 128-bit addresses (340 undecillion addresses - that's 340 trillion trillion trillion).

**IPv4 address**: `192.168.1.100`
**IPv6 address**: `2001:0db8:85a3:0000:0000:8a2e:0370:7334` (or shortened: `2001:db8:85a3::8a2e:370:7334`)

## Why IPv6 Matters in CCDC (And Why It's Dangerous)

### The CCDC Problem
**Most teams forget about IPv6 entirely.** This is one of the biggest security holes in CCDC competitions:

1. **You configure firewall rules for IPv4** → Attackers connect via IPv6 and bypass everything
2. **You monitor IPv4 traffic** → IPv6 attacks go completely unnoticed
3. **You disable services on IPv4** → They're still running on IPv6
4. **You block an attacker's IPv4** → They switch to IPv6 and continue

**Real CCDC scenario**: Your team spends hours hardening SSH, blocking brute force attempts on IPv4. Attacker connects via IPv6, SSH accepts the connection, game over. This happens **all the time**.

### Why Attackers Love IPv6 in CCDC

1. **Usually completely unmonitored** - Teams forget it exists
2. **Firewall rules often don't apply** - iptables rules don't affect ip6tables
3. **Services listen on IPv6 by default** - SSH, HTTP, everything
4. **Automatic configuration** - SLAAC means hosts auto-configure IPv6
5. **Tunneling** - Attackers can tunnel IPv6 over IPv4 to bypass restrictions
6. **Address space** - Huge address space makes scanning harder but also hides attackers

## IPv6 Fundamentals You Need to Know

### Address Types

**Global Unicast** (like public IPv4):
- `2000::/3` - Routable on the internet
- Example: `2001:db8:1234:5678::1`
- These are your "public" addresses

**Link-Local** (automatic, non-routable):
- `fe80::/10` - Automatically assigned to every interface
- Example: `fe80::1`
- Only works on the local network segment
- **CCDC Risk**: Attackers on your LAN can use link-local to bypass routing restrictions

**Unique Local** (like private IPv4 - RFC 4193):
- `fc00::/7` (typically `fd00::/8` used)
- Example: `fd12:3456:789a::1`
- Not routable on internet (like 192.168.x.x or 10.x.x.x)

**Loopback**:
- `::1` (equivalent to 127.0.0.1)

**Multicast**:
- `ff00::/8`
- Example: `ff02::1` (all nodes on link)
- Example: `ff02::2` (all routers on link)

### IPv6 Neighbor Discovery (ND)

IPv6 doesn't use ARP like IPv4. Instead, it uses **Neighbor Discovery Protocol (NDP)** with ICMPv6:

- **Router Solicitation (RS)**: "Any routers here?"
- **Router Advertisement (RA)**: "I'm a router, here's network info"
- **Neighbor Solicitation (NS)**: "Who has this IPv6 address?" (like ARP request)
- **Neighbor Advertisement (NA)**: "I have that address" (like ARP reply)

**CCDC Risk**: Attackers can send fake Router Advertisements to redirect traffic, conduct MitM attacks, or cause DoS.

### SLAAC (Stateless Address Auto-Configuration)

IPv6 hosts can automatically configure addresses without DHCP:

1. Host generates link-local address (`fe80::`)
2. Host sends Router Solicitation
3. Router sends Router Advertisement with network prefix
4. Host combines prefix with its own identifier → global address

**CCDC Risk**: 
- Hosts auto-configure IPv6 even if you only set up IPv4
- Attackers can spoof Router Advertisements
- You might not know what IPv6 addresses your hosts have

## CCDC IPv6 Attack Scenarios

### Scenario 1: The "Forgot About IPv6" Attack

**What happens**:
1. You lock down SSH on IPv4: `iptables -A INPUT -p tcp --dport 22 -j DROP`
2. SSH is still listening on IPv6: `:::22`
3. Attacker connects: `ssh user@2001:db8::10`
4. Your firewall doesn't block it because ip6tables has no rules
5. Attacker is in

**How to detect**:
```bash
# Check what's listening on IPv6
netstat -ln6 | grep LISTEN
ss -ln6 | grep LISTEN

# You might see:
tcp6  0  0 :::22  :::*  LISTEN  # SSH open to world on IPv6!
tcp6  0  0 :::3306  :::*  LISTEN  # MySQL exposed on IPv6!
```

**Prevention**:
```bash
# Block everything on IPv6 by default
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

# Allow only what you need (similar to IPv4)
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT
ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

### Scenario 2: Rogue Router Advertisement Attack

**What happens**:
1. Attacker on your LAN sends fake Router Advertisement
2. Claims to be the default gateway
3. All IPv6 traffic now routes through attacker's machine
4. Attacker can intercept, modify, or drop traffic
5. MitM attack successful

**Detection**:
```bash
# Monitor for Router Advertisements
tcpdump -i eth0 -n 'icmp6 && ip6[40] == 134'

# Or use radvdump
radvdump

# Look for unexpected RAs
```

**Prevention**:
```bash
# Disable IPv6 router advertisements (if you're not the router)
sysctl -w net.ipv6.conf.all.accept_ra=0
sysctl -w net.ipv6.conf.default.accept_ra=0
sysctl -w net.ipv6.conf.eth0.accept_ra=0

# Make permanent in /etc/sysctl.conf
echo "net.ipv6.conf.all.accept_ra = 0" >> /etc/sysctl.conf
```

### Scenario 3: Tunneling and Covert Channels

**What happens**:
1. You block outbound connections on IPv4
2. Attacker uses IPv6-in-IPv4 tunneling (6to4, Teredo, ISATAP)
3. Their traffic tunnels out over your IPv4 network
4. Your monitoring doesn't see it
5. Data exfiltration successful

**Common tunneling protocols**:
- **6to4**: Uses IPv4 protocol 41
- **Teredo**: Tunnels IPv6 over UDP port 3544
- **ISATAP**: Intra-Site Automatic Tunnel Addressing Protocol

**Detection**:
```bash
# Check for tunnel interfaces
ip -6 tunnel show
ip link show type sit  # 6to4 tunnels

# Monitor for protocol 41 (6to4)
tcpdump -i eth0 proto 41

# Monitor for Teredo (UDP 3544)
tcpdump -i eth0 udp port 3544
```

**Prevention**:
```bash
# Block IPv6 tunneling protocols in iptables
iptables -A INPUT -p 41 -j DROP    # 6to4
iptables -A INPUT -p udp --dport 3544 -j DROP  # Teredo
iptables -A OUTPUT -p 41 -j DROP
iptables -A OUTPUT -p udp --dport 3544 -j DROP

# Disable IPv6 tunneling modules
modprobe -r sit
modprobe -r ipip
modprobe -r ip6_tunnel
echo "blacklist sit" >> /etc/modprobe.d/blacklist.conf
echo "blacklist ipip" >> /etc/modprobe.d/blacklist.conf
echo "blacklist ip6_tunnel" >> /etc/modprobe.d/blacklist.conf
```

### Scenario 4: IPv6 Service Discovery

**What happens**:
1. Attackers use IPv6 multicast for service discovery
2. They send packets to `ff02::1` (all nodes)
3. Services respond revealing their presence
4. Attacker maps your network without triggering IDS

**Example attack**:
```bash
# Attacker scans for web servers on IPv6
ping6 ff02::1%eth0  # Ping all nodes
nmap -6 fe80::1-ff%eth0  # Scan link-local range
```

**Prevention**:
```bash
# Block multicast from untrusted sources
ip6tables -A INPUT -m pkttype --pkt-type multicast -j DROP
# Or limit to specific multicast addresses you need
```

## CCDC IPv6 Defense Strategies

### Strategy 1: "Disable IPv6 Completely" (Scorched Earth)

**When to use**: When you have no legitimate IPv6 requirements and want to eliminate the attack surface entirely.

**How to disable**:

**Method 1: Kernel parameter (immediate)**:
```bash
# Disable IPv6 on all interfaces
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

# Make permanent
cat >> /etc/sysctl.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

sysctl -p
```

**Method 2: GRUB (requires reboot)**:
```bash
# Edit /etc/default/grub
GRUB_CMDLINE_LINUX="ipv6.disable=1"

# Update GRUB
update-grub  # Debian/Ubuntu
grub2-mkconfig -o /boot/grub2/grub.cfg  # RHEL/CentOS

# Reboot required
```

**Method 3: Module blacklist**:
```bash
# Prevent IPv6 module from loading
echo "blacklist ipv6" >> /etc/modprobe.d/blacklist.conf
update-initramfs -u
```

**Verification**:
```bash
# Should show no IPv6 addresses
ip -6 addr show

# Should show "Protocol not available"
ping6 ::1
```

**Pros**:
- Eliminates entire IPv6 attack surface
- Simple to implement
- No complexity

**Cons**:
- Scoring engine might use IPv6 (rare but possible)
- Some applications might break (also rare)
- Not a learning opportunity

**CCDC Recommendation**: This is often the safest choice if you're unsure. Disable IPv6 in the first 30 minutes, verify scoring still works, move on to other tasks.

### Strategy 2: "Lockdown IPv6" (Parallel Security)

**When to use**: When IPv6 is required or you want to maintain it for learning/completeness.

**Implementation**: Mirror your IPv4 security posture on IPv6.### Strategy 3: "Monitor and Alert" (Detection)

Even if you lock down IPv6, you should monitor for IPv6 activity to detect attacks.## pfSense IPv6 Configuration

pfSense has excellent IPv6 support, but you need to configure it carefully for CCDC.

### pfSense IPv6 Setup - Security-First Approach

**Option 1: Disable IPv6 Completely in pfSense**

1. Navigate to **System → Advanced → Networking**
2. Check "**Disable IPv6**"
3. Click Save
4. Reboot pfSense

**This is often the safest CCDC approach.**

**Option 2: Enable IPv6 with Strict Firewall Rules**

If you need IPv6 functionality:

1. **Interfaces → WAN**
   - IPv6 Configuration Type: None (or DHCP6/Static if required)
   - Block bogon networks: ✓ Checked
   - Block private networks: ✓ Checked

2. **Interfaces → LAN**
   - IPv6 Configuration Type: Track Interface or Static
   - If using Track Interface:
     - IPv6 Prefix ID: 0
   - If using Static:
     - Use a ULA prefix: `fd00::/64` or similar

3. **Services → Router Advertisements**
   - Router Advertisements: Disabled (or Managed - for DHCPv6 only)
   - Router Priority: Normal
   - **DO NOT use Assisted or SLAAC** - this allows auto-configuration which is a security risk

4. **Firewall → Rules → WAN (IPv6)**

Create these rules in order:

```
# Block all inbound IPv6 by default
Action: Block
Interface: WAN
Protocol: IPv6
Source: Any
Destination: Any
Description: Block all inbound IPv6

# Allow only established/related
Action: Pass
Interface: WAN  
Protocol: IPv6
Source: Any
Destination: Any
Advanced: State Type: Keep state, Allow established
Description: Allow established IPv6 connections
```

5. **Firewall → Rules → LAN (IPv6)**

```
# Block outbound IPv6 by default
Action: Block
Interface: LAN
Protocol: IPv6
Source: LAN net
Destination: Any
Description: Block all outbound IPv6

# Allow only specific services
Action: Pass
Interface: LAN
Protocol: IPv6 + TCP
Source: LAN net
Destination: Any
Destination Port: 80, 443 (HTTP/HTTPS)
Description: Allow web browsing

# Allow DNS
Action: Pass
Interface: LAN
Protocol: IPv6 + UDP
Source: LAN net
Destination: Any
Destination Port: 53
Description: Allow DNS
```

6. **System → Advanced → Firewall & NAT**
   - Disable
# VPN Architectures, Protocols, and Peering

## VPN Protocol Overview

### OpenVPN
**OpenVPN** is the most versatile and widely-used open-source VPN solution. It uses SSL/TLS for key exchange and can operate over UDP (faster, preferred) or TCP (more reliable through restrictive firewalls). It's highly configurable, works on virtually every platform, and can traverse NAT easily. The downside is it's not the fastest protocol and can be complex to configure properly.

**Best for**: Maximum compatibility, flexibility, and when you need to support various client platforms. It's the "safe choice" for CCDC because it just works.

### WireGuard
**WireGuard** is the modern VPN protocol that's incredibly fast, uses state-of-the-art cryptography, and has a tiny codebase (making it more secure and auditable). It's built into the Linux kernel as of version 5.6. It uses UDP only and creates a simple point-to-point tunnel with static IP assignments. The configuration is remarkably simple compared to OpenVPN.

**Best for**: Site-to-site VPNs, when performance matters, modern infrastructure. It's becoming the go-to choice for new deployments.

### IPsec (with IKEv2)
**IPsec** is the enterprise-standard VPN protocol, built into most operating systems. IKEv2 (Internet Key Exchange version 2) is the modern key exchange protocol used with IPsec. It's extremely fast, handles network changes well (MOBIKE support), and is natively supported on iOS, macOS, Windows, and most enterprise equipment. Configuration can be complex, especially certificate management.

**Best for**: Enterprise environments, mobile devices (excellent roaming support), when native OS support is crucial, pfSense-to-pfSense tunnels.

### L2TP/IPsec
**L2TP/IPsec** combines Layer 2 Tunneling Protocol with IPsec encryption. It's widely supported natively on operating systems but is slower than other options (double encapsulation) and can have NAT traversal issues. It's considered somewhat outdated but still commonly used for client VPNs.

**Best for**: Legacy compatibility when you can't install custom VPN clients.

### SSL VPN (like pfSense's built-in OpenVPN or Cisco AnyConnect)
**SSL VPNs** operate over HTTPS (TCP 443), making them nearly impossible to block. They often provide web-based access without requiring client software. pfSense includes OpenVPN-based SSL VPN functionality.

**Best for**: Restrictive network environments, web-based access requirements, clientless VPN needs.

## VPN Architectures

### Site-to-Site VPN
Connects entire networks together, creating a secure tunnel between two or more locations. Both ends have VPN gateways (like pfSense boxes), and clients on either network can access resources on the other transparently.

**CCDC Use Case**: Connect your main competition network to a backup/management network, or create redundant paths between network segments. If attackers compromise one path, you can route through another.

```
[Competition Network] --VPN Tunnel--> [Management Network]
   pfSense Router                        Backup pfSense
```

### Remote Access VPN (Road Warrior)
Individual clients connect to a central VPN server to access network resources. Each client gets a virtual IP address and can access the internal network as if they were physically present.

**CCDC Use Case**: During competition, team members can securely connect to your network from anywhere. This is crucial for distributed teams or if you need to manage systems remotely. Also useful for controlled out-of-band access to critical systems.

```
[Team Member Laptop] ---> [pfSense VPN Server] ---> [Internal Network]
[Team Member Laptop] ---> [pfSense VPN Server] ---> [Internal Network]
```

### Hub-and-Spoke VPN
A central hub (usually your main site) has VPN connections to multiple spoke sites. Spokes communicate with the hub and potentially with each other through the hub.

**CCDC Use Case**: If you've segmented your network into multiple isolated zones (DMZ, internal, management), you can use a hub-and-spoke model where a central pfSense instance acts as the hub connecting to each segment.

```
        [Hub - Main pfSense]
       /        |         \
      /         |          \
[DMZ Zone] [Web Zone] [Database Zone]
```

### Mesh VPN
Every node connects to every other node, creating a fully meshed network. This provides redundancy and optimal routing but becomes complex as the number of nodes increases (n*(n-1)/2 connections).

**CCDC Use Case**: For critical infrastructure where you need maximum redundancy. If one path fails, traffic automatically routes through another path. Tools like Tailscale or Nebula make this easier to manage.

```
[Node A] -------- [Node B]
   |    \       /    |
   |     \     /     |
   |      \ / \      |
   |       X   X     |
   |      / \ / \    |
   |     /   X   \   |
   |    /   / \   \  |
[Node C] -------- [Node D]
```

### VPN Concentrator
A dedicated device or server that handles many simultaneous VPN connections. This is essentially a scaled-up remote access VPN server optimized for handling hundreds or thousands of concurrent clients.

**CCDC Use Case**: Less relevant for typical CCDC scale, but if you're running a larger operation or providing VPN access to many people, pfSense can act as a concentrator.

## VPN Peering Concepts

### What is VPN Peering?
VPN peering is the process of establishing secure connections between different VPN networks or systems. This allows separate VPN infrastructures to communicate securely.

### BGP over VPN
Running Border Gateway Protocol over VPN tunnels allows dynamic routing between sites. When you establish IPsec tunnels between pfSense instances, you can run BGP to automatically exchange routes.

**CCDC Use Case**: If you have multiple sites or network segments with complex routing, BGP over VPN lets you dynamically advertise routes. If a path goes down, BGP automatically converges on a new path.

**Example Scenario**: You have three pfSense boxes creating a triangle of VPN tunnels. BGP running on each box automatically figures out the best path for traffic between networks, even if one tunnel fails.

### Route-Based vs Policy-Based VPNs

**Policy-Based VPNs** (traditional IPsec):
- Traffic is encrypted based on matching ACLs/policies
- Each "interesting traffic" rule creates a separate SA (Security Association)
- More complex configuration but very specific control
- Common in older enterprise equipment

**Route-Based VPNs** (VTI - Virtual Tunnel Interfaces):
- Creates a virtual interface that you route traffic through
- Much simpler routing configuration
- Easier to use with dynamic routing protocols like BGP or OSPF
- This is how WireGuard and modern VPN solutions work

**CCDC Preference**: Route-based VPNs are generally easier to manage and troubleshoot. pfSense supports both, but route-based (especially with WireGuard) is cleaner.

### Split Tunneling vs Full Tunneling

**Split Tunneling**:
- Only traffic destined for the VPN network goes through the tunnel
- Internet traffic goes directly from the client
- Faster for general internet use, less VPN server load
- **Security risk**: Traffic not protected by VPN when accessing internet

**Full Tunneling**:
- ALL traffic goes through the VPN tunnel
- Protects all traffic, but slower internet access
- More VPN server load and bandwidth usage
- **More secure**: All traffic is encrypted and monitored

**CCDC Recommendation**: Use full tunneling for team members accessing competition infrastructure. You want to monitor and protect all their traffic. Use split tunneling only if bandwidth becomes a critical issue.

## CCDC-Specific VPN Scenarios

### Scenario 1: Out-of-Band Management Network
Create a separate VPN that connects directly to management interfaces (iLO, iDRAC, switch/router management ports) on a different network segment.

**Why**: If attackers compromise your main network, you still have secure access to management interfaces. This is your "backup plan" for regaining control.

**Implementation**:
- Dedicated pfSense box or separate interface on main pfSense
- WireGuard VPN (fast, simple, modern)
- Only team members' devices have keys
- Routes ONLY to management subnet (10.0.99.0/24 or similar)
- Heavily firewalled - management traffic only

```
Team Laptop --WireGuard--> Management pfSense --> Management VLAN
                                                    (iLO, switches, etc.)
```

### Scenario 2: Redundant Internet Connection via VPN
If your competition network has internet connectivity, create a VPN to an external server/VPS that can serve as a backup path.

**Why**: If attackers DoS your primary internet connection or it fails, you have a backup route. You can route critical traffic (like scoring checks) through this VPN.

**Implementation**:
- OpenVPN or WireGuard to a cloud VPS (DigitalOcean, Vultr, etc.)
- Configure policy-based routing on pfSense
- Critical traffic (scoring engine IPs) preferentially routes through VPN
- Automatic failover if primary connection fails

### Scenario 3: Distributed Team Access
Your team is physically separated (some remote, some on-site). Everyone needs secure access to the competition network.

**Why**: Enables collaboration and allows remote team members to help during the competition.

**Implementation**:
- pfSense OpenVPN server (best client support)
- Each team member gets a certificate
- Full tunnel configuration (all traffic through VPN)
- Segmented access based on team roles (use firewall rules)
- Strong authentication (certificates + password)

**Security considerations**:
- Use certificate revocation if a laptop is compromised
- Monitor VPN connections for unusual activity
- Limit what VPN users can access (least privilege)
- Log all VPN authentication attempts

### Scenario 4: Site-to-Site for Network Segmentation
Create isolated network segments connected via VPN instead of routing them directly.

**Why**: If attackers compromise one segment, the VPN provides a chokepoint where you can filter traffic, and you can quickly disconnect segments by killing the VPN.

**Implementation**:
- WireGuard tunnels between pfSense instances in each segment
- Firewall rules on each pfSense control inter-segment traffic
- Log all traffic between segments
- Can quickly disable segment access if compromised

```
[Web DMZ] <--WireGuard--> [pfSense Hub] <--WireGuard--> [Database Segment]
pfSense A                  pfSense Main                 pfSense B
```

### Scenario 5: Encrypted C2 Channel
Create a hidden management channel using VPN for incident response and coordination.

**Why**: If attackers are monitoring your network, you need a covert channel to coordinate response without them knowing.

**Implementation**:
- WireGuard tunnel to external server on non-standard port
- Minimal traffic - only used for team communication/coordination
- SSH or encrypted chat over this tunnel
- Attackers monitoring main network don't see your coordination

## VPN Protocol Selection for CCDC

| Protocol | Setup Speed | Performance | Compatibility | Security | CCDC Rating |
|----------|-------------|-------------|---------------|----------|-------------|
| WireGuard | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **Best for site-to-site** |
| OpenVPN | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | **Best for client VPN** |
| IPsec/IKEv2 | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Good for pfSense-to-pfSense |
| L2TP/IPsec | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | Avoid unless necessary |

## Quick pfSense Configuration Tips

### WireGuard on pfSense
1. Install WireGuard package from Package Manager
2. Create tunnel: VPN → WireGuard → Tunnels → Add
3. Generate keys automatically
4. Assign interface to tunnel
5. Configure peer with public key and allowed IPs
6. Add firewall rules on WireGuard interface

**Pro tip**: Keep WireGuard configs simple. One peer = one purpose. Don't try to do complex routing with it initially.

### OpenVPN on pfSense
1. Set up Certificate Authority (System → Cert Manager)
2. Create server certificate
3. VPN → OpenVPN → Wizards → Start wizard
4. Choose "Remote Access (SSL/TLS + User Auth)"
5. Export client config (VPN → OpenVPN → Client Export)

**Pro tip**: Use the wizard. Seriously. Manual OpenVPN config in pfSense is tedious and error-prone under time pressure.

### IPsec on pfSense
1. VPN → IPsec → Tunnels → Add P1
2. Configure Phase 1 (IKE) - authentication method, encryption
3. Add Phase 2 (IPsec) - define networks, encryption
4. Add firewall rules on IPsec interface
5. Check Status → IPsec to verify

**Pro tip**: For pfSense-to-pfSense, use pre-shared keys during CCDC for speed. Certificates are more secure but take longer to set up.

## Common CCDC VPN Mistakes to Avoid

1. **Forgetting firewall rules**: Creating the VPN tunnel doesn't automatically allow traffic. You MUST add firewall rules on the VPN interface.

2. **Overlapping subnets**: If your VPN network uses 192.168.1.0/24 and your internal network also uses 192.168.1.0/24, nothing will work. Plan your IP addressing.

3. **Not testing failover**: Your VPN looks great until the competition starts and it fails under load. Test it beforehand.

4. **Complex routing without documentation**: You set up clever routing during setup, competition starts, something breaks, and you can't remember how you configured it. Document your VPN architecture.

5. **Weak authentication**: Using simple passwords for VPN access during a security competition is asking for trouble. Use certificates + passwords for OpenVPN.

6. **Not monitoring VPN logs**: VPN authentication failures might be the first sign someone is trying to access your network. Watch those logs.

7. **Over-engineering**: A simple WireGuard tunnel between two pfSense boxes is better than a complex IPsec setup with BGP that you don't fully understand. Keep it as simple as possible while meeting your needs.

## VPN Troubleshooting Quick Checks

When your VPN isn't working in CCDC:

1. **Can you ping the VPN endpoint?** (Basic connectivity)
2. **Is the VPN service running?** (Check pfSense Status → Services)
3. **Are firewall rules in place?** (On WAN, VPN interface, and LAN if needed)
4. **Check logs** (Status → System Logs → OpenVPN/IPsec/WireGuard)
5. **Verify routing** (Diagnostics → Routes)
6. **Check NAT** (Is traffic being NAT'd when it shouldn't be?)
7. **Certificate issues?** (System → Cert Manager - verify not expired)

## Recommended CCDC VPN Architecture

For a typical CCDC environment, I'd recommend:

**Primary Remote Access VPN**: OpenVPN
- Best client support
- Team members can connect from anywhere
- Full tunnel to protect all traffic

**Site-to-Site Between Segments**: WireGuard
- Fast, simple, modern
- Easy to add/remove peers
- Minimal configuration complexity

**Emergency Out-of-Band**: WireGuard to external VPS
- Backup access if main network compromised
- Fast setup in cloud (5 minutes on DigitalOcean)
- Small, secure, hard to detect

This combination gives you compatibility (OpenVPN), performance (WireGuard), and resilience (multiple VPN types) without over-complicating your infrastructure.
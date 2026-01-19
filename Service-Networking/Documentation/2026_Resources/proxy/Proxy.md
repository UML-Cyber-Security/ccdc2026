# Load Balancing and Reverse Proxying with Nginx and HAProxy

## Overview

**Nginx** and **HAProxy** are both powerful tools for load balancing and reverse proxying, but they excel in different areas:

**Nginx** is a versatile web server that also functions as a reverse proxy and load balancer. It's excellent for serving static content, SSL/TLS termination, and HTTP-based load balancing. It's particularly good at handling many concurrent connections efficiently and is commonly used for web applications.

**HAProxy** is a dedicated load balancer and proxy that excels at high-performance TCP and HTTP load balancing. It offers more advanced load balancing algorithms, better health checking, and superior performance for pure load balancing tasks. It's the go-to choice when you need maximum flexibility in routing decisions and advanced traffic management.

## CCDC Scenarios with pfSense

In a CCDC (Collegiate Cyber Defense Competition) environment where you're using pfSense as your edge firewall, here are practical scenarios:

### Scenario 1: Web Application Protection
You have multiple web servers behind pfSense. Use Nginx or HAProxy as a reverse proxy to:
- Hide your actual web server IPs from attackers
- Terminate SSL/TLS at the proxy layer (easier certificate management)
- Implement rate limiting to prevent DoS attacks
- Add an extra layer of logging and monitoring
- Quickly redirect traffic if a server is compromised

### Scenario 2: Service Redundancy
Deploy redundant services (web, mail, DNS) and use HAProxy to:
- Automatically fail over if one server goes down
- Distribute load across multiple servers
- Perform health checks to detect compromised or failing services
- Quickly isolate a compromised server by removing it from the pool

### Scenario 3: SSL/TLS Offloading
During CCDC, you're often dealing with legacy systems or quick deployments. Use Nginx to:
- Handle all SSL/TLS encryption/decryption at the proxy
- Protect backend servers that may not support modern TLS versions
- Centralize certificate management in one place
- Add security headers (HSTS, CSP, etc.) to all responses

### Scenario 4: Multi-Service Architecture
You're running multiple services (scoring engine, web apps, APIs) on different ports. Use HAProxy with pfSense to:
- Route traffic based on domain names (SNI routing) or URL paths
- Present a single external IP while distributing to multiple backend services
- Implement ACLs to restrict access to certain services
- Create a chokepoint for monitoring all inbound traffic

## Practical Deployment Scripts## Additional CCDC Tips and Suggestions

### pfSense Integration Considerations

1. **Port Forwarding**: Configure pfSense to forward ports 80/443 to your load balancer container host
2. **Firewall Rules**: Create rules to allow only necessary traffic to backend servers
3. **VLANs**: Place load balancers in a DMZ VLAN between pfSense and your web servers
4. **Monitoring**: Use pfSense's traffic graphs to detect anomalies that might indicate attacks

### Quick Security Wins

**Rate Limiting**: Both configs include rate limiting to protect against basic DoS attacks during competition. Adjust the rates based on your scoring engine's check frequency.

**Health Checks**: Automatic health checking means if a server gets compromised and stops responding correctly, it's automatically removed from the pool.

**Logging**: Centralized logging makes it much easier to spot attack patterns. In CCDC, you can quickly grep logs for suspicious IPs or patterns.

**SSL/TLS Termination**: Managing certificates at the load balancer level is much easier than on each backend server, especially under time pressure.

### Competition Day Checklist

- **Test failover** before competition starts (kill a backend, verify traffic continues)
- **Change default passwords** in HAProxy stats page
- **Verify logs are writing** properly for incident response
- **Document your architecture** (draw a quick network diagram)
- **Know how to quickly disable a compromised backend** (comment out server line, reload config)
- **Set up monitoring** on the stats pages (HAProxy has a great built-in one on port 8404)
- **Have backup configs** ready to redeploy if something breaks

### Choosing Between Nginx and HAProxy

**Use Nginx if:**
- You're more comfortable with web server configs
- You need to serve static content too
- You want simpler setup
- You're primarily load balancing HTTP/HTTPS

**Use HAProxy if:**
- You need advanced load balancing algorithms
- You want better observability (stats page is excellent)
- You need TCP load balancing for non-HTTP services
- You want more granular control over health checks and routing

Both are excellent choices for CCDC. I'd slightly lean toward HAProxy for competitions because its stats page is invaluable for troubleshooting under pressure, but Nginx is perfectly capable and might be faster to configure if you're already familiar with it.
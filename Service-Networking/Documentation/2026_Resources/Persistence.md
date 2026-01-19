# Session Persistence (Sticky Sessions) in Load Balancing

## What is Session Persistence?

**Session persistence**, also called **sticky sessions** or **session affinity**, is a mechanism that ensures requests from the same client are always directed to the same backend server for the duration of their session. Without this, load balancers distribute requests in a round-robin or least-connections manner, which can break applications that store session state locally on individual servers.

## Why Session Persistence Matters

### The Problem
Imagine you're running a web application behind a load balancer with three backend servers:

1. User logs into your web app, request goes to **Server A**
2. Server A creates a session, stores "user is authenticated" in memory
3. User clicks a link, load balancer sends this request to **Server B**
4. Server B has no session data for this user → user appears logged out
5. User gets frustrated, competition points are lost

### The Solution
Session persistence ensures that once a user connects to Server A, all their subsequent requests go to Server A (until the session expires or the server fails).

## Session Persistence Methods

### 1. Source IP Hash (IP-based Affinity)
The load balancer hashes the client's IP address and consistently routes that IP to the same backend server.

**How it works**:
```
hash(client_IP) % number_of_servers = assigned_server
```

**Pros**:
- Simple to implement
- Works with any protocol (HTTP, TCP, UDP)
- No cookies or application modification needed
- Client doesn't need to support cookies

**Cons**:
- Users behind NAT/proxy appear as same IP → all go to same server (poor distribution)
- Changing server pool breaks all sessions
- Not resilient if a server fails (users on that server lose sessions)
- Doesn't work well with mobile users who change networks/IPs

**CCDC Use Case**: Good for internal services where users have dedicated IPs, or for non-HTTP protocols where you can't use cookies. Not ideal for public-facing web apps with users behind NAT.

**HAProxy Config**:
```
balance source
hash-type consistent  # Better distribution when servers change
```

**Nginx Config**:
```
upstream backend {
    ip_hash;
    server backend1:80;
    server backend2:80;
}
```

### 2. Cookie-based Persistence
The load balancer inserts or reads a cookie that identifies which backend server should handle the request.

**How it works**:
1. Client makes first request (no cookie)
2. Load balancer routes to Server A using normal algorithm
3. Load balancer inserts cookie: `SERVERID=server_a`
4. Client's subsequent requests include this cookie
5. Load balancer reads cookie, always routes to Server A

**Pros**:
- Works correctly with users behind NAT/proxies
- Survives client IP changes (mobile roaming)
- Fine-grained control
- Can survive server restarts (if using application cookies)

**Cons**:
- Only works for HTTP/HTTPS
- Requires cookie support in client (usually not an issue)
- Cookies can be tampered with (use encryption/signing)
- May conflict with application cookies if not careful

**CCDC Use Case**: **This is your go-to method** for web applications. Most reliable, works with diverse client networks, and handles the scoring engine making requests from different IPs.

**HAProxy Config** (Load Balancer Sets Cookie):
```
backend web_backend
    balance roundrobin
    cookie SERVERID insert indirect nocache httponly secure
    server web1 10.0.1.10:80 check cookie web1
    server web2 10.0.1.11:80 check cookie web2
    server web3 10.0.1.12:80 check cookie web3
```

**HAProxy Config** (Application Sets Cookie):
```
backend web_backend
    balance roundrobin
    cookie PHPSESSID prefix nocache httponly secure
    server web1 10.0.1.10:80 check cookie web1
    server web2 10.0.1.11:80 check cookie web2
```

**Nginx Config** (with sticky module):
```
upstream backend {
    sticky cookie srv_id expires=1h domain=.example.com path=/;
    server backend1:80;
    server backend2:80;
}
```

### 3. Session ID in URL
The session identifier is embedded in the URL, and the load balancer routes based on this.

**How it works**:
```
https://example.com/app;jsessionid=ABC123XYZ
```
Load balancer extracts `ABC123XYZ`, hashes it, routes to consistent server.

**Pros**:
- Works without cookies
- Can be combined with cookie methods

**Cons**:
- Session IDs visible in URLs (security risk)
- URLs can be shared, causing session confusion
- SEO problems
- Difficult to implement correctly

**CCDC Use Case**: Avoid this unless you're dealing with a legacy application that specifically requires it (like some old Java apps with JSESSIONID in URLs).

### 4. HTTP Header-based Persistence
Route based on a specific HTTP header value.

**How it works**:
Load balancer reads a custom header like `X-User-ID` or `Authorization` token and routes consistently based on its value.

**Pros**:
- Works for APIs and modern web apps
- Can use JWT tokens or other identifiers
- More flexible than cookies for API-first applications

**Cons**:
- Requires application to send the header
- More complex to configure
- Not automatic like cookie insertion

**CCDC Use Case**: Good for REST APIs or microservices where you're already using authentication tokens. The load balancer can hash the JWT subject claim or API key to route consistently.

**HAProxy Config**:
```
backend api_backend
    balance hdr(Authorization)
    hash-type consistent
    server api1 10.0.2.10:80 check
    server api2 10.0.2.11:80 check
```

### 5. SSL Session ID Persistence
For SSL/TLS connections, route based on the SSL Session ID.

**How it works**:
The SSL handshake creates a session ID. The load balancer routes all requests with the same SSL session ID to the same backend.

**Pros**:
- Works at the TLS layer
- Transparent to application
- Good for encrypted non-HTTP protocols

**Cons**:
- SSL session IDs can change
- Not reliable for long-lived sessions
- Doesn't work with TLS 1.3 session tickets properly

**CCDC Use Case**: Rarely needed. Use cookie-based for HTTP/HTTPS. Consider this only for specific protocols that require TLS but aren't HTTP.

## When You DON'T Need Session Persistence

### Stateless Applications
If your application stores session data in a shared backend (Redis, database, memcached) rather than locally on each web server, you **don't need sticky sessions**. This is the **preferred architecture** if you have time to implement it.

**Example Architecture**:
```
[Client] → [Load Balancer] → [Web Server 1] ↘
                           → [Web Server 2] → [Redis Session Store]
                           → [Web Server 3] ↗
```

Each web server stores/retrieves session data from Redis. The load balancer can route requests anywhere without breaking sessions.

**Benefits**:
- Better load distribution
- True high availability (server failure doesn't lose sessions)
- Easier scaling
- No session persistence complexity

**CCDC Reality**: You usually don't have time to refactor applications to use shared session storage. Sticky sessions are the quick fix.

### Read-Only Applications
If your application doesn't have user sessions (static content, APIs with per-request authentication), you don't need persistence.

### Properly Designed APIs
RESTful APIs should be stateless - every request contains all necessary information. If your API truly follows this principle, no persistence needed.

## Session Persistence Failure Scenarios

### What Happens When a Server Fails?

**With IP Hash**:
- All users on the failed server lose their sessions
- They're redistributed to remaining servers
- Users must re-authenticate/restart their work

**With Cookies (LB-inserted)**:
- Load balancer detects server failure via health check
- Requests with cookie pointing to failed server are re-routed
- User loses session but can re-authenticate
- New cookie is set for different server

**With Shared Session Storage (stateless)**:
- Server fails, load balancer routes to healthy server
- New server retrieves session from Redis/DB
- User experience is seamless
- **This is the gold standard**

## CCDC-Specific Session Persistence Scenarios

### Scenario 1: E-Commerce Application with Shopping Carts
**Problem**: Your e-commerce app stores shopping cart data in local server memory. Without sticky sessions, users' carts appear to empty randomly as requests bounce between servers.

**Solution**: 
- **Quick Fix (CCDC day-of)**: Enable cookie-based sticky sessions in HAProxy/Nginx
- **Better Fix (if you have time)**: Move cart storage to Redis or database

**HAProxy Config**:
```
backend ecommerce
    balance roundrobin
    cookie SHOPID insert indirect nocache httponly secure
    option httpchk GET /health
    server shop1 10.0.10.10:80 check cookie shop1
    server shop2 10.0.10.11:80 check cookie shop2
```

**Why this works**: Each user gets a cookie tying them to a specific server. Their cart data stays on that server.

### Scenario 2: Legacy PHP Application with File-based Sessions
**Problem**: Old PHP app using default file-based sessions (`/var/lib/php/sessions`). Sessions stored locally on each web server.

**Solution**:
- **Quick**: Cookie-based persistence in load balancer
- **Medium**: Configure PHP to use shared session storage
- **Better**: Use `session.save_handler = redis` in php.ini

**Quick Fix - Nginx**:
```
upstream php_backend {
    sticky cookie phpsessid expires=30m;
    server php1:80;
    server php2:80;
}
```

**Medium Fix - PHP Config** (if you have time):
```ini
# /etc/php/7.4/fpm/php.ini
session.save_handler = redis
session.save_path = "tcp://redis-server:6379"
```

**CCDC Reality**: During competition, go with the sticky sessions. Document the session.save_handler change for later if you have time.

### Scenario 3: Admin Portal with Login Sessions
**Problem**: Your admin portal requires authentication. Admins keep getting logged out randomly because requests hit different servers that don't have their session data.

**Solution**: Cookie-based persistence

**HAProxy Config**:
```
frontend admin_front
    bind *:443 ssl crt /etc/ssl/admin.pem
    default_backend admin_backend

backend admin_backend
    balance roundrobin
    cookie ADMINID insert indirect nocache httponly secure
    
    # Longer timeout for admin sessions
    timeout server 3600s
    
    # Strict health check - only route to healthy servers
    option httpchk GET /admin/health
    http-check expect status 200
    
    server admin1 10.0.20.10:80 check inter 5s cookie admin1
    server admin2 10.0.20.11:80 check inter 5s cookie admin2
```

**Additional security**: Consider also using IP hash as a secondary check to prevent cookie theft:
```
# Combine methods for security
stick-table type ip size 100k expire 30m
stick on src
cookie ADMINID insert indirect nocache httponly secure
```

### Scenario 4: Scoring Engine Compatibility
**Problem**: The CCDC scoring engine hits your web app to verify services. It might come from different IPs or not support cookies properly, breaking session-based checks.

**Solution**: Detect scoring engine and bypass sticky sessions for it

**HAProxy Config**:
```
backend web_backend
    # ACL to detect scoring engine
    acl is_scoring_engine hdr_sub(User-Agent) -i "scoring" "checker"
    acl is_scoring_ip src 10.0.99.10
    
    # Use round-robin for scoring engine (stateless)
    use-server web1 if is_scoring_engine !is_scoring_ip
    use-server web2 if is_scoring_engine is_scoring_ip
    
    # Normal users get sticky sessions
    balance roundrobin
    cookie WEBID insert indirect nocache httponly
    server web1 10.0.10.10:80 check cookie web1
    server web2 10.0.10.11:80 check cookie web2
```

**Why this matters**: Scoring engines often don't maintain cookies between checks. If they hit a different server each time and your app requires session state, checks might fail.

### Scenario 5: WebSocket Applications (Real-time Chat, Dashboards)
**Problem**: WebSocket connections are long-lived. If they get routed to different servers mid-connection, they break.

**Solution**: IP hash or cookie-based persistence, plus special WebSocket handling

**Nginx Config**:
```
upstream websocket_backend {
    ip_hash;  # Ensures same client always hits same server
    server ws1:8080;
    server ws2:8080;
}

server {
    listen 443 ssl;
    server_name chat.example.com;
    
    location /ws/ {
        proxy_pass http://websocket_backend;
        
        # WebSocket upgrade headers
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Preserve client info
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # Longer timeouts for WebSocket
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

**HAProxy Config**:
```
backend websocket_backend
    balance source  # IP-based persistence
    
    # Detect WebSocket upgrade
    option http-server-close
    
    # Long timeout for WebSocket connections
    timeout tunnel 3600s
    
    server ws1 10.0.30.10:8080 check
    server ws2 10.0.30.11:8080 check
```

## Advanced: Handling Session Persistence Failures

### Session Draining
When you need to take a server out of rotation (maintenance, suspected compromise), you want existing sessions to complete but no new sessions to start.

**HAProxy - Graceful Shutdown**:
```
# Mark server as drain - no new sessions
echo "set server web_backend/web1 state drain" | socat stdio /var/run/haproxy.sock

# Wait for sessions to complete
# Monitor with: echo "show sess" | socat stdio /var/run/haproxy.sock

# Then fully disable
echo "set server web_backend/web1 state maint" | socat stdio /var/run/haproxy.sock
```

**CCDC Use**: If you suspect a web server is compromised, drain it to let current users finish while preventing new infections.

### Session Replication
Some applications support active session replication between servers. If configured, sessions are copied to multiple servers, providing resilience.

**Examples**:
- Tomcat cluster with session replication
- JBoss/WildFly with distributed sessions
- .NET with SQL Server or StateServer session storage

**CCDC Reality**: This is usually pre-configured or too complex to set up during competition. But if your app has it, enable it for better resilience.

### Backup Server with Session Dump
A creative solution when you can't do proper session replication:

**Concept**:
1. Primary servers periodically dump active sessions to shared storage
2. If server fails, backup server loads the session dumps
3. Users might need to retry their request, but sessions are preserved

**CCDC Use**: Probably too complex for competition day, but good for documentation/write-ups.

## Monitoring Session Persistence

### HAProxy Stats Page
HAProxy's built-in stats page (`:8404/stats`) shows:
- Which server each session is on
- Number of active sessions per server
- Session distribution (are they balanced or all on one server?)

### Check Cookie Distribution
```bash
# See which cookies are being set
curl -I https://your-app.com | grep -i cookie

# Follow redirects and see sticky cookie
curl -L -c cookies.txt https://your-app.com
cat cookies.txt
```

### Verify Persistence
```bash
# Make multiple requests, verify same backend
for i in {1..10}; do
    curl -b cookies.txt https://your-app.com 2>&1 | grep "Server:"
done
```

All responses should show the same server if persistence is working.

### Monitor Session Loss
Watch your application logs for sudden authentication failures or session errors:
```bash
# If you see spikes in "invalid session" errors, persistence might be broken
tail -f /var/log/webapp/error.log | grep -i "session"
```

## Common Session Persistence Mistakes in CCDC

### 1. Forgetting to Enable Cookies
You configure sticky sessions but forget to actually insert/read cookies.

**Symptom**: Users randomly logged out, shopping carts emptying

**Fix**: Verify cookie is being set:
```bash
curl -I https://your-site.com | grep Set-Cookie
```

### 2. Cookie Name Conflicts
Your application sets a cookie named `SESSIONID`, and your load balancer also tries to use `SESSIONID`.

**Symptom**: Weird behavior, sessions not persisting correctly

**Fix**: Use different names for LB cookies vs app cookies, or use cookie prefix mode in HAProxy.

### 3. Too Short Cookie Expiry
Setting cookie expiry too short causes sessions to break prematurely.

**Symptom**: Users logged out after a few minutes even while active

**Fix**: Set appropriate expiry:
```
cookie SERVERID insert indirect nocache expires=1h
```

### 4. Not Handling Server Failures
You enable persistence but don't configure health checks. Failed server keeps getting requests.

**Symptom**: Some users can't access the site at all

**Fix**: Always combine persistence with health checks:
```
option httpchk GET /health
server web1 10.0.10.10:80 check inter 5s
```

### 5. SSL/TLS Issues
Using sticky cookies over HTTP but application redirects to HTTPS, cookies are lost.

**Symptom**: Sticky sessions work sometimes but not others

**Fix**: Set cookies with `secure` flag and ensure load balancer handles SSL properly:
```
cookie SERVERID insert indirect nocache httponly secure
```

### 6. Scoring Engine False Failures
Your sticky session config requires cookies, but scoring engine doesn't support them.

**Symptom**: Services fail scoring checks but work fine for manual testing

**Fix**: Whitelist scoring engine IP or user-agent to bypass sticky sessions for health checks.

## Quick Decision Tree

**Do you need session persistence?**

```
Does your app store state locally on each server?
├─ YES → You need session persistence
│   ├─ Is it HTTP/HTTPS?
│   │   ├─ YES → Use cookie-based (HAProxy: cookie insert)
│   │   └─ NO → Use IP hash (balance source)
│   └─ Are sessions critical (e-commerce, auth)?
│       ├─ YES → Consider migrating to shared storage (Redis)
│       └─ NO → Cookie-based is fine
└─ NO (stateless app) → No persistence needed
    └─ Use round-robin or least-connections for best distribution
```

## Recommended CCDC Approach

**For most web applications in CCDC**:

1. **Use cookie-based sticky sessions** (HAProxy `cookie insert` or Nginx `sticky`)
2. **Enable health checks** so failed servers are removed from rotation
3. **Set reasonable timeouts** (30 minutes to 1 hour for web sessions)
4. **Monitor the stats page** to verify even distribution
5. **Document which apps need stickiness** so you can quickly reconfigure if needed
6. **Have a fallback plan**: If persistence breaks and you can't fix it quickly, can you restart all backend servers at once to clear all sessions and start fresh?

**If you have extra time** (post-initial-setup):
- Migrate to shared session storage (Redis/Memcached)
- This eliminates the need for sticky sessions entirely
- Much more robust, but takes time to implement

The beauty of cookie-based sticky sessions is they're a configuration change in your load balancer - no application changes needed. Perfect for CCDC when you're under time pressure and just need things to work.
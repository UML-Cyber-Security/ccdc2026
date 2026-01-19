# Rate Limiting in Load Balancers and Web Applications

## What is Rate Limiting?

**Rate limiting** is a technique to control the rate at which clients can make requests to your services. It's a critical defense mechanism that prevents abuse, protects against DoS attacks, and ensures fair resource usage among clients.

Think of it like a bouncer at a club who says "you can only enter 10 times per minute" - if you try to rush the door 100 times in a second, you get blocked.

## Why Rate Limiting Matters (Especially in CCDC)

During CCDC, you're under active attack. Rate limiting is one of your most effective defenses:

1. **Mitigates DoS/DDoS attacks**: Attackers can't overwhelm your servers with requests
2. **Protects brute-force targets**: Login pages, admin panels, API endpoints
3. **Preserves resources**: Prevents one abusive client from impacting all users
4. **Buys you time**: Slows down attackers while you investigate and respond
5. **Protects scoring**: Ensures the scoring engine can get through while attackers are blocked

**The CCDC Reality**: You will be attacked. Rate limiting might be the difference between staying online and going down in the first hour.

## Rate Limiting Strategies

### 1. Fixed Window
Count requests in fixed time windows (e.g., "100 requests per minute").

**How it works**:
```
Window: 12:00:00 - 12:00:59
Count: 0
Request at 12:00:01 → Count: 1 → Allow
Request at 12:00:02 → Count: 2 → Allow
...
Request at 12:00:59 → Count: 100 → Allow
Request at 12:00:59 → Count: 101 → DENY
[Window resets at 12:01:00, count back to 0]
```

**Pros**:
- Simple to implement
- Low memory usage
- Predictable behavior

**Cons**:
- **Window edge problem**: User can make 100 requests at 12:00:59 and another 100 at 12:01:00 (200 in 2 seconds)
- Can be gamed by timing requests around window boundaries
- Bursty traffic patterns

**CCDC Use**: Good enough for basic protection, but not ideal for critical endpoints.

**Example**: Limiting general web traffic where occasional bursts are acceptable.

### 2. Sliding Window
Similar to fixed window but the window slides with time, providing smoother limiting.

**How it works**:
```
Limit: 100 requests per 60 seconds
Current time: 12:00:30

Look back 60 seconds:
- Requests from 11:59:30 to 12:00:30
- Count them
- If < 100, allow
- If >= 100, deny

Each new request recalculates the window
```

**Pros**:
- More accurate than fixed window
- No edge-case exploits
- Smoother rate limiting

**Cons**:
- More complex to implement
- Higher memory usage (must track individual request timestamps)
- More CPU intensive

**CCDC Use**: Better for critical endpoints like admin panels or APIs where you need precise control.

**Example**: Protecting login endpoints from brute force.

### 3. Token Bucket
A bucket holds tokens. Each request consumes a token. Tokens are added at a fixed rate. When the bucket is empty, requests are denied.

**How it works**:
```
Bucket capacity: 100 tokens
Refill rate: 10 tokens/second

Initial state: 100 tokens
Request arrives → 99 tokens (allowed)
Request arrives → 98 tokens (allowed)
...
[After 10 seconds, bucket refilled by 100 tokens, capped at capacity]

Burst scenario:
- 100 requests instantly → 0 tokens (all allowed)
- 101st request → no tokens (denied)
- Wait 1 second → 10 tokens added
- Next 10 requests allowed
```

**Pros**:
- Allows controlled bursts (up to bucket capacity)
- Smooth rate limiting over time
- Industry standard (used by AWS, Google Cloud)
- Handles bursty traffic gracefully

**Cons**:
- More complex than fixed window
- Can be harder to tune properly
- Requires more state tracking

**CCDC Use**: **This is the gold standard**. Allows legitimate bursts (like scoring engine doing multiple checks) while preventing sustained abuse.

**Example**: API rate limiting where occasional bursts are legitimate but sustained high rates indicate abuse.

### 4. Leaky Bucket
Requests are added to a queue (bucket). The queue is processed at a fixed rate. If the queue is full, new requests are dropped.

**How it works**:
```
Bucket capacity: 50 requests
Process rate: 10 requests/second

Queue: []
10 requests arrive → Queue: [10 requests] → Process 10/sec
50 more requests arrive → Queue: [50 requests, 10 processing]
10 more requests arrive → Queue FULL → Requests dropped

Output is always smooth 10 req/sec
```

**Pros**:
- Extremely smooth output rate
- Perfect for protecting downstream services
- Handles bursts by queuing

**Cons**:
- Adds latency (requests wait in queue)
- Can drop legitimate requests during attacks
- Queue management complexity

**CCDC Use**: Good for protecting backend services that can't handle bursts, but the latency might impact user experience. Less common than token bucket.

**Example**: Protecting a database backend that can only handle 100 queries/second.

### 5. Concurrent Connection Limiting
Limit the number of simultaneous connections from a client, rather than request rate.

**How it works**:
```
Limit: 10 concurrent connections per IP

Client opens connection 1 → Total: 1 → Allow
Client opens connection 2 → Total: 2 → Allow
...
Client opens connection 10 → Total: 10 → Allow
Client opens connection 11 → Total: 11 → DENY

Connection 1 closes → Total: 9 → Can accept new connection
```

**Pros**:
- Protects against connection exhaustion attacks
- Simpler than request-rate limiting
- Works for any protocol (HTTP, TCP, etc.)

**Cons**:
- Doesn't prevent slow-rate attacks
- Legitimate users might hit limits with modern browsers (many parallel connections)
- Keep-alive connections can cause false limits

**CCDC Use**: Combine with rate limiting for defense in depth. Prevents attackers from holding open thousands of connections.

**Example**: Limiting connections to prevent Slowloris attacks.

## Rate Limiting Scopes

### Per IP Address
Most common: limit requests from each unique IP address.

**Pros**:
- Simple to implement
- Effective against single-source attacks

**Cons**:
- Users behind NAT/proxies share limits
- Doesn't protect against distributed attacks
- Can block legitimate users sharing IP

**CCDC Use**: Your baseline rate limit. Always implement this.

### Per User/Account
Limit requests per authenticated user.

**Pros**:
- Fair for shared IPs (NAT/proxies)
- Allows different limits per user tier
- Protects individual accounts from abuse

**Cons**:
- Requires authentication
- Doesn't protect unauthenticated endpoints
- Attackers can create multiple accounts

**CCDC Use**: Implement for authenticated areas (admin panel, user dashboards).

### Per API Key
Common for APIs: each API key has its own rate limit.

**Pros**:
- Easy to track and manage
- Different limits for different integrations
- Can revoke abusive keys

**Cons**:
- Only works for APIs requiring keys
- Keys can be stolen/shared

**CCDC Use**: If you have APIs, definitely implement this.

### Global
Limit total requests to the entire service regardless of source.

**Pros**:
- Protects overall system capacity
- Simple "circuit breaker" pattern

**Cons**:
- DDoS can trigger it, denying service to everyone
- First-come-first-served isn't always fair

**CCDC Use**: Use as a last-resort protection when under massive attack. "Better to serve some users than none."

### Per Endpoint
Different rate limits for different URLs/endpoints.

**Pros**:
- Expensive endpoints (search, reports) get tighter limits
- Cheap endpoints (static assets) get loose limits
- Login endpoints get special brute-force protection

**Cons**:
- More complex configuration
- Must maintain multiple counters

**CCDC Use**: **Essential**. Login pages need 5 req/min, APIs need 100 req/min, static content needs 1000 req/min.

## CCDC Rate Limiting Scenarios

### Scenario 1: Protecting Login Pages from Brute Force
**Problem**: Attackers are brute-forcing your admin login. Thousands of login attempts per second.

**Solution**: Aggressive rate limiting on login endpoints

**HAProxy Config**:
```
frontend web_front
    bind *:443 ssl crt /etc/ssl/cert.pem
    
    # Track requests per IP
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    
    # ACL to identify login endpoints
    acl is_login path_beg /login /admin/login /wp-login.php
    
    # Very strict rate limit for login attempts
    # 5 requests per 10 seconds = 30 per minute
    http-request deny deny_status 429 if is_login { sc_http_req_rate(0) gt 5 }
    
    # Add delay to failed logins (optional, more advanced)
    # This makes brute forcing even slower
    
    default_backend web_backend

backend web_backend
    server web1 10.0.1.10:80 check
```

**Nginx Config**:
```
http {
    # Define rate limit zone for login
    # 10MB can track ~160k IP addresses
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
    
    server {
        listen 443 ssl;
        
        # Login endpoints
        location ~ ^/(login|admin) {
            limit_req zone=login_limit burst=3 nodelay;
            limit_req_status 429;
            
            # Return helpful error message
            error_page 429 = @ratelimit;
            
            proxy_pass http://backend;
        }
        
        location @ratelimit {
            return 429 "Rate limit exceeded. Try again later.\n";
            add_header Content-Type text/plain;
        }
    }
}
```

**Why this works**: 
- Legitimate users rarely make more than 5 login attempts in 10 seconds
- Brute force tools making thousands of attempts are immediately blocked
- You can still log in while attackers are locked out

**CCDC Pro Tip**: Set different limits for known-good IPs (your team, scoring engine):
```
# HAProxy - whitelist scoring engine
acl is_scoring_ip src 10.0.99.10
http-request deny deny_status 429 if is_login !is_scoring_ip { sc_http_req_rate(0) gt 5 }
```

### Scenario 2: API Rate Limiting by Key
**Problem**: You have an API that attackers are hammering. You need to allow legitimate users while blocking abuse.

**Solution**: Rate limit per API key with different tiers

**HAProxy Config**:
```
frontend api_front
    bind *:443 ssl crt /etc/ssl/cert.pem
    
    # Extract API key from header
    http-request set-var(txn.api_key) req.hdr(X-API-Key)
    
    # Track requests per API key
    stick-table type string len 64 size 10k expire 60s store http_req_rate(60s)
    http-request track-sc0 var(txn.api_key)
    
    # ACL for premium vs free tier
    acl is_premium_key var(txn.api_key) -m str -f /etc/haproxy/premium_keys.lst
    
    # Premium tier: 1000 requests/minute
    http-request deny deny_status 429 if is_premium_key { sc_http_req_rate(0) gt 1000 }
    
    # Free tier: 100 requests/minute
    http-request deny deny_status 429 if !is_premium_key { sc_http_req_rate(0) gt 100 }
    
    default_backend api_backend
```

**Nginx Config** (requires additional module):
```
http {
    # Map API keys to rate limit zones
    map $http_x_api_key $limit_key {
        default $http_x_api_key;
        "premium_key_123" "premium_$http_x_api_key";
        "premium_key_456" "premium_$http_x_api_key";
    }
    
    # Different zones for different tiers
    limit_req_zone $limit_key zone=api_free:10m rate=100r/m;
    limit_req_zone $limit_key zone=api_premium:10m rate=1000r/m;
    
    server {
        location /api/ {
            # Use premium zone if key matches
            limit_req zone=api_premium burst=50;
            limit_req zone=api_free burst=10;
            
            proxy_pass http://api_backend;
        }
    }
}
```

**Why this works**:
- Each API key gets its own rate limit
- Premium users get higher limits
- Easy to identify and block abusive keys
- Legitimate integrations continue working

### Scenario 3: Protecting Against DDoS (Global + Per-IP)
**Problem**: You're under a distributed attack. Thousands of IPs hitting your site.

**Solution**: Multi-layer rate limiting

**HAProxy Config**:
```
frontend web_front
    bind *:443 ssl crt /etc/ssl/cert.pem
    
    # Layer 1: Global rate limit (circuit breaker)
    # Protect against overwhelming the backend
    stick-table type integer size 1 expire 10s store http_req_rate(10s)
    http-request track-sc1 int(1)
    
    # If global rate exceeds 10,000 req/10s, start rejecting
    http-request deny deny_status 503 if { sc_http_req_rate(1) gt 10000 }
    
    # Layer 2: Per-IP rate limiting
    stick-table type ip size 100k expire 30s store http_req_rate(10s),conn_cur
    http-request track-sc0 src
    
    # Aggressive per-IP limits during attack
    # Normal: 100 req/10s
    # Under attack: 20 req/10s
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
    
    # Layer 3: Connection limiting per IP
    http-request deny deny_status 429 if { sc_conn_cur(0) gt 10 }
    
    # Layer 4: Detect and block scanners
    acl is_scanning path_reg -i \.(php|asp|aspx|jsp)$ !-f /var/www/html
    http-request deny deny_status 403 if is_scanning
    
    default_backend web_backend
```

**Progressive Rate Limiting** (smarter approach):
```
# Start gentle, get aggressive if needed
acl light_attack sc_http_req_rate(0) gt 100
acl heavy_attack sc_http_req_rate(0) gt 200
acl extreme_attack sc_http_req_rate(0) gt 500

# Progressive delays
http-request tarpit deny_status 429 if extreme_attack
http-request deny deny_status 429 if heavy_attack
http-request set-var(txn.delay) int(1000) if light_attack
```

**Why this works**:
- Multiple layers catch different attack patterns
- Global limit prevents backend overload
- Per-IP catches individual attackers
- Connection limiting prevents connection exhaustion
- Scanner detection blocks common attack tools

**CCDC Strategy**: 
1. Start with loose limits
2. Monitor attack patterns
3. Tighten limits as needed
4. Whitelist scoring engine and team IPs

### Scenario 4: Protecting WordPress/CMS Admin
**Problem**: WordPress admin panel (`/wp-admin/`) is being brute forced. XML-RPC is being abused for amplification.

**Solution**: Specialized rate limits for CMS weak points

**Nginx Config**:
```
http {
    # Very strict limit for XML-RPC (often abused)
    limit_req_zone $binary_remote_addr zone=xmlrpc:10m rate=1r/m;
    
    # Strict for wp-login
    limit_req_zone $binary_remote_addr zone=wplogin:10m rate=5r/m;
    
    # Moderate for wp-admin
    limit_req_zone $binary_remote_addr zone=wpadmin:10m rate=30r/m;
    
    server {
        # Block or heavily limit XML-RPC
        location = /xmlrpc.php {
            limit_req zone=xmlrpc burst=1 nodelay;
            
            # Or just block it entirely if not needed
            # deny all;
            
            proxy_pass http://wordpress;
        }
        
        # Protect login
        location = /wp-login.php {
            limit_req zone=wplogin burst=3 nodelay;
            proxy_pass http://wordpress;
        }
        
        # Protect admin area
        location ~ ^/wp-admin/ {
            limit_req zone=wpadmin burst=10;
            proxy_pass http://wordpress;
        }
        
        # Normal rate for everything else
        location / {
            proxy_pass http://wordpress;
        }
    }
}
```

**HAProxy Config**:
```
frontend wordpress_front
    bind *:443 ssl crt /etc/ssl/cert.pem
    
    stick-table type ip size 100k expire 60s store http_req_rate(60s)
    http-request track-sc0 src
    
    # Identify problem endpoints
    acl is_xmlrpc path /xmlrpc.php
    acl is_wplogin path /wp-login.php
    acl is_wpadmin path_beg /wp-admin
    
    # XML-RPC: 1 request per minute (or block entirely)
    http-request deny deny_status 429 if is_xmlrpc { sc_http_req_rate(0) gt 1 }
    # Or completely block: http-request deny if is_xmlrpc
    
    # wp-login: 5 requests per minute
    http-request deny deny_status 429 if is_wplogin { sc_http_req_rate(0) gt 5 }
    
    # wp-admin: 30 requests per minute
    http-request deny deny_status 429 if is_wpadmin { sc_http_req_rate(0) gt 30 }
    
    default_backend wordpress_backend
```

**CCDC Pro Tips**:
- XML-RPC is almost never needed in CCDC. Just block it.
- Consider IP whitelisting for `/wp-admin/` if possible
- Monitor logs for `POST /wp-login.php` failures
- Change admin URL if WordPress supports it (security through obscurity helps)

### Scenario 5: Differentiated Rate Limits for Scoring Engine
**Problem**: You need to rate limit attackers but the scoring engine needs to work. How do you allow scoring while blocking abuse?

**Solution**: Whitelist scoring engine, aggressive limits for everyone else

**HAProxy Config**:
```
frontend web_front
    bind *:443 ssl crt /etc/ssl/cert.pem
    
    # Identify scoring engine
    acl is_scoring_ip src 10.0.99.10/32
    acl is_scoring_ua hdr_sub(User-Agent) -i "scoring" "checker" "monitor"
    acl is_scoring is_scoring_ip or is_scoring_ua
    
    # Track non-scoring traffic
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src unless is_scoring
    
    # Rate limit only non-scoring traffic
    # Scoring engine gets unlimited access
    http-request deny deny_status 429 if !is_scoring { sc_http_req_rate(0) gt 50 }
    
    # Log scoring engine requests separately
    http-request set-header X-Scoring-Engine true if is_scoring
    
    default_backend web_backend
```

**Alternative**: Use separate backends with different rate limits
```
frontend web_front
    bind *:443 ssl crt /etc/ssl/cert.pem
    
    acl is_scoring src 10.0.99.10
    
    use_backend scoring_backend if is_scoring
    default_backend public_backend

# No rate limiting for scoring
backend scoring_backend
    server web1 10.0.1.10:80 check

# Aggressive rate limiting for public
backend public_backend
    stick-table type ip size 100k expire 10s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 20 }
    
    server web1 10.0.1.10:80 check
```

**Critical CCDC Consideration**: 
- **Always test with the scoring engine** before competition
- Check scoring engine IP and User-Agent
- Monitor scoring attempts in logs
- Have a "kill switch" to disable rate limiting if it breaks scoring

### Scenario 6: Adaptive Rate Limiting Based on Response Codes
**Problem**: You want to be more aggressive with rate limiting against clients that are getting errors (likely attackers scanning).

**Solution**: Track error rates and adjust limits

**HAProxy Config**:
```
backend web_backend
    # Track both requests and errors per IP
    stick-table type ip size 100k expire 30s store http_req_rate(10s),http_err_rate(10s)
    
    # Track on response
    http-response track-sc0 src
    
    # If client has high error rate, they're likely attacking
    acl high_error_rate sc_http_err_rate(0) gt 10
    
    # Clients with high error rates get much stricter limits
    http-request deny deny_status 429 if high_error_rate { sc_http_req_rate(0) gt 10 }
    
    # Normal clients get normal limits
    http-request deny deny_status 429 if !high_error_rate { sc_http_req_rate(0) gt 100 }
    
    server web1 10.0.1.10:80 check
```

**Why this works**: 
- Attackers scanning for vulnerabilities generate lots of 404s
- Brute force attempts generate lots of 401s
- Legitimate users rarely generate many errors
- Adaptive limiting focuses defensive resources on likely attackers

## Rate Limiting Response Strategies

### Return 429 Too Many Requests
Standard HTTP status code for rate limiting.

**Good practice**:
```
HTTP/1.1 429 Too Many Requests
Retry-After: 60
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1640000000

{"error": "Rate limit exceeded", "retry_after": 60}
```

**CCDC Use**: This is the standard approach. Clear communication to clients.

### Tarpit (Slow Response)
Instead of denying, respond extremely slowly to waste attacker's resources.

**HAProxy**:
```
http-request tarpit deny_status 429 if { sc_http_req_rate(0) gt 100 }
```

**Pros**: Wastes attacker's time and resources
**Cons**: Also wastes your server resources

**CCDC Use**: Effective psychological warfare but be careful not to exhaust your own resources.

### Silent Drop
Just drop the connection without responding.

**Pros**: Gives no feedback to attackers
**Cons**: Makes debugging harder, confusing for legitimate users

**CCDC Use**: For extreme cases only. Makes troubleshooting difficult.

### Challenge (CAPTCHA)
Return a CAPTCHA challenge instead of blocking.

**Pros**: Allows legitimate users to prove they're human
**Cons**: Complex to implement, not all frameworks support it

**CCDC Use**: Probably too complex for competition day unless already implemented.

### Gradual Degradation
Instead of hard blocking, add delays:
- First violation: 100ms delay
- Second: 500ms delay  
- Third: 2s delay
- Fourth+: Block

**CCDC Use**: More user-friendly but also more complex. Stick to hard limits for simplicity.

## Rate Limiting Best Practices

### 1. Multiple Layers
Don't rely on just one rate limit. Use multiple layers:
- Network layer (iptables connection limiting)
- Load balancer layer (HAProxy/Nginx)
- Application layer (app-specific rate limiting)
- WAF layer (if using CloudFlare, etc.)

### 2. Different Limits for Different Endpoints
```
/static/*       → 1000 req/min (cheap)
/api/search     → 30 req/min (expensive)
/login          → 5 req/min (security critical)
/admin/*        → 10 req/min (restricted)
/health         → unlimited (monitoring)
```

### 3. Whitelist Essentials
Always whitelist:
- Scoring engine IP
- Your team's IPs
- Monitoring systems
- Essential integrations

```
acl is_whitelisted src -f /etc/haproxy/whitelist.txt
http-request allow if is_whitelisted
```

### 4. Informative Error Messages
Help legitimate users understand why they're blocked:
```
{
  "error": "rate_limit_exceeded",
  "message": "Too many requests. Please wait 60 seconds.",
  "limit": 100,
  "period": "60s",
  "retry_after": 60
}
```

### 5. Logging and Monitoring
Log rate limit hits to detect patterns:
```
# HAProxy
http-request capture src len 15 if { sc_http_req_rate(0) gt 100 }
log-format "%ci:%cp [%t] %ft %b/%s %Tq/%Tw/%Tc/%Tr/%Tt %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r"
```

**Monitor these metrics**:
- Number of rate-limited requests per minute
- Top IPs being rate limited
- Endpoints being hit most
- Time of day patterns

### 6. Start Loose, Tighten as Needed
**Pre-competition**: Loose limits to avoid blocking legitimate traffic
**During attack**: Progressively tighten limits
**Post-attack**: Loosen again once attack subsides

**Example progression**:
```
# Normal operations
100 requests/minute

# Light attack detected
50 requests/minute

# Heavy attack
20 requests/minute

# Extreme attack (survival mode)
5 requests/minute
```

### 7. Test With Scoring Engine
**Before competition**:
```bash
# Simulate scoring engine traffic
for i in {1..100}; do
    curl -H "User-Agent: scoring-engine" https://your-site.com/
    sleep 0.1
done
```

Verify that:
- Scoring requests are not rate limited
- Scoring engine can complete checks
- Logs show scoring attempts clearly

## Application-Level Rate Limiting

Sometimes load balancer rate limiting isn't enough. Application-level rate limiting gives you more context.

### Redis-based Rate Limiting (Python/Flask example)
```python
import redis
from flask import Flask, request, jsonify
from functools import wraps

app = Flask(__name__)
r = redis.Redis(host='localhost', port=6379, db=0)

def rate_limit(max_requests=100, window=60):
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            # Get client identifier
            client_ip = request.remote_addr
            key = f"rate_limit:{f.__name__}:{client_ip}"
            
            # Increment counter
            current = r.incr(key)
            
            # Set expiry on first request
            if current == 1:
                r.expire(key, window)
            
            # Check limit
            if current > max_requests:
                return jsonify({
                    "error": "rate_limit_exceeded",
                    "retry_after": r.ttl(key)
                }), 429
            
            return f(*args, **kwargs)
        return wrapped
    return decorator

@app.route('/api/expensive-operation')
@rate_limit(max_requests=10, window=60)
def expensive_operation():
    # Do expensive work
    return jsonify({"result": "success"})

@app.route('/api/cheap-operation')
@rate_limit(max_requests=1000, window=60)
def cheap_operation():
    return jsonify({"result": "success"})
```

**Advantages**:
- Per-user rate limiting (based on session/auth)
- Different limits per endpoint easily
- Can use more complex logic
- Access to application context

**CCDC Reality**: If your app doesn't already have this, don't implement it during competition. Use load balancer rate limiting instead.

## Monitoring Rate Limiting Effectiveness

### HAProxy Stats Page Monitoring
Access HAProxy stats (`:8404/stats`) and watch:
- **Denied requests**: Spike indicates attack or misconfiguration
- **Queue depth**: If rate limiting is too strict, requests queue up
- **Response time**: Should stay low despite attacks

### Log Analysis
```bash
# Count rate-limited requests per minute
tail -f /var/log/haproxy/haproxy.log | grep "429" | wc -l

# Top IPs being rate limited
grep "429" /var/log/haproxy/haproxy.log | awk '{print $6}' | sort | uniq -c | sort -rn | head -20

# Rate limit hits over time
grep "429" /var/log/haproxy/haproxy.log | awk '{print $2}' | cut -d: -f1-2 | uniq -c
```

### Custom Monitoring Script
```bash
#!/bin/bash
# monitor_rate_limits.sh

LOGFILE="/var/log/haproxy/haproxy.log"
ALERT_THRESHOLD=100  # Alert if more than 100 rate limits/minute

while true; do
    # Count 429s in last minute
    COUNT=$(grep "429" $LOGFILE | tail -1000 | grep "$(date +'%d/%b/%Y:%H:%M')" | wc -l)
    
    if [ $COUNT -gt $ALERT_THRESHOLD ]; then
        echo "ALERT: $COUNT rate limit hits in last minute"
        # Could send notification, email, etc.
        
        # Show top offending IPs
        grep "429" $LOGFILE | tail -1000 | awk '{print $6}' | sort | uniq -c | sort -rn | head -5
    fi
    
    sleep 60
done
```

## Quick CCDC Rate Limiting Setup Guide

**15-Minute Emergency Rate Limiting Setup**:

1. **Identify Critical Endpoints** (2 minutes)
   - Login pages: `/login`, `/admin/login`, `/wp-login.php`
   - API endpoints: `/api/*`
   - Admin panels: `/admin/*`, `/wp-admin/*`

2. **Implement Basic HAProxy Rate Limiting** (5 minutes)
```
frontend web_front
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    
    acl is_login path_beg /login /admin/login
    http-request deny deny_status 429 if is_login { sc_http_req_rate(0) gt 5 }
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
```

3. **Whitelist Scoring Engine** (3 minutes)
```
acl is_scoring src 10.0.99.10
http-request allow if is_scoring
```

4. **Test** (3 minutes)
```bash
# Test rate limiting works
for i in {1..150}; do curl https://your-site.com/; done | grep -c "429"

# Test scoring engine is whitelisted
curl -H "Host: your-site.com" http://10.0.99.10/
```

5. **Monitor** (2 minutes)
```bash
watch -n 1 'echo "show table" | socat stdio /var/run/ha
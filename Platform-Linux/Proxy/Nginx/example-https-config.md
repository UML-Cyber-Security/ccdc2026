# Reverse Proxy Setup with Nginx: HTTP → HTTPS

How to sit Nginx in front of your services (Wordpress, Grafana, Nexterm, etc.) so that:
- Port **80** (HTTP) redirects to HTTPS automatically
- Port **443** (HTTPS) proxies traffic to your service running on its local port

---

## How It Works

```
Browser → :80  → redirect to :443
Browser → :443 → reverse proxy → your service (e.g. localhost:3000)
```

Your service keeps running on its original port. Nginx sits in front and handles all the SSL and redirects.

---

## Prerequisites

- A domain name or server IP
- An SSL certificate (see bottom for self-signed)
- Your service already running on its local port

---

## Install Nginx

```bash
sudo apt install nginx        # Ubuntu/Debian
sudo dnf install nginx        # RHEL/Rocky
```

---

## Config File

Create a new config file for your service:

```bash
sudo nano /etc/nginx/sites-available/myservice
```

Paste the following, replacing the values marked with `< >`:

```nginx
# Redirect HTTP → HTTPS
server {
    listen 80;
    server_name <your-domain-or-ip>;

    return 301 https://$host$request_uri;
}

# HTTPS → proxy to your service
server {
    listen 443 ssl;
    server_name <your-domain-or-ip>;

    ssl_certificate     /etc/ssl/certs/<your-cert>.crt;
    ssl_certificate_key /etc/ssl/private/<your-key>.key;

    location / {
        proxy_pass http://localhost:<service-port>;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## Enable & Reload

```bash
sudo ln -s /etc/nginx/sites-available/myservice /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Common Service Ports

| Service    | Default Port |
|------------|-------------|
| Grafana    | 3000        |
| Nexterm    | 6989        |
| Wordpress  | 8080        |
| Gitea      | 3000        |
| Semaphore  | 3000        |

---

## Generating a Self-Signed Certificate (Testing Only)

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/myservice.key \
  -out /etc/ssl/certs/myservice.crt
```

> ⚠️ Self-signed certs will show a browser warning. Use [Let's Encrypt](https://certbot.eff.org/) for a trusted cert in production.

---

## Firewall

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 80
sudo ufw allow 443

# RHEL/Rocky (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```
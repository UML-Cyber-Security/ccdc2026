# Reverse Proxy Setup with Apache2: HTTP → HTTPS

How to sit Apache2 in front of your services (Wordpress, Grafana, Nexterm, etc.) so that:
- Port **80** (HTTP) redirects to HTTPS automatically
- Port **443** (HTTPS) proxies traffic to your service running on its local port

---

## How It Works

```
Browser → :80  → redirect to :443
Browser → :443 → reverse proxy → your service (e.g. localhost:3000)
```

Your service keeps running on its original port. Apache2 sits in front and handles all the SSL and redirects.

---

## Prerequisites

- A domain name or server IP
- An SSL certificate (see bottom for self-signed)
- Your service already running on its local port

---

## Install Apache2

```bash
sudo apt install apache2        # Ubuntu/Debian
sudo dnf install httpd          # RHEL/Rocky
```

---

## Enable Required Modules

```bash
sudo a2enmod proxy proxy_http rewrite ssl headers
sudo systemctl restart apache2
```

---

## Config File

```bash
sudo nano /etc/apache2/sites-available/myservice.conf
```

Paste the following, replacing the values marked with `< >`:

```apache
# Redirect HTTP → HTTPS
<VirtualHost *:80>
    ServerName <your-domain-or-ip>

    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>

# HTTPS → proxy to your service
<VirtualHost *:443>
    ServerName <your-domain-or-ip>

    SSLEngine On
    SSLCertificateFile    /etc/ssl/certs/<your-cert>.crt
    SSLCertificateKeyFile /etc/ssl/private/<your-key>.key

    ProxyPreserveHost On
    ProxyPass        / http://localhost:<service-port>/
    ProxyPassReverse / http://localhost:<service-port>/

    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
</VirtualHost>
```

---

## Enable & Reload

```bash
sudo a2ensite myservice.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
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
# Nexterm Manual Installation

Quick setup guide for deploying Nexterm via Docker on RHEL-based systems (Rocky Linux, AlmaLinux, CentOS Stream).

---

## Prerequisites

- RHEL-based system (Rocky Linux, AlmaLinux, CentOS Stream)
- `sudo` access

---

## Step 1 — Update & Install Docker

```bash
sudo dnf update -y
sudo dnf install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker
```

---

## Step 2 — Create Working Directory

```bash
mkdir nexterm
cd nexterm
```

---

## Step 3 — Deploy Nexterm Container

```bash
sudo docker run -d \
  -e ENCRYPTION_KEY=887c041510fcd80e7ba2cd02165f662197a28a41fff4c98e182181e363a89f76 \
  --network host \
  --name nexterm \
  --restart always \
  -v nexterm:/app/data \
  nexterm/aio:development
```

### What each flag does

| Flag | Purpose |
|------|---------|
| `-d` | Run container in background |
| `-e ENCRYPTION_KEY` | Key used to encrypt stored passwords and SSH keys |
| `--network host` | Use host networking so Nexterm can reach your other machines |
| `--name nexterm` | Name the container for easy management |
| `--restart always` | Auto-restart on reboot or crash |
| `-v nexterm:/app/data` | Persist Nexterm data across container restarts |

---

## Step 4 — Allow Port Through Firewall

RHEL-based systems use `firewalld` by default. Open port 6989:

```bash
sudo firewall-cmd --permanent --add-port=6989/tcp
sudo firewall-cmd --reload
```

---

## Step 5 — Access Nexterm

Once the container is running, open your browser and navigate to:

```
http://<your-server-ip>:6989
```

On first visit you will be prompted to create an admin account.

---
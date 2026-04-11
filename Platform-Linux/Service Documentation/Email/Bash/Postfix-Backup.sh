#!/usr/bin/env bash

set -euo pipefail

### =========================
### CONFIG (EDIT THESE)

REMOTE_USER="youruser"
REMOTE_HOST="your.mail.server.ip"
SSH_PORT=22

LOCAL_BACKUP_DIR="$HOME/service-backups/postfix-backup"

### =========================
### FLAGS
INCLUDE_SECRETS=0
INCLUDE_QUEUE=1

while getopts "kq" opt; do
  case $opt in
    k) INCLUDE_SECRETS=1 ;;
    q) INCLUDE_QUEUE=1 ;;
    *) echo "Usage: $0 [-k (certs/keys)] [-q (mail queue snapshot)]"
       exit 1 ;;
  esac

done

### =========================
### SETUP DEST DIR
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DEST="$LOCAL_BACKUP_DIR/$TIMESTAMP"

mkdir -p "$DEST"

echo "[+] Creating backup directory: $DEST"

### =========================
### 1. POSTFIX CONFIG BACKUP
echo "[+] Pulling Postfix configuration..."

rsync -avz -e "ssh -p $SSH_PORT" \
  "$REMOTE_USER@$REMOTE_HOST:/etc/postfix/" \
  "$DEST/postfix/"

### =========================
### 2. RUNTIME CONFIG SNAPSHOT
echo "[+] Capturing Postfix runtime configuration..."

ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
  "postconf -n" > "$DEST/postfix_runtime_config.txt" 2>/dev/null || true

### =========================
### 3. MAIL QUEUE SNAPSHOT (optional)
if [[ "$INCLUDE_QUEUE" -eq 1 ]]; then
  echo "[+] Capturing mail queue state..."

  ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
    "mailq || true; postqueue -p || true" \
    > "$DEST/mail_queue.txt"
else
  echo "[*] Skipping mail queue snapshot"
fi

### =========================
### 4. OPTIONAL: TLS CERTS + KEYS
if [[ "$INCLUDE_SECRETS" -eq 1 ]]; then
  echo "[!] INCLUDING CERTIFICATES + PRIVATE KEYS"

  rsync -avz -e "ssh -p $SSH_PORT" \
    "$REMOTE_USER@$REMOTE_HOST:/etc/ssl/" \
    "$DEST/ssl/" 2>/dev/null || true

  rsync -avz -e "ssh -p $SSH_PORT" \
    "$REMOTE_USER@$REMOTE_HOST:/etc/letsencrypt/" \
    "$DEST/letsencrypt/" 2>/dev/null || true
else
  echo "[*] Skipping certificates/private keys (use -k to include)"
fi

echo "[✓] Postfix backup complete!"
echo "[✓] Saved to: $DEST"
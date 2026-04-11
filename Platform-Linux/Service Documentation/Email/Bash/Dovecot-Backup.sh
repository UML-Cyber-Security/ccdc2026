#!/usr/bin/env bash

set -euo pipefail

### =========================
### CONFIG (EDIT THESE)
### =========================
REMOTE_USER="youruser"
REMOTE_HOST="your.mail.server.ip"
SSH_PORT=22

LOCAL_BACKUP_DIR="$HOME/service-backups/dovecot-backup"

### =========================
### FLAGS
### =========================
INCLUDE_SECRETS=0

while getopts "k" opt; do
  case $opt in
    k) INCLUDE_SECRETS=1 ;;
    *) echo "Usage: $0 [-k (include keys/certs)]"
       exit 1 ;;
  esac
done

### =========================
### TIMESTAMPED DIR
### =========================
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DEST="$LOCAL_BACKUP_DIR/$TIMESTAMP"

mkdir -p "$DEST"

echo "[+] Creating backup directory: $DEST"

### =========================
### 1. BACKUP DOVECOT CONFIG
### =========================
echo "[+] Pulling Dovecot configuration..."

rsync -avz -e "ssh -p $SSH_PORT" \
  "$REMOTE_USER@$REMOTE_HOST:/etc/dovecot/" \
  "$DEST/dovecot/"

### =========================
### 2. OPTIONAL: TLS CERTS + KEYS
### =========================
if [[ "$INCLUDE_SECRETS" -eq 1 ]]; then
  echo "[!] INCLUDING CERTIFICATES + PRIVATE KEYS"

  rsync -avz -e "ssh -p $SSH_PORT" \
    "$REMOTE_USER@$REMOTE_HOST:/etc/ssl/" \
    "$DEST/ssl/"

  rsync -avz -e "ssh -p $SSH_PORT" \
    "$REMOTE_USER@$REMOTE_HOST:/etc/letsencrypt/" \
    "$DEST/letsencrypt/" 2>/dev/null || true
else
  echo "[*] Skipping certificates/private keys (use -k to include)"
fi

### =========================
### 3. METADATA SNAPSHOT
### =========================
echo "[+] Saving config summary..."

ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
  "dovecot -n" > "$DEST/dovecot_runtime_config.txt" 2>/dev/null || true

### =========================
### DONE
### =========================
echo "[✓] Backup complete!"
echo "[✓] Saved to: $DEST"
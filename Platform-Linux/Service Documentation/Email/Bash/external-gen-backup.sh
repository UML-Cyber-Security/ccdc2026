#!/usr/bin/env bash
set -euo pipefail

### GLOBAL CONFIG
REMOTE_USER="youruser"
REMOTE_HOST="your.server.ip"
SSH_PORT=22

BASE_BACKUP_DIR="$HOME/service-backups"

### SERVICE CONFIG
SERVICE_NAME="dovecot"

REMOTE_PATHS=(
  "/etc/dovecot"
)

### MACHINE NAME (SAFE FALLBACK)
HOSTNAME_REMOTE=$(ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "hostname" 2>/dev/null || echo "$REMOTE_HOST")

### sanitize hostname for filesystem safety
HOST_DIR=$(echo "$HOSTNAME_REMOTE" | tr '/ ' '__')

### OUTPUT SETUP
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

DEST="$BASE_BACKUP_DIR/$HOST_DIR/$SERVICE_NAME/$TIMESTAMP"
LATEST_LINK="$BASE_BACKUP_DIR/$HOST_DIR/$SERVICE_NAME/latest"

mkdir -p "$DEST"

echo "[+] Host      : $HOST_DIR"
echo "[+] Service   : $SERVICE_NAME"
echo "[+] Target    : $DEST"

### BACKUP FILES (NO SUDO)
for REMOTE_PATH in "${REMOTE_PATHS[@]}"; do

  echo "[+] Pulling: $REMOTE_PATH"

  BASENAME=$(basename "$REMOTE_PATH")
  OUT_DIR="$DEST/$BASENAME"

  mkdir -p "$OUT_DIR"

  rsync -avz -e "ssh -p $SSH_PORT" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" \
    "$OUT_DIR/" || {
      echo "[!] Warning: failed to pull $REMOTE_PATH"
    }

done

### RUNTIME SNAPSHOT
echo "[+] Capturing runtime config..."

ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
  "command -v $SERVICE_NAME >/dev/null 2>&1 && $SERVICE_NAME -n 2>/dev/null || true" \
  > "$DEST/${SERVICE_NAME}_runtime.txt" || true

### UPDATE LATEST POINTER
rm -f "$LATEST_LINK"
ln -s "$TIMESTAMP" "$LATEST_LINK"

echo "[✓] Backup complete"
echo "[✓] Host stored under: $HOST_DIR"
echo "[✓] Latest -> $LATEST_LINK"
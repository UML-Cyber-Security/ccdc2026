#!/usr/bin/env bash
set -euo pipefail

### =========================
### CONFIG
### =========================
LOCAL_HOSTNAME=$(hostname)
BACKUP_BASE="$HOME/service-backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DEST="$BACKUP_BASE/$TIMESTAMP"

mkdir -p "$DEST"

echo "[+] Backup destination: $DEST"

### =========================
### SERVICE DEFINITIONS (EDIT HERE)
### Format:
###   ["service_name"]="/path/to/config"
### =========================
declare -A SERVICES=(
  ["nginx"]="/etc/nginx"
  ["apache2"]="/etc/apache2"
)

### =========================
### DETECT + BACKUP (GENERIC)
### =========================
FOUND=0

for SERVICE in "${!SERVICES[@]}"; do
  CONFIG_PATH="${SERVICES[$SERVICE]}"

  # only act if path exists
  if [ -e "$CONFIG_PATH" ]; then

    echo "[+] Backing up $SERVICE from $CONFIG_PATH"

    OUT_DIR="$DEST/$SERVICE"
    mkdir -p "$OUT_DIR"

    cp -a "$CONFIG_PATH" "$OUT_DIR/" 2>/dev/null || {
      echo "[!] Warning: partial copy of $SERVICE (permission limited)"
    }

    FOUND=1
  fi
done

### =========================
### RESULT SUMMARY
### =========================
echo "======================================"
echo ""
echo "SUMMARY"
echo ""
echo "======================================"
echo "[+] Hostname        : $LOCAL_HOSTNAME"
echo "[+] Backup location : $DEST"

if [ "$FOUND" -eq 0 ]; then
  echo "[!] No matching service paths found."
else
  echo "[✓] Backup complete."
fi
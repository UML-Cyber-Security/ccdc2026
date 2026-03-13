#!/bin/bash

# TELEPORT BACKUP SCRIPT (Bare Metal)
# Backs up Teleport resources and optionally user secrets

set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

read -r -p "Include user secrets in backup? (y/N): " USER_INPUT
USER_INPUT=${USER_INPUT:-N}

if [[ "$USER_INPUT" =~ ^[Yy]$ ]]; then
    EXPORT_SECRETS="yes"
else
    EXPORT_SECRETS="no"
fi

# Variable sets (same as container version)
BACKUP_DIR="/opt/teleport-backups/$(date +%F_%H-%M-%S)"
TCTL="/usr/local/bin/tctl"
TELEPORT_CONFIG="/etc/teleport/teleport.yaml"
TELEPORT_DATA="/var/lib/teleport"

mkdir -p "$BACKUP_DIR"

# Basic validation
if [[ ! -x "$TCTL" ]]; then
    echo "Error: tctl not found or not executable at $TCTL"
    exit 1
fi

if [[ ! -f "$TELEPORT_CONFIG" ]]; then
    echo "Error: Teleport config not found at $TELEPORT_CONFIG"
    exit 1
fi

if [[ ! -d "$TELEPORT_DATA" ]]; then
    echo "Error: Teleport data directory not found at $TELEPORT_DATA"
    exit 1
fi

echo "[*] Backup directory: $BACKUP_DIR"
echo "[*] Export secrets: $EXPORT_SECRETS"

# User exporting
echo "[*] Exporting users..."
"$TCTL" get users > "$BACKUP_DIR/users.yaml"

if [[ "$EXPORT_SECRETS" == "yes" ]]; then
    echo "  [!] Exporting users WITH secrets (sensitive data)"
    "$TCTL" get users --with-secrets > "$BACKUP_DIR/users_with_secrets.yaml"
    chmod 600 "$BACKUP_DIR/users_with_secrets.yaml"
fi

# Rest of tctl exports
echo "[*] Exporting roles and nodes"
"$TCTL" get roles > "$BACKUP_DIR/roles.yaml"

# Export the teleport.yaml config
echo "[*] Exporting teleport.yaml..."
cp "$TELEPORT_CONFIG" "$BACKUP_DIR/"

# Export cluster state/data
echo "[*] Exporting Teleport data directory..."
cp -a "$TELEPORT_DATA" "$BACKUP_DIR/data"
tar -czf "$BACKUP_DIR/teleport-data.tar.gz" -C "$BACKUP_DIR" data
rm -rf "$BACKUP_DIR/data"

echo "[*] Backup complete."
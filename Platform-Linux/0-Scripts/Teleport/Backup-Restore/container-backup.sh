#!/bin/bash

# TELEPORT BACKUP SCRIPT (Podman / distroless compatible)
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

# Variable sets
BACKUP_DIR="/opt/teleport-backups/$(date +%F_%H-%M-%S)"
CONTAINER="teleport"
TCTL="/usr/local/bin/tctl"

mkdir -p "$BACKUP_DIR"

if ! podman container exists "$CONTAINER"; then
    echo "Error: Podman container '$CONTAINER' not found."
    exit 1
fi  

echo "[*] Backup directory: $BACKUP_DIR"
echo "[*] Export secrets: $EXPORT_SECRETS"

# User exporting
echo "[*] Exporting users..."
podman exec "$CONTAINER" "$TCTL" get users > "$BACKUP_DIR/users.yaml"

if [[ "$EXPORT_SECRETS" == "yes" ]]; then
    echo "[!] Exporting users WITH secrets (sensitive data)"
    podman exec "$CONTAINER" "$TCTL" get users --with-secrets > "$BACKUP_DIR/users_with_secrets.yaml"
    chmod 600 "$BACKUP_DIR/users_with_secrets.yaml"
fi

# Rest of tctl exports
echo "[*] Exporting roles and nodes"
podman exec "$CONTAINER" "$TCTL" get roles > "$BACKUP_DIR/roles.yaml"

# Export the teleport.yaml config
echo "[*] Exporting teleport.yaml..."
podman cp "$CONTAINER":/etc/teleport/teleport.yaml "$BACKUP_DIR/"

# Export cluster state/data
echo "[*] Exporting Teleport data directory..."
podman cp "$CONTAINER":/var/lib/teleport "$BACKUP_DIR/data"
tar -czf "$BACKUP_DIR/teleport-data.tar.gz" -C "$BACKUP_DIR" data
rm -rf "$BACKUP_DIR/data"

echo "[*] Backup complete."
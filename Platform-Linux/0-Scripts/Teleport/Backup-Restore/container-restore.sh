#!/bin/bash

# TELEPORT RESTORE SCRIPT (Interactive)
# Restores selected Teleport resources via Podman
# Run this script from inside the backup directory

set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Variable sets
CONTAINER="teleport"
TCTL="/usr/local/bin/tctl"
BACKUP_DIR="$(pwd)"

echo "[*] Using backup directory: $BACKUP_DIR"

# Container Verify
if ! podman container exists "$CONTAINER"; then
    echo "Error: Podman container '$CONTAINER' not found."
    exit 1
fi

# Mr.G prompt helper
ask_restore() {
    local name="$1"
    read -r -p "Restore $name? (y/N): " choice
    choice=${choice:-N}

    if [[ "$choice" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Mr.G restore helper
restore_resource() {
    local file="$1"
    local name="$2"

    if [[ ! -f "$BACKUP_DIR/$file" ]]; then
        echo "[*] $file not found, skipping."
        return
    fi

    if ask_restore "$name"; then
        echo "[*] Restoring $name from $file"
        podman cp "$BACKUP_DIR/$file" "$CONTAINER:/tmp/$file"
        podman exec "$CONTAINER" "$TCTL" create -f "/tmp/$file"
    else
        echo "[*] Skipping $name"
    fi
}

# Main restore runner
echo ""
echo "Select resources to restore (default = No):"
echo ""

restore_resource "roles.yaml" "roles"
restore_resource "users.yaml" "users"
restore_resource "users_with_secrets.yaml" "users WITH secrets"

echo ""
echo "[*] Restore process complete."
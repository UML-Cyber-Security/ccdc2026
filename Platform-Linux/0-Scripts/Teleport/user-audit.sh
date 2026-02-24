#!/bin/bash

# Teleport User Audit / Modification Script
# Supports Bare Metal or Podman deployments
# Run as root
# No confirmation prompts — actions execute immediately

set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: Run this script as root."
    exit 1
fi

# Run mode selection
echo "Select Teleport deployment type:"
echo "1) Bare metal"
echo "2) Podman"
read -rp "Choice (1/2): " MODE

TCTL="/usr/local/bin/tctl"
CONTAINER="teleport"

if [[ "$MODE" == "2" ]]; then
    if ! podman container exists "$CONTAINER"; then
        echo "Error: Podman container '$CONTAINER' not found."
        exit 1
    fi

    run_tctl() {
        podman exec "$CONTAINER" "$TCTL" "$@"
    }
else
    run_tctl() {
        "$TCTL" "$@"
    }
fi

# Grab users
echo ""
echo "[*] Retrieving users..."
USERS=$(run_tctl users ls | awk 'NR>1 {print $1}')

echo ""
echo "[*] Starting interactive review"
echo "[!] Actions execute immediately."
echo ""


# Loop through users
for USER in $USERS; do
    echo "----------------------------------"
    echo "User: $USER"

    # Display current roles
    echo "Current roles:"
    run_tctl get user/"$USER" | grep roles || echo "(no roles found)"

    echo ""
    echo "Action:"
    echo "1) Keep"
    echo "2) Delete user"
    echo "3) Remove all roles"
    read -rp "Choice (1/2/3): " ACTION

    case "$ACTION" in
        2)
            echo "[*] Deleting $USER"
            run_tctl rm user/"$USER"
            ;;
        3)
            echo "[*] Removing all roles from $USER"

            TMPFILE="/tmp/${USER}_noroles.yaml"
            run_tctl get user/"$USER" > "$TMPFILE"

            # Replace roles with empty list
            sed -i 's/roles: .*/roles: []/' "$TMPFILE"

            if [[ "$MODE" == "2" ]]; then
                podman cp "$TMPFILE" "$CONTAINER:/tmp/${USER}_noroles.yaml"
                podman exec "$CONTAINER" "$TCTL" create -f "/tmp/${USER}_noroles.yaml"
            else
                run_tctl create -f "$TMPFILE"
            fi

            rm -f "$TMPFILE"
            ;;
        *)
            echo "[*] Keeping $USER"
            ;;
    esac

    echo ""
done

echo "[*] User review complete."
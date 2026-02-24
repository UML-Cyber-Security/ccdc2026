#!/bin/bash

# Teleport User Audit / Modification Script
# No role preview
# Safe role removal
# Supports Bare Metal or Podman deployments

set -euo pipefail

#######################################
# Root check
#######################################
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: Run this script as root."
    exit 1
fi

#######################################
# Mode selection
#######################################
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

#######################################
# Get users (clean list)
#######################################
echo ""
echo "[*] Retrieving users..."
USERS=$(run_tctl users ls 2>/dev/null | awk 'NR>1 && $1 !~ /^-+$/ {print $1}')

echo ""
echo "[*] Starting interactive review"
echo "[!] Actions execute immediately."
echo ""

#######################################
# Loop through users
#######################################
for USER in $USERS; do
    echo "----------------------------------"
    echo "User: $USER"

    echo ""
    echo "Action:"
    echo "1) Keep"
    echo "2) Delete user"
    echo "3) Remove all roles"
    read -rp "Choice (1/2/3): " ACTION

    case "$ACTION" in
        2)
            echo "[*] Deleting $USER"
            run_tctl rm user/"$USER" || echo "[!] Failed to delete $USER"
            ;;
        3)
            echo "[*] Removing all roles from $USER"

            TMPFILE=$(mktemp /tmp/"${USER}"_noroles.XXXX.yaml)

            if ! run_tctl get user/"$USER" > "$TMPFILE" 2>/dev/null; then
                echo "[!] Failed to retrieve user $USER"
                rm -f "$TMPFILE"
                continue
            fi

            # Safely replace spec.roles block with empty list
            awk '
            BEGIN {inroles=0}
            /^[[:space:]]*roles:/ && inroles==0 {
                print "  roles: []"
                inroles=1
                next
            }
            inroles && /^[[:space:]]*-/ { next }
            { print }
            ' "$TMPFILE" > "${TMPFILE}.new"

            mv "${TMPFILE}.new" "$TMPFILE"

            if [[ "$MODE" == "2" ]]; then
                BASENAME=$(basename "$TMPFILE")
                podman cp "$TMPFILE" "$CONTAINER:/tmp/$BASENAME"
                podman exec "$CONTAINER" "$TCTL" create -f "/tmp/$BASENAME" \
                    || echo "[!] Failed to update $USER"
            else
                run_tctl create -f "$TMPFILE" || echo "[!] Failed to update $USER"
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
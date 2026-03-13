#!/bin/bash

# Teleport User Audit / Modification Script
# Supports Bare Metal or Podman deployments

# Todo: Add docker compatability

set -euo pipefail

# Run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: Run this script as root."
    exit 1
fi

# Mode selection
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

# Get all users as a clean list
echo ""
echo "[*] Retrieving users..."
USERS=$(run_tctl users ls 2>/dev/null | awk 'NR>1 && $1 !~ /^-+$/ {print $1}')

echo ""
echo "[*] Starting interactive review"
echo "[!] Actions execute immediately."
echo ""

KEPT_USERS=()
DELETED_USERS=()
ROLES_REMOVED_USERS=()
LOCKED_USERS=()

# Loop through all users one by one
for USER in $USERS; do
    echo "----------------------------------"
    echo "User: $USER"

    echo ""
    echo "Action:"
    echo "1) Keep"
    echo "2) Delete user"
    echo "3) Deprivilege (remove all roles)"
    echo "4) Lock"
    read -rp "Choice (1/2/3/4): " ACTION

    case "$ACTION" in
        2)
            echo "[*] Deleting $USER"
            run_tctl rm user/"$USER" || echo "[!] Failed to delete $USER"
            DELETED_USERS+=("$USER")
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
            ROLES_REMOVED_USERS+=("$USER")
            ;;
        4)
            echo "[*] Locking $USER"
            run_tctl lock --user="$USER" || echo "[!] Failed to lock $USER"
            LOCKED_USERS+=("$USER")
            ;;
        *)
            echo "[*] Keeping $USER"
            KEPT_USERS+=("$USER")
            ;;
    esac

    echo ""
done

echo "[*] User review complete."

# Script output summary
echo ""
echo "======================================"
echo "           AUDIT SUMMARY"
echo "======================================"

echo ""
echo "Users Kept (${#KEPT_USERS[@]}):"
if [[ ${#KEPT_USERS[@]} -eq 0 ]]; then
    echo "  None"
else
    for U in "${KEPT_USERS[@]}"; do echo "  - $U"; done
fi

echo ""
echo "Users Deleted (${#DELETED_USERS[@]}):"
if [[ ${#DELETED_USERS[@]} -eq 0 ]]; then
    echo "  None"
else
    for U in "${DELETED_USERS[@]}"; do echo "  - $U"; done
fi

echo ""
echo "Users With Roles Removed (${#ROLES_REMOVED_USERS[@]}):"
if [[ ${#ROLES_REMOVED_USERS[@]} -eq 0 ]]; then
    echo "  None"
else
    for U in "${ROLES_REMOVED_USERS[@]}"; do echo "  - $U"; done
fi

echo ""
echo "Users Locked (${#LOCKED_USERS[@]}):"
if [[ ${#LOCKED_USERS[@]} -eq 0 ]]; then
    echo "  None"
else
    for U in "${LOCKED_USERS[@]}"; do echo "  - $U"; done
fi

echo ""
echo "======================================"
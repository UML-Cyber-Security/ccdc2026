#!/bin/bash

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
# Watch loop
#######################################
echo ""
echo "[*] Monitoring active Teleport sessions every 2 minutes."
echo "[*] Press Ctrl+C to stop."
echo ""

while true; do
    echo "======================================"
    echo "  Teleport Monitor — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================"

    echo ""
    echo "--- Active Sessions (connected to a node / teleport agent) ---"
    run_tctl sessions ls

    echo ""
    echo "--- Recent Logins (web UI + tsh) ---"
    run_tctl audit log --type=user.login

    echo ""
    echo "[*] Next refresh in 2 minutes..."
    sleep 120
done
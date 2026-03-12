#!/bin/bash
#############################################################################
# This script makes is so that only Root can run the CLI for Teleport. 
#############################################################################

#######################################
# Root check
#######################################
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: Run this script as root."
    exit 1
fi

#######################################
# Lock down tctl to root/sudo only
#######################################
BINARIES=("/usr/local/bin/tctl")

for BIN in "${BINARIES[@]}"; do
    if [[ ! -f "$BIN" ]]; then
        echo "======================================"
        echo "======================================"
        echo "[!] Binary not found, skipping: $BIN"
        echo "======================================"
        echo "======================================"
        continue
    fi

    # Set owner to root, remove execute for group and others
    chown root:root "$BIN"
    chmod 700 "$BIN"

    echo "[*] Locked down: $BIN"
done

echo ""
echo "[*] Done. Only root/sudo can now execute tctl."
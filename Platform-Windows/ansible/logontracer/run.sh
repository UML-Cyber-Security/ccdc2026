#!/bin/bash
# LogonTracer Automation Script
# Called by cron every 30 minutes to extract and ingest logs
#
# Schedule: */30 * * * * (configurable in group_vars/all.yml)
# Flow: Windows AD (extract) -> Ansible Controller (fetch) -> LogonTracer (ingest)

set -e

# Get absolute path to script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/cron.log"
INVENTORY="$SCRIPT_DIR/inventory/hosts.ini"
PLAYBOOK="$SCRIPT_DIR/operations/extract_and_ingest.yml"
ROLES_PATH="$SCRIPT_DIR/roles"

# Ansible settings
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_ROLES_PATH="$ROLES_PATH"

# Log start
echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting LogonTracer automation" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Check files exist
if [ ! -f "$INVENTORY" ]; then
    echo "[ERROR] Inventory not found: $INVENTORY" >> "$LOG_FILE"
    exit 1
fi

if [ ! -f "$PLAYBOOK" ]; then
    echo "[ERROR] Playbook not found: $PLAYBOOK" >> "$LOG_FILE"
    exit 1
fi

# Run playbook
echo "[INFO] Running: ansible-playbook -i $INVENTORY $PLAYBOOK" >> "$LOG_FILE"
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

# Log completion
if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed successfully" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed with exit code: $EXIT_CODE" >> "$LOG_FILE"
fi
echo "========================================" >> "$LOG_FILE"

exit $EXIT_CODE

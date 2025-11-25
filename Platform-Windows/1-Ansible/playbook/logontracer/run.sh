#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "---- $(date) ----" >> "$SCRIPT_DIR/cron.log" 2>&1

ansible-playbook \
  -i "$SCRIPT_DIR/inventory.ini" \
  "$SCRIPT_DIR/extract.yml" \
  >> "$SCRIPT_DIR/cron.log" 2>&1

ansible-playbook \
  -i "$SCRIPT_DIR/inventory.ini" \
  "$SCRIPT_DIR/upload.yml" \
  >> "$SCRIPT_DIR/cron.log" 2>&1

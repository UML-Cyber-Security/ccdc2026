#!/bin/bash
# LogonTracer Automation Script
# This script is called by cron to extract and ingest logs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/cron.log"

echo "---- $(date) ----" >> "$LOG_FILE" 2>&1

ansible-playbook \
  -i "$SCRIPT_DIR/inventory/hosts.ini" \
  "$SCRIPT_DIR/operations/extract_and_ingest.yml" \
  >> "$LOG_FILE" 2>&1

echo "---- Completed $(date) ----" >> "$LOG_FILE" 2>&1

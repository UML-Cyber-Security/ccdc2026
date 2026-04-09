#!/usr/bin/env bash

set -euo pipefail

### =========================
### CONFIG (EDIT THESE)
### =========================
REMOTE_USER="youruser"
REMOTE_HOST="your.mail.server.ip"
SSH_PORT=22

POSTFIX_BASELINE="$HOME/postfix-backup/latest/postfix"
DOVECOT_BASELINE="$HOME/dovecot-backup/latest/dovecot"

TMP_DIR="/tmp/mail-config-remote-$$"

mkdir -p "$TMP_DIR"

echo "[+] Creating temporary workspace: $TMP_DIR"

### =========================
### 1. PULL LIVE CONFIGS VIA SSH
### =========================
echo "[+] Pulling live Postfix config from remote..."

ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
  "tar -czf - -C /etc postfix" > "$TMP_DIR/postfix_live.tar.gz"

mkdir -p "$TMP_DIR/postfix_live"
tar -xzf "$TMP_DIR/postfix_live.tar.gz" -C "$TMP_DIR/postfix_live"

echo "[+] Pulling live Dovecot config from remote..."

ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
  "tar -czf - -C /etc dovecot" > "$TMP_DIR/dovecot_live.tar.gz"

mkdir -p "$TMP_DIR/dovecot_live"
tar -xzf "$TMP_DIR/dovecot_live.tar.gz" -C "$TMP_DIR/dovecot_live"

### =========================
### 2. RUN DIFFS
### =========================
echo ""
echo "================ POSTFIX DIFF ================"

diff -ruN \
  "$POSTFIX_BASELINE" \
  "$TMP_DIR/postfix_live/postfix" || true

echo ""
echo "================ DOVECOT DIFF ================"

diff -ruN \
  "$DOVECOT_BASELINE" \
  "$TMP_DIR/dovecot_live/dovecot" || true

echo ""
echo "[✓] Diff complete"

### =========================
### 3. CLEANUP (optional)
### =========================
rm -rf "$TMP_DIR"
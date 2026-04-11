#!/usr/bin/env bash
set -euo pipefail

### =========================
### GLOBAL CONFIG
### =========================
REMOTE_USER="youruser"
REMOTE_HOST="your.server.ip"
SSH_PORT=22

BASE_BACKUP_DIR="$HOME/db-backups"

### =========================
### DB CONFIG
### =========================
# Choose one:
#   mysql | postgres | sqlite
DB_TYPE="mysql"
DB_NAME="all"   # or specific DB name

### =========================
### MACHINE NAME
### =========================
HOSTNAME_REMOTE=$(ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "hostname" 2>/dev/null || echo "$REMOTE_HOST")
HOST_DIR=$(echo "$HOSTNAME_REMOTE" | tr '/ ' '__')

### =========================
### OUTPUT SETUP
### =========================
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

DEST="$BASE_BACKUP_DIR/$HOST_DIR/$DB_TYPE/$TIMESTAMP"
LATEST_LINK="$BASE_BACKUP_DIR/$HOST_DIR/$DB_TYPE/latest"

mkdir -p "$DEST"

echo "[+] Host    : $HOST_DIR"
echo "[+] DB Type : $DB_TYPE"
echo "[+] Target  : $DEST"

### =========================
### MYSQL / MARIADB
### =========================
if [[ "$DB_TYPE" == "mysql" ]]; then

  echo "[+] Running MySQL dump..."

  ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
    "mysqldump --all-databases 2>/dev/null" \
    > "$DEST/mysql_dump.sql" || {
      echo "[!] MySQL dump failed (auth/permissions required)"
    }

fi

### =========================
### POSTGRESQL
### =========================
if [[ "$DB_TYPE" == "postgres" ]]; then

  echo "[+] Running PostgreSQL dump..."

  ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
    "pg_dumpall 2>/dev/null" \
    > "$DEST/postgres_dump.sql" || {
      echo "[!] PostgreSQL dump failed (auth/permissions required)"
    }

fi

### =========================
### SQLITE (FILE-BASED)
### =========================
if [[ "$DB_TYPE" == "sqlite" ]]; then

  echo "[+] Searching for SQLite DBs..."

  ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" \
    "find / -type f \\( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \\) 2>/dev/null | head -n 20" \
    | while read -r db; do

        echo "[+] Found: $db"

        BASENAME=$(basename "$db")

        rsync -avz -e "ssh -p $SSH_PORT" \
          "$REMOTE_USER@$REMOTE_HOST:$db" \
          "$DEST/$BASENAME" 2>/dev/null || {
            echo "[!] Failed to copy $db"
          }

      done
fi

### =========================
### UPDATE LATEST POINTER
### =========================
rm -f "$LATEST_LINK"
ln -s "$TIMESTAMP" "$LATEST_LINK"

echo "[✓] Backup complete"
echo "[✓] Latest -> $LATEST_LINK"
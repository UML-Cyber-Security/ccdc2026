#!/bin/bash
# system_quarantine.sh
# Purpose: Quarantine rogue SUID files, clean /tmp, destroy crontabs, and block known malicious IPs

set -euo pipefail

# 1. Create a secure quarantine vault
QUARANTINE_DIR="/root/quarantine_vault"
mkdir -p "$QUARANTINE_DIR"
chmod 700 "$QUARANTINE_DIR"

# 2. The Universal OS-Agnostic SUID Quarantine
echo "[*] Starting SUID quarantine..."
while IFS= read -r f; do
  owned=0

  # Check if the system uses dpkg (Debian/Ubuntu)
  if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -S "$f" &>/dev/null && owned=1

  # Check if the system uses rpm (Rocky/SLES/Fedora)
  elif command -v rpm >/dev/null 2>&1; then
    rpm -qf "$f" &>/dev/null && owned=1
  fi

  # If the file is NOT owned by the OS package manager, neutralize it
  if [ $owned -eq 0 ]; then
    echo "[QUARANTINE] Neutralizing rogue file: $f"
    chmod u-s "$f"
    mv "$f" "$QUARANTINE_DIR/"
  else
    echo "[SAFE] Keeping legitimate OS file: $f"
  fi
done < <(find / -type f -perm -4000 -mtime -3 2>/dev/null)

# 3. Clean up the /tmp/ workbench
echo "[*] Cleaning /tmp/..."
rm -f /tmp/*.c /tmp/*.sh

# 4. Destroy the crontab persistence
HOST_BACKUP="$HOME/compromised_crontab_$(hostname).txt"
crontab -l >"$HOST_BACKUP" 2>/dev/null || true
crontab -r 2>/dev/null || true
echo "[*] Crontab backed up to $HOST_BACKUP and cleared."

# 5. Kill active tunnels and block fallback IPs
echo "[*] Blocking malicious IPs..."
MALICIOUS_IPS=("192.168.4.97" "192.168.4.73")
for ip in "${MALICIOUS_IPS[@]}"; do
  pkill -9 -f "$ip" || true
  iptables -I INPUT -s "$ip" -j DROP
  iptables -I OUTPUT -d "$ip" -j DROP
done

echo "=== System Quarantine Complete ==="

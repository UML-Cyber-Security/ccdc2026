#!/bin/bash
# neutralize_attack.sh
# Purpose: Kill malicious processes, block attacker IPs, backup crontab, remove known SUID malware

set -euo pipefail

echo "[*] Killing malicious processes and SSH tunnels..."
pkill -9 -f "kprobes|scheduler|jitter|namespace|clock-sync|cgroup|thermal|tcp-monitor|icmp|inode|background|network-opt|netfilter|sys-cache|sshpass|192\.168\.4\.97|192\.168\.4\.73" || true

echo "[*] Blocking attacker IPs..."
iptables -I INPUT -s 192.168.4.97 -j DROP
iptables -I OUTPUT -d 192.168.4.97 -j DROP
iptables -I INPUT -s 192.168.4.73 -j DROP
iptables -I OUTPUT -d 192.168.4.73 -j DROP

echo "[*] Backing up and removing root crontab..."
crontab -l >~/compromised_crontab_$(hostname).txt 2>/dev/null || true
crontab -r 2>/dev/null || true

echo "[*] Removing known SUID binaries..."
rm -f /sbin/kprobes-monitor \
  /usr/local/bin/scheduler-tuner \
  /bin/jitter-monitor \
  /usr/local/bin/namespace-tracker \
  /usr/sbin/clock-sync-daemon \
  /usr/bin/cgroup-monitor \
  /sbin/thermal-monitor \
  /bin/tcp-monitor \
  /usr/bin/icmp-monitor \
  /usr/bin/inode-cleaner \
  /bin/background-indexer \
  /usr/bin/network-optimizer \
  /usr/sbin/netfilter-monitor \
  /usr/bin/sys-cache-refresh \
  /usr/sbin/sys-cache-refresh \
  /usr/local/bin/sys-cache-refresh \
  /bin/network-optimizer || true

echo "[*] Neutralization complete on $(hostname)"

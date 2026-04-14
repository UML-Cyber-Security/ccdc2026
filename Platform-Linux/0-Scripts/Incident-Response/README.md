# Incident Response Scripts

Shell scripts promoted from practice rounds for immediate host containment.

- `neutralize_attack.sh`: Kills known malicious process patterns, blocks attacker IPs, clears root crontab, and removes known malware paths.
- `system_quarantine.sh`: Quarantines newly created rogue SUID binaries, clears temporary payload files, clears crontab persistence, and blocks attacker IPs.

Use with care: both scripts are intentionally aggressive and should be reviewed before execution on critical systems.

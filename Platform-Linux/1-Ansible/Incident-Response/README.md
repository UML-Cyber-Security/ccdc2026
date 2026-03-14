# Incident Response Playbooks

These playbooks were promoted from practice environments for rapid containment and triage during CCDC operations.

## Included playbooks

- `detection-sweep.yaml`: Quick host sweep for suspicious ports, cron jobs, hidden files, and recent `/etc` changes.
- `lock-unauthorized-accounts.yaml`: Locks non-whitelisted users, kills active sessions, and records account lock evidence.
- `malware-forensics-collection.yaml`: Pulls suspicious binaries and metadata back to a local `forensics_repo` for analysis.
- `user-create.yaml`: Creates and hardens blue team user accounts using key-based access and locked sudoers files.

## Usage notes

- Review host groups (`hosts:`), whitelist entries, and variables before running in production.
- Run with explicit inventories and limits first (example: `--limit kiosk`), then expand scope.
- Prefer check mode when safe (`--check`) before executing account lock or persistence actions.

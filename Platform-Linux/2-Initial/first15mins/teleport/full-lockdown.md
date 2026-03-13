# Teleport: First Steps to Locking Down the Service

---

## Step 1: Back Up Teleport

Before making any changes, always back up your Teleport installation first. Choose the script that matches your deployment type.

Scripts are located at:
- `/Platform-Linux/0-Scripts/Teleport/baremetal-backup.sh`
- `/Platform-Linux/0-Scripts/Teleport/container-backup.sh`

**Bare Metal:**
```bash
sudo bash ccdc2026-internal/Platform-Linux/0-Scripts/Teleport/baremetal-backup.sh
```

**Podman:**
```bash
sudo bash ccdc2026-internal/Platform-Linux/0-Scripts/Teleport/container-backup.sh
```

When prompted, choose whether to include user secrets in the backup. Backups are saved to `/opt/teleport-backups/<timestamp>` and include:

| File | Description |
|------|-------------|
| `users.yaml` | All Teleport user accounts |
| `users_with_secrets.yaml` | Users including password hashes — only if you chose yes (sensitive, auto-set to chmod 600) |
| `roles.yaml` | All roles and their permissions |
| `teleport.yaml` | Teleport service configuration |
| `teleport-data.tar.gz` | Full Teleport data directory |

---

## Step 2: Kick All Users Off All Nodes

Before auditing, kick everyone off so you are starting from a clean state.

```bash
tctl sessions ls --format=json | jq -r '.[].id' | xargs -I{} tctl sessions rm {}
```

**On Podman:**
```bash
podman exec teleport tctl sessions ls --format=json | jq -r '.[].id' | xargs -I{} podman exec teleport tctl sessions rm {}
```

> **Note:** This terminates all active node sessions but does not prevent users from reconnecting. Locking accounts in Step 4 will prevent that.

---

## Step 3: Lock Down tctl

Run the script below to restrict the `tctl` binary so that only root/sudo can execute it. This prevents regular users from interacting with the Teleport admin CLI.

Script is located at: `ccdc2026-internal/Platform-Linux/0-Scripts/Teleport/lock-down-tctl.sh`

```bash
sudo bash ccdc2026-internal/Platform-Linux/0-Scripts/Teleport/lock-down-tctl.sh
```

This sets `chmod 700` on `/usr/local/bin/tctl`, meaning:

| Who | Permission |
|-----|-----------|
| Root / sudo | Can execute ✅ |
| Everyone else | Permission denied ❌ |

> **Note:** This has no effect on the Teleport service itself — only on who can use the admin CLI tool.

---

## Step 4: Audit All Users

Run the user audit script to review every Teleport account and take action on each one.

Script is located at: `ccdc2026-internal/Platform-Linux/0-Scripts/Teleport/user-audit.sh`

```bash
sudo bash ccdc2026-internal/Platform-Linux/0-Scripts/Teleport/user-audit.sh
```

**Lock down all users except for the admin user.** For each user you will be prompted to choose:

| Option | Action |
|--------|--------|
| `1` Keep | User is left unchanged |
| `2` Delete | Permanently removes the user |
| `3` Deprivilege | Strips all roles, account still exists |
| `4` Lock | Blocks all login methods, terminates active sessions |

### If There Is No Admin User — Create One

If there is no existing admin user, create a `blueteam` user and give it admin privileges. This will be your admin account going forward.

**Bare Metal:**
```bash
sudo tctl users add blueteam --roles=editor,access --logins=root,ubuntu,ec2-user,student
```

**Podman:**
```bash
sudo podman exec -it teleport tctl users add blueteam --roles=editor,access --logins=root,ubuntu,ec2-user,student
```

After running the command, a one-time signup link will be generated. Open it in a browser to set a password and configure MFA for the account.

---

## Step 5: Monitor Who Is Logged In

To see all active sessions go to this URL on the teleport web ui:

```
https://<TELEPORT-IP>/web/cluster/my-teleport-cluster/sessions
```

To see the audit log go to:

```
https://<TELEPORT-IP>/web/cluster/my-teleport-cluster/audit
```

---

## Quick Reference

```bash
# List all Teleport users
tctl users ls

# List active sessions
tctl sessions ls

# Kick all users off all nodes
tctl sessions ls --format=json | jq -r '.[].id' | xargs -I{} tctl sessions rm {}

# Lock a specific user
tctl lock --user=<username>

# View all active locks
tctl locks ls

# Remove a lock
tctl locks rm <lock-id>

# Force a user to re-authenticate
tctl users reset <username>
```

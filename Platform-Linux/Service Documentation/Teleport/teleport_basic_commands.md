# Basic Teleport commands

---

## Table of Contents
- [Users](#users)
- [Nodes / SSH Access](#nodes--ssh-access)
- [Active Sessions](#active-sessions)
- [Audit Logs](#audit-logs)
- [Hardening & Locking](#hardening--locking)
- [Web UI Quick Reference](#web-ui-quick-reference)
- [tsh Quick Reference](#tsh-quick-reference)

---

## Users

### Add a regular user
```bash
sudo tctl users add <username> --roles=access --logins=root,ubuntu,ec2-user,student
```

### Add a full admin user
```bash
sudo tctl users add <username> --roles=editor,access --logins=root,ubuntu,ec2-user,student
```

This generates a one-time invite link the user opens to set their password and MFA.

### List all users
```bash
sudo tctl users ls
```

### Delete a user
```bash
sudo tctl users rm <username>
```

### Reset a user's password
```bash
sudo tctl users reset <username>
```

### View a user's details
```bash
sudo tctl get users/<username>
```

---

## Nodes / SSH Access

### List all registered nodes
```bash
sudo tctl nodes ls
```

### Connect to a node (via tsh)
```bash
tsh ssh --proxy=teleport.yourdomain.com <os-user>@<node-name>
```

Example:
```bash
tsh ssh --proxy=teleport.chefops.com ubuntu@web-server-01
```

---

## Active Sessions

### Join an active session (observer mode)
```bash
tsh join --proxy=teleport.yourdomain.com <session-id>
```

### Forcefully terminate a session
Join as moderator, then press `t`:
```bash
tsh join --mode=moderator --proxy=teleport.yourdomain.com <session-id>
# Press 't' inside the session to terminate it
```

---

## Audit Logs

Audit events are stored in `/var/lib/teleport/log/events.log` (self-hosted with dir backend).

### View recent logins
```bash
sudo grep '"event":"user.login"' /var/lib/teleport/log/events.log | jq -r '[.time, .user, .method, .success] | @tsv'
```

### View session starts (node connections)
```bash
sudo grep '"event":"session.start"' /var/lib/teleport/log/events.log | jq -r '[.time, .user, .server_hostname, .login] | @tsv'
```

### View all key events (logins + session starts/ends)
```bash
sudo cat /var/lib/teleport/log/events.log | jq -r 'select(.event | test("user.login|session.start|session.end")) | [.time, .event, .user, .server_hostname // "-"] | @tsv'
```

### Watch live events as they happen
```bash
sudo tail -f /var/lib/teleport/log/events.log | grep --line-buffered '"event":"user.login"'
```

### List recorded sessions (completed)
```bash
sudo tctl recordings ls
```

---

## Hardening & Locking

### Lock a user (kicks active sessions + blocks new ones)
```bash
sudo tctl lock --user=<username> --message="Reason here"
```

### Lock by role
```bash
sudo tctl lock --role=contractor --message="Access suspended" --ttl=24h
```

### Lock a specific OS login
```bash
sudo tctl lock --login=root --message="Root access suspended"
```

### List all active locks
```bash
sudo tctl locks ls
```

### Remove a lock
```bash
sudo tctl locks ls                  # find the lock name
sudo tctl rm locks/<lock-name>      # remove it
```

### View all roles
```bash
sudo tctl get roles
```

### View a specific role
```bash
sudo tctl get roles/<role-name>
```

---

## Web UI Quick Reference

Access the Web UI at `https://teleport.yourdomain.com`

| What | Where in UI |
|------|-------------|
| Connect to a node | **Resources** → find server → **Connect** |
| View active sessions | **Activity** → **Active Sessions** |
| View session recordings | **Activity** → **Session Recordings** |
| View audit log | **Activity** → **Audit Log** |
| Manage users | **Access** → **Users** |
| Manage roles | **Access** → **Roles** |
| Manage access requests | **Access** → **Access Requests** |
| Approve/deny access requests | **Access** → **Access Requests** → review pending |

---

## tsh Quick Reference

### Log in
```bash
tsh login --proxy=teleport.yourdomain.com --user=<username>
```

### Log out
```bash
tsh logout
```

### List available nodes
```bash
tsh ls
```

### SSH into a node
```bash
tsh ssh <os-user>@<node-name>
```

### List active sessions
```bash
tsh sessions ls
```

### Play a recorded session
```bash
tsh recordings ls                        # find the session ID
tsh play <session-id>
```

### Check current login status
```bash
tsh status
```

---

## Tips

- `tctl` requires `sudo` in most environments — always prefix with `sudo`
- `tsh` connects through the proxy — make sure `TELEPORT_PROXY` is set or pass `--proxy=` each time
- Set a default proxy to avoid typing it every time:
  ```bash
  export TELEPORT_PROXY=teleport.yourdomain.com
  ```
  Add this to `~/.bashrc` to make it permanent
- Locks are the fastest way to cut off a user in an incident — use `--ttl` so they auto-expire

# Nexterm Bulk Agent Connect Scripts (File-Based)
### `connect-agents-file.sh` — SSH | `connect-rdp-agents-file.sh` — RDP

These scripts read a plain text file containing a list of servers and bulk-add them all to your Nexterm instance in one go. Useful for onboarding many machines at once without manual prompting.

---

## How It Works

1. The script takes a `.txt` file as an argument and logs into Nexterm to get a session token.
2. It reads the file and splits it into server blocks using commas (`,`) as block separators.
3. Each block is parsed line by line. The parser automatically detects:
   - **Name** — first line of the block
   - **IP address** — detected by `x.x.x.x` pattern
   - **Port** — detected if the value is a number between 1–65535 (defaults to `22` for SSH, `3389` for RDP if not provided)
   - **Username / Password** — anything that isn't an IP or port is treated as credentials in order
4. If a username and password are present, an identity is created first, then the server entry is linked to it.
5. If no credentials are present, the entry is added without an identity — Nexterm will prompt for credentials on connect.
6. The last server block does not need a trailing comma.

---

## txt File Format

```
[server-name]
[ip-address]
[port]          <- optional, omit to use default
[username]      <- optional, omit for no identity
[password],     <- optional, omit for no identity. Comma ends the block.
```

### Example `servers.txt`

```
windows-ad
192.168.4.193
3389
blueteam
1qazxsW@1,
gitea
192.168.4.195
blueteam
1qazxsW@1,
semaphore
192.168.4.196
22,
wordpress
192.168.4.198
```

In the above example:
- `windows-ad` and `gitea` — added with saved credentials (identity)
- `semaphore` — explicit port, no credentials
- `wordpress` — no port (uses default), no credentials

---

## Usage

```bash
chmod +x connect-ssh-file.sh
./connect-ssh-file.sh servers.txt
```

```bash
chmod +x connect-rdp-file.sh
./connect-rdp-file.sh rdp-servers.txt
```

You will only be prompted once for your Nexterm login. Everything else is read from the file.

---

## Example Output

```
============================================
     Nexterm Bulk Agent Connect Tool
============================================

Nexterm username: blueteam
Nexterm password:
[+] Logged in successfully.

--- Processing: windows-ad (192.168.4.193:22) ---
  [*] Creating identity for blueteam...
  [+] Identity created (id: 2)
  [+] 'windows-ad' added successfully (id: 3)

--- Processing: semaphore (192.168.4.196:22) ---
  [*] No credentials provided - adding without identity
  [+] 'semaphore' added successfully (id: 4)

[+] Done. Check the Nexterm UI at http://localhost:6989
```

---

## Risk Assessment

| Risk | Severity | Notes |
|------|----------|-------|
| Plaintext credentials stored in the `.txt` file on disk | Medium | Delete or restrict permissions on the file after use: `rm servers.txt` or `chmod 600 servers.txt` |
| File readable by other users if permissions are not set | Medium | Run `chmod 600 servers.txt` before use on shared systems |
| Credentials transmitted over HTTP to Nexterm | Medium | Only a risk if Nexterm is exposed beyond localhost; use a reverse proxy with HTTPS in production |
| No duplicate detection — running the script twice adds duplicate entries | Low | Check Nexterm UI before re-running; duplicates are harmless but untidy |
| Malformed file lines are silently skipped | Low | Double-check your txt file format if an entry doesn't appear in the UI |
| Session token stored in memory only during runtime | Low | Token is not written to disk |

---

## Requirements

- `bash`
- `curl`
- `grep`, `sed`, `xargs` (standard on all Linux/Unix systems)
- Nexterm running and accessible at `http://localhost:6989`
- A valid Nexterm account
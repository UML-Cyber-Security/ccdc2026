# Nexterm Agent Connect Scripts (Interactive)
### `connect-agents.sh` — SSH | `connect-rdp-agents.sh` — RDP

These scripts let you interactively add servers to your Nexterm instance one at a time via the command line. You are prompted for each server's details in a loop and can stop at any time.

---

## How It Works

1. The script logs into your Nexterm instance using the API and retrieves a session token.
2. It then enters a loop asking you for server details one by one.
3. For each server, you choose whether to save credentials as an **identity** (so Nexterm connects automatically) or to leave it without credentials (so Nexterm prompts you each time you connect).
4. If you choose to save credentials, the script first creates an identity via the API, then creates the server entry linked to that identity.
5. If you choose no credentials, the server entry is created without any identity attached.
6. Once added, the server appears immediately in the Nexterm UI sidebar.
7. Type `q` at any prompt to stop the loop and exit.

---

## Usage

```bash
chmod +x connect-agents.sh
./connect-agents.sh
```

```bash
chmod +x connect-rdp-agents.sh
./connect-rdp-agents.sh
```

You will be prompted for:
- Your **Nexterm** login username and password
- For each server:
  - Server name (display name in UI)
  - Server IP address
  - Port (defaults to `22` for SSH, `3389` for RDP if left blank)
  - Whether to save credentials (`a`) or not (`b`)
  - If saving credentials: the remote username and password

---

## Example Session

```
Nexterm username: blueteam
Nexterm password:
[+] Logged in successfully.

Add an agent? (press Enter to continue, q to quit):
  Server name: web-server
  Server IP: 192.168.1.50
  SSH port [22]:

  Identity options:
    a) With identity (save username/password - no prompt on connect)
    b) Without identity (prompted for credentials each time)
  Choice (a/b): a
  SSH username: blueteam
  SSH password:
  [*] Creating identity...
  [+] Identity created (id: 3)
  [*] Adding server entry...
  [+] Agent 'web-server' (192.168.1.50:22) added successfully (id: 4)

Add an agent? (press Enter to continue, q to quit): q

[+] Done. Your agents are now visible in the Nexterm UI at http://localhost:6989
```

---

## Risk Assessment

| Risk | Severity | Notes |
|------|----------|-------|
| Credentials entered in terminal may appear in shell history | Low | Use `history -c` after running if on a shared machine |
| Session token is stored in a shell variable during runtime only | Low | Token is not written to disk |
| Passwords transmitted over HTTP (not HTTPS) to Nexterm | Medium | Only a risk if Nexterm is exposed beyond localhost; use a reverse proxy with HTTPS in production |
| No input validation on IP addresses or server names | Low | Malformed input will simply fail at the API level with an error message |
| Script exits on first login failure — no retry | Low | Just re-run the script |

---

## Requirements

- `bash`
- `curl`
- Nexterm running and accessible at `http://localhost:6989`
- A valid Nexterm account
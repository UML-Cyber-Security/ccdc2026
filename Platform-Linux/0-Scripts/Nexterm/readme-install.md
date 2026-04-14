# Nexterm Install Script
### `install-nexterm.sh`

Installs Docker, deploys Nexterm in a container, and creates your admin account in one shot.

---

## How It Works

1. Prompts for your first name, last name, username, and password upfront.
2. Runs `apt update` and installs Docker.
3. Pulls and starts the Nexterm container with a fixed encryption key, host networking, and a persistent data volume.
4. Waits for Nexterm to be ready (polls up to 20 times).
5. Registers your account via the API.
6. Prints the URL and your login username.

---

## Usage

```bash
chmod +x install-nexterm.sh
./install-nexterm.sh
```

Nexterm will be available at `http://<your-server-ip>:6989` when done.

---

## Risk Assessment

| Risk | Severity | Notes |
|------|----------|-------|
| Encryption key is hardcoded in the script | Medium | Change it before deploying; anyone with the key can decrypt stored credentials |
| Password entered in terminal may appear in shell history | Low | Run `history -c` after if on a shared machine |
| Nexterm runs over HTTP by default | Medium | Set up a reverse proxy with HTTPS before exposing beyond localhost |
| Register endpoint only works once (first time setup) | Low | Running the script a second time on an existing install will fail at the registration step only — Nexterm itself is unaffected |
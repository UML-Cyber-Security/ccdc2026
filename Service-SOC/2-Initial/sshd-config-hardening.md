# SSH Hardening Script

**Author:** Michael Leahy  
**Last Updated:** February 18, 2026  
**Reference:** https://www.blumira.com/blog/secure-ssh-on-linux

## Overview

This bash script automatically hardens SSH configurations on Linux servers by implementing security best practices. The script backs up the existing configuration, applies secure settings, validates the changes, and restarts the SSH service. This script must be run with root privileges.

## Usage
```bash
sudo ./ssh_setup.sh
```

## What the Script Does

### 1. Backup Configuration
- Creates a backup of `/etc/ssh/sshd_config` at `/etc/ssh/sshd_config.bak`
- Preserves original settings for rollback if needed

### 2. Security Modifications

#### Protocol and Cryptography
- **Protocol Version:** Sets to SSH Protocol 2 (eliminates legacy Protocol 1 vulnerabilities)
- **Ciphers:** Configures strong encryption ciphers:
  - `chacha20-poly1305@openssh.com`
  - `aes256-gcm@openssh.com`
  - `aes128-gcm@openssh.com`
  - `aes256-ctr`, `aes192-ctr`, `aes128-ctr`
- **MACs:** Sets secure message authentication codes:
  - `hmac-sha2-512-etm@openssh.com`
  - `hmac-sha2-256-etm@openssh.com`
  - `hmac-sha2-512`, `hmac-sha2-256`
- **Key Exchange Algorithms:** Configures modern KEX algorithms:
  - `curve25519-sha256`
  - `curve25519-sha256@libssh.org`
  - `diffie-hellman-group14-sha256`
  - `diffie-hellman-group16-sha512`
  - `diffie-hellman-group18-sha512`
  - `ecdh-sha2-nistp521`
  - `ecdh-sha2-nistp384`
  - `ecdh-sha2-nistp256`
  - `diffie-hellman-group-exchange-sha256`

#### Authentication Settings
- **Disable Root Login:** Sets `PermitRootLogin no`
- **Enable Public Key Authentication:** Sets `PubkeyAuthentication yes`
- **Disable Empty Passwords:** Sets `PermitEmptyPasswords no`
- **Disable Host-based Authentication:** Sets `HostbasedAuthentication no`
- **Enable Rhosts Ignore:** Sets `IgnoreRhosts yes`
- **Max Authentication Attempts:** Limits to 4 tries via `MaxAuthTries 4`

#### Session Management
- **Login Grace Time:** Sets to 60 seconds (`LoginGraceTime 60`)
- **Max Sessions:** Limits to 10 concurrent sessions (`MaxSessions 10`)
- **Client Alive Interval:** Sets to 300 seconds (`ClientAliveInterval 300`)
- **Client Alive Count:** Sets to 0 (`ClientAliveCountMax 0`) - disconnects idle sessions
- **Max Startups:** Configures connection rate limiting (`MaxStartups 10:30:60`)

#### Additional Security
- **Verbose Logging:** Sets `LogLevel VERBOSE` for detailed audit trails
- **Disable X11 Forwarding:** Sets `X11Forwarding no`
- **Disable User Environment:** Sets `PermitUserEnvironment no`
- **Enable PAM:** Sets `UsePAM yes` for additional authentication modules
- **Comment Include Directive:** Prevents external config file inclusion

### 3. Validation and Service Restart
- Validates configuration syntax with `sshd -t`
- Restarts SSH service only if validation passes
- Exits with error if configuration is invalid
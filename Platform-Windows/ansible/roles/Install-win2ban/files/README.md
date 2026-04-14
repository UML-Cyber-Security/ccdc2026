# Install-win2ban Files

## installwin2ban.ps1
**Functionality:** Downloads and silently installs IPBan (Windows equivalent of Fail2Ban) from GitHub for automated IP blocking based on failed authentication attempts.

**Use Case During Event:** Deploying brute-force protection on Windows hosts to automatically block repeated login failures.

**Risk Assessment:** MEDIUM — Downloads and executes a remote script from GitHub without checksum verification. Aggressive blocking thresholds could lock out legitimate users.

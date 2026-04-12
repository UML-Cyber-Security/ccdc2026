# Platform-Windows

Windows services documentation, scripts, and automation for CCDC 2026.

> [!NOTE]
> Be careful with this documentation, make sure you know what you are doing before making changes as some may affect the services on the machine. Additionally we need to be mindful of the Black Team infrastructure which may use SSH tunnels.

## Quick Start

**Start here:** [15Min.md](15Min.md) — Master playbook for the first 15 minutes of competition.

## Directory Structure

```
Platform-Windows/
├── 15Min.md                  # Master playbook (first 15 minutes)
├── README.md                 # This file
│
├── scripts/                  # ALL runnable PowerShell scripts
│   ├── Harden-GPO.ps1       # Domain GPO hardening (DC only)
│   ├── Enable-WinRM.ps1     # WinRM setup for Ansible
│   ├── AD_Installer.ps1     # Active Directory installer
│   ├── CA_Enterprise_Installer.ps1  # Certificate Authority installer
│   ├── IncidentResponse.ps1 # Merged detection toolkit (run all or individual)
│   ├── LocalPassRotation.ps1    # Rotate local passwords
│   ├── RotateDomainPass.ps1     # Rotate domain passwords
│   ├── GetOUPermissions.ps1     # Export OU permissions (DC only)
│   ├── CreateFileWatcher.ps1    # Monitor file changes
│   ├── KillKnownMalwareProceses.ps1  # Kill known bad processes
│   ├── enableRDP.ps1            # Enable RDP
│   └── exportScheduled.ps1     # Export scheduled tasks
│
├── docs/                     # ALL reference documentation
│   ├── active-directory.md   # AD install, commands, policies
│   ├── certificate-authority.md  # CA setup, templates, certificates
│   ├── dns.md                # DNS setup and commands
│   ├── hardening.md          # Access, DNS, Kerberos hardening
│   ├── event-ids.md          # Windows event ID reference
│   ├── incident-response.md  # IR commands and procedures
│   └── networking.md         # Firewall ports, data export commands
│
├── ansible/                  # Ansible automation
│   ├── README.md             # Setup instructions
│   ├── playbook.yml          # Main playbook
│   ├── inventory/            # Host inventories
│   ├── vars/                 # Variables
│   ├── roles/                # All Ansible roles
│   └── logontracer/          # LogonTracer setup
│
└── CA/Images/                # Screenshots for CA docs
```

## Scripts

All scripts are in `scripts/`. Run from `Platform-Windows\`:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\<script>.ps1
```

**IncidentResponse.ps1** combines multiple detection tools into one:
```powershell
# Run all detection functions
.\scripts\IncidentResponse.ps1

# Run a specific function
.\scripts\IncidentResponse.ps1 -Function Find-HiddenExecutables
.\scripts\IncidentResponse.ps1 -Function Block-OutboundIP -IP "10.0.0.50"
```

## Documentation

All docs are in `docs/`. Key references:
- [Active Directory](docs/active-directory.md) — Installation, commands, policies
- [Certificate Authority](docs/certificate-authority.md) — Setup, templates, certificates
- [DNS](docs/dns.md) — Installation and commands
- [Hardening](docs/hardening.md) — Access control, DNS, Kerberos
- [Event IDs](docs/event-ids.md) — Windows security event reference
- [Incident Response](docs/incident-response.md) — Commands and procedures
- [Networking](docs/networking.md) — Firewall ports, data exports

---

# Tools & Scripts — First 15 Minutes (15Min.md)

Inline scripts embedded in the first-15-minute runbook. These are copy-paste blocks, not standalone files.

## Step 1: Reset Hosts File
**Functionality:** Backs up `C:\Windows\System32\drivers\etc\hosts` then resets it to localhost-only defaults.

**Use Case During Event:** Removing any malicious host file redirects planted before competition start.

**Risk Assessment:** LOW — Overwrites hosts file. Backup saved to Documents. Could break apps relying on custom host entries.

## Step 1: Install Firefox
**Functionality:** Downloads and silently installs latest Firefox from Mozilla CDN.

**Use Case During Event:** Deploying a secure browser for web-based management during competition.

**Risk Assessment:** LOW — No version pinning or checksum validation. Download over HTTPS.

## Step 1: Install Sysinternals + Sysmon
**Functionality:** Downloads 13 Sysinternals tools, accepts EULAs via registry, sets run-as-admin, installs Sysmon with a hardened XML config, and launches Process Explorer, Autoruns, and TCPView.

**Use Case During Event:** Immediate deployment of system monitoring and forensics tools at competition start. Sysmon provides persistent event logging for process, network, registry, and file activity.

**Risk Assessment:** MEDIUM — Downloads binaries without integrity verification. Sysmon install is persistent across reboots. Sets all tools to RUNASADMIN via registry.

## Step 2: Disable Local Accounts
**Functionality:** Disables the Guest and Administrator local accounts.

**Use Case During Event:** Eliminating default account attack surface immediately.

**Risk Assessment:** MEDIUM — Could lock out access if no other admin account exists. Does not terminate active sessions.

## Step 2: Disable AD Accounts (DC only)
**Functionality:** Disables the Guest and Administrator AD accounts.

**Use Case During Event:** Eliminating default domain account attack surface on the DC.

**Risk Assessment:** MEDIUM — Could lock out domain admin access if no other admin exists.

## Step 2: Surgical Group & GPO Cleanup (DC only)
**Functionality:** Backs up all group memberships and GPO link state to CSV. Audits privileged groups against a desired-state config. Removes unauthorized members, adds missing ones. Unlinks non-default GPOs without deleting them. Dry-run with confirmation prompt.

**Use Case During Event:** Cleaning up AD privileged group memberships and suspicious GPOs left by red team or from pre-competition state.

**Risk Assessment:** HIGH — Modifies privileged group membership domain-wide. GPO unlinking can affect applied policies. `$ourUsers` list must be populated before use or no one gets admin.

## Step 3: Show Active Sessions
**Functionality:** Enumerates all active RDP, SSH, and WinRM sessions with status and user details.

**Use Case During Event:** Identifying unauthorized remote sessions from red team or unknown users.

**Risk Assessment:** LOW — Read-only enumeration.

## Step 3: Disable SSH
**Functionality:** Kills SSH processes, stops and disables the sshd service, and blocks ports 22/2222 via firewall.

**Use Case During Event:** Shutting down SSH access to eliminate a common remote access vector.

**Risk Assessment:** HIGH — Permanent service disable. If SSH is the active management channel, access will be lost. Firewall rule persists across reboots.

## Step 4: Install Nmap
**Functionality:** Downloads and installs Nmap 7.98 with Npcap driver from nmap.org.

**Use Case During Event:** Deploying network scanning capability for service discovery and verification.

**Risk Assessment:** LOW — No checksum validation. Npcap driver install may temporarily affect network stack.

## Step 4: Install Wireshark
**Functionality:** Downloads and silently installs Wireshark 4.6.4.

**Use Case During Event:** Deploying packet capture capability for network traffic analysis during incidents.

**Risk Assessment:** LOW — No integrity check. Enables capture of all network traffic.

## Step 4: Enable Firewall
**Functionality:** Enables Windows Firewall on all profiles. Allows RDP, File/Printer Sharing, and ICMP ping.

**Use Case During Event:** Ensuring the firewall is active on every host while keeping required services accessible.

**Risk Assessment:** MEDIUM — Turning on the firewall could block services that depend on it being off. Opens several inbound rule groups.

## Step 5: Harden-GPO (DC only)
**Functionality:** Full domain hardening via GPO: audit policy, NIST password policy, SMB/Kerberos/LDAP encryption, credential protection, Defender enforcement, network hardening. Same as `scripts/Harden-GPO.ps1`.

**Use Case During Event:** Rapid one-shot domain hardening from the DC. Primary defensive GPO tool.

**Risk Assessment:** HIGH — Can break legacy services. See `scripts/README.md` for full details. Use `-Safe` or `-SuperSafe` flags to reduce risk.

## Step 6: Enable Windows Defender
**Functionality:** Multi-phase Defender recovery: preflight checks, fix red team ACL sabotage on service registry keys, re-enable disabled drivers (with Authenticode verification), pull GPO settings, remove planted exclusions, enable real-time protection, verify operational status.

**Use Case During Event:** Recovering Windows Defender after red team disables or sabotages it.

**Risk Assessment:** MEDIUM — Modifies registry ACLs on Defender service keys. Re-enables boot-start drivers only after verifying binary signatures. Removes all Defender exclusions.

## Step 7: Install Chainsaw
**Functionality:** Downloads Chainsaw (log analysis tool) from GitHub and extracts to `C:\Chainsaw`.

**Use Case During Event:** Deploying a fast Windows event log forensics tool for threat hunting.

**Risk Assessment:** LOW — Download without integrity check. Tool is read-only forensics, no system modifications.

## Step 8: Chainsaw Triage (8 hunt commands)
**Functionality:** Eight targeted Chainsaw hunt commands covering critical/high findings, lateral movement, persistence, credential access, log tampering, suspicious PowerShell, Ansible detection, and IOC search.

**Use Case During Event:** Rapid threat hunting through Windows event logs to find red team activity.

**Risk Assessment:** LOW — Read-only log analysis. No system modifications.

## Step 9: Local Password Rotation
**Functionality:** Generates random 20-character passwords for all enabled local users except an exclusion list. Logs passwords to CSV.

**Use Case During Event:** Rotating local passwords after initial access to invalidate any compromised credentials.

**Risk Assessment:** HIGH — Plaintext passwords saved to CSV. Service accounts may break. No user notification.

## Step 9: AD Password Rotation (DC only)
**Functionality:** Generates random 20-character passwords for all enabled domain users except an exclusion list. Forces password change at next logon. Logs to CSV.

**Use Case During Event:** Mass domain password rotation to invalidate compromised credentials after red team access.

**Risk Assessment:** HIGH — Plaintext domain passwords in CSV. Forces all users to change password at logon.

## Reference: Disable Unwanted Programs & Services
**Functionality:** Stops and disables suspicious services, removes unauthorized startup items, blocks processes via Defender ASR rules, cleans suspicious scheduled tasks.

**Use Case During Event:** Removing red team persistence and unauthorized software.

**Risk Assessment:** HIGH — Stops services permanently. ASR rules block entire categories of executables. Scheduled task removal is irreversible.

## Reference: Disable WinRM
**Functionality:** Kills WinRM sessions, stops the service, and blocks ports 5985/5986 via firewall.

**Use Case During Event:** Shutting down WinRM if it's being exploited or is no longer needed.

**Risk Assessment:** HIGH — If WinRM is the active Ansible management channel, all automation will break.

## Reference: Enable Defender (Local, No GPO)
**Functionality:** Standalone Defender recovery script with the same multi-phase approach as Step 6 but without requiring GPO infrastructure.

**Use Case During Event:** Recovering Defender on non-domain-joined machines or when GPO infrastructure is unavailable.

**Risk Assessment:** MEDIUM — Same registry ACL and driver changes as Step 6. No GPO dependency.

## Reference: Block EXEs from Running
**Functionality:** Uses Defender ASR rules or AppLocker to block execution of specific executables by path or hash.

**Use Case During Event:** Blocking known red team tools or malicious binaries from executing.

**Risk Assessment:** HIGH — Can block legitimate programs if paths overlap. ASR rules apply broadly. AppLocker requires testing.

## Reference: Restore GPO from Backup
**Functionality:** Restores GPOs from a local backup zip file created by Harden-GPO.ps1.

**Use Case During Event:** Rolling back GPO changes if hardening broke critical services.

**Risk Assessment:** MEDIUM — Overwrites current GPO state. Could restore compromised GPOs if backup was taken post-compromise.

## Reference: WinStride Service Setup
**Functionality:** Installs and configures WinStride monitoring agent with server and remote agent components. Opens HTTP/HTTPS firewall ports.

**Use Case During Event:** Deploying the WinStride monitoring service for centralized Windows event visualization.

**Risk Assessment:** MEDIUM — Opens HTTP/HTTPS ports. Service runs with system privileges. Firewall rules created for inbound access.

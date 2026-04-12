# Scripts

## AD_Installer.ps1
**Functionality:** Interactive menu for installing/uninstalling AD DS role, promoting/demoting domain controllers, and upgrading forest functional levels.

**Use Case During Event:** Setting up or restoring Active Directory on a new or recovered domain controller.

**Risk Assessment:** HIGH — Demotion of the last DC permanently destroys the domain. Forest promotion and functional level upgrades are irreversible.

## CA_Enterprise_Installer.ps1
**Functionality:** Installs, publishes, or uninstalls an Enterprise Root Certificate Authority including self-signed cert creation and AD PKI object management.

**Use Case During Event:** Standing up or recovering the domain's certificate infrastructure for internal TLS/auth.

**Risk Assessment:** MEDIUM — Uninstall deletes all cert and CRL infrastructure without per-item confirmation. Can orphan already-issued certificates.

## CreateFileWatcher.ps1
**Functionality:** Monitors `C:\Users` recursively and logs file creation/modification events to the console in real time.

**Use Case During Event:** Detecting red team file drops or unauthorized changes in user directories.

**Risk Assessment:** LOW — Read-only monitoring. May produce excessive output on busy systems.

## Enable-WinRM.ps1
**Functionality:** Enables WinRM with HTTPS listeners, configures authentication (Basic, CredSSP), creates self-signed certificates, and opens firewall ports 5985/5986.

**Use Case During Event:** Enabling remote management so Ansible can reach Windows hosts.

**Risk Assessment:** MEDIUM — Opens remote management ports on all firewall profiles. Sets LocalAccountTokenFilterPolicy=1, reducing UAC token filtering.

## enableRDP.ps1
**Functionality:** Enables Remote Desktop by activating firewall rules, creating an inbound rule for TCP 3389, and setting registry values to allow RDP connections.

**Use Case During Event:** Enabling remote desktop access to manage Windows machines during competition.

**Risk Assessment:** MEDIUM — Exposes port 3389. Creates duplicate firewall rules if run multiple times. No encryption or session timeout configured.

## exportScheduled.ps1
**Functionality:** Enumerates all Windows scheduled tasks and exports them to a CSV file with task names, paths, descriptions, commands, and arguments.

**Use Case During Event:** Auditing scheduled tasks to find red team persistence mechanisms.

**Risk Assessment:** LOW — Read-only enumeration. Output CSV may expose sensitive command-line arguments if leaked.

## GetOUPermissions.ps1
**Functionality:** Enumerates all OUs in the domain and exports their ACLs and AD permissions to a CSV file.

**Use Case During Event:** Auditing OU permissions to detect unauthorized delegation or privilege escalation paths.

**Risk Assessment:** LOW — Read-only. Output CSV contains sensitive permission data that should be protected.

## Harden-GPO.ps1
**Functionality:** Comprehensive domain hardening via GPO: audit policy, NIST password policy, SMB/Kerberos/LDAP encryption, credential protection, Defender enforcement, and network hardening. Supports `-Safe` and `-SuperSafe` modes to reduce breakage risk.

**Use Case During Event:** Rapidly hardening the domain from a single DC after initial access. Primary defensive tool for GPO-based lockdown.

**Risk Assessment:** HIGH — Disabling SMB1 and enforcing AES-only Kerberos can break legacy services. `-Reset` flag deletes all custom GPOs. Password policy changes affect the entire domain. Always backs up GPOs before changes.

## IncidentResponse.ps1
**Functionality:** IR toolkit with 7 functions: detect recently created accounts, search security events, find failed logons, locate hidden executables, enumerate network connections, list recent processes, and block outbound IPs via firewall.

**Use Case During Event:** Primary detection and investigation tool during active incident response.

**Risk Assessment:** MEDIUM — Block-OutboundIP creates firewall rules without IP validation. Hidden file scan on full C: drive may be slow. Most functions are read-only.

## KillKnownMalwareProceses.ps1
**Functionality:** Force-terminates processes matching hardcoded known malware tool names (Mimikatz, Netcat, PowerSploit, Metasploit, etc.).

**Use Case During Event:** Quick kill of known offensive tools during active red team engagement.

**Risk Assessment:** MEDIUM — No confirmation before killing. Could terminate legitimate tools with similar names. No logging of terminated processes.

## LocalPassRotation.ps1
**Functionality:** Generates random 20-character passwords for all enabled local users except a hardcoded exclusion list. Logs new passwords to a CSV file.

**Use Case During Event:** Rotating all local passwords after initial access to lock out red team credentials.

**Risk Assessment:** HIGH — Stores plaintext passwords in CSV at `C:\Users\Administrator\local_user_passwords.csv`. Service accounts may lose access without warning.

## RotateDomainPass.ps1
**Functionality:** Generates random 20-character passwords for all enabled domain users except an exclusion list. Forces password change at next logon. Logs passwords to CSV.

**Use Case During Event:** Mass domain password rotation to invalidate any compromised credentials after red team access.

**Risk Assessment:** HIGH — Stores plaintext domain passwords in CSV. Forces all users to change password at next logon. Can cause business disruption if service accounts aren't excluded.

## Strip-Groups-Nuclear.ps1
**Functionality:** Removes ALL group memberships from every domain user except configured exclusions, then rebuilds only the specified privileged groups to match desired state. Creates backup CSV before changes.

**Use Case During Event:** Nuclear option to reset all AD group memberships if red team has planted unauthorized privilege escalation.

**Risk Assessment:** CRITICAL — Permanently removes all custom groups (department, application, resource groups). Manual recovery from backup is complex. Users lose all resource access during execution.

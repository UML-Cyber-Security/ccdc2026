# Tools & Scripts

## playbook.yml
**Functionality:** Main entry-point playbook that selectively runs Ansible roles against Windows hosts. Most roles are commented out by default.

**Use Case During Event:** Orchestrating automated tasks across all Windows machines from a single command.

**Risk Assessment:** LOW — No direct changes. Uncommenting roles without review could trigger unintended mass changes across all hosts.

## roles/build-dynamic-ini
**Functionality:** Queries Windows hosts by domain role via WMI and groups them into a dynamic inventory file at `inventory/domain_inventory.ini`.

**Use Case During Event:** Auto-discovering and categorizing Windows machines by role (workstation, server, DC) for targeted playbook runs.

**Risk Assessment:** LOW — Read-only enumeration. Overwrites the inventory file, which could break subsequent plays if group names mismatch.

## roles/check-alive
**Functionality:** Simple connectivity test using win_ping to verify Ansible can reach Windows hosts.

**Use Case During Event:** Quick health check to confirm which Windows machines are reachable before running other roles.

**Risk Assessment:** LOW — Read-only. No system changes.

## roles/create-team-accounts
**Functionality:** Creates local AD users (`blueteam`, `SirTempleton`) with a hardcoded password and password_never_expires set.

**Use Case During Event:** Rapidly deploying team accounts on all Windows hosts at competition start.

**Risk Assessment:** HIGH — Hardcoded plaintext password in YAML vars file. Non-expiring password is a security gap. No handling for pre-existing users.

## roles/enum-win-acc
**Functionality:** Enumerates local users, groups, service accounts, and computer info on each host. Saves JSON reports to the control node.

**Use Case During Event:** Auditing all Windows accounts across the environment to find unauthorized users or group changes.

**Risk Assessment:** LOW — Read-only. Output JSON files contain sensitive account data and should be protected.

## roles/find-DC
**Functionality:** Uses WMI to detect each host's domain role (workstation, member server, DC) and writes the result to a dynamic inventory file.

**Use Case During Event:** Identifying which machines are domain controllers for targeted DC-only operations.

**Risk Assessment:** LOW — Read-only enumeration. May fail on firewalled hosts.

## roles/install-chocolatey
**Functionality:** Installs the Chocolatey package manager on target Windows hosts.

**Use Case During Event:** Enabling easy software installation on Windows machines via command line.

**Risk Assessment:** LOW — Standard tool installation. No post-install validation.

## roles/Install-win2ban
**Functionality:** Installs and configures IPBan (brute-force mitigation) via GitHub script download. Configures 3-day ban duration and 20-attempt threshold.

**Use Case During Event:** Deploying automated brute-force protection across all Windows hosts.

**Risk Assessment:** HIGH — Downloads and executes PowerShell from GitHub without hash verification. Misconfigured thresholds could lock out legitimate users. No rollback.

## roles/kill ssh
**Functionality:** Stops OpenSSH service, kills sshd processes, removes the OpenSSH capability, deletes service registry entries, and blocks ports 22 and 2222 via firewall.

**Use Case During Event:** Removing SSH access from Windows hosts to eliminate a common red team remote access vector.

**Risk Assessment:** CRITICAL — If SSH is the active management channel, this will disconnect mid-playbook and break all subsequent tasks. Service deletion is permanent.

## roles/list-process
**Functionality:** Enumerates all running processes with owner, PID, command line, and parent PID. Saves JSON output to the control node.

**Use Case During Event:** Capturing a process snapshot across all Windows hosts for forensic analysis or anomaly detection.

**Risk Assessment:** LOW — Read-only. Output command lines may contain embedded credentials.

## roles/rotate-domain-acc
**Functionality:** Copies a PowerShell password rotation script to target, executes it, and retrieves the resulting plaintext password CSV to the control node.

**Use Case During Event:** Mass rotation of domain account passwords from Ansible after suspected credential compromise.

**Risk Assessment:** HIGH — Outputs domain passwords in plaintext CSV with no encryption. No validation of password change success.

## roles/rotate-user-creds
**Functionality:** Gets enabled local users, generates random 18-character passwords, rotates them, and saves a plaintext password CSV to the control node.

**Use Case During Event:** Rotating all local account passwords across the environment after initial access.

**Risk Assessment:** HIGH — Plaintext password storage on control node. Limited exclusion list (only Administrator/Guest). Could lock out service accounts.

## roles/run-ps-scripts
**Functionality:** Copies a PowerShell script from the scripts directory to `C:\Temp\` on the target and executes it with ExecutionPolicy Bypass.

**Use Case During Event:** Running any standalone PowerShell script across all Windows hosts via Ansible.

**Risk Assessment:** CRITICAL — Arbitrary code execution with no script validation. ExecutionPolicy Bypass weakens security controls. Risk depends entirely on which script is run.

## roles/sysinternal
**Functionality:** Copies and executes install scripts for Wireshark, Nmap, Sysinternals Suite, and Firefox on target hosts.

**Use Case During Event:** Mass deployment of diagnostic and analysis tools across all Windows machines at competition start.

**Risk Assessment:** MEDIUM — Executes four external scripts with Bypass policy. Adds network monitoring tools. No post-install verification.

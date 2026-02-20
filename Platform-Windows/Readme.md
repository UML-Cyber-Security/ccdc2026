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

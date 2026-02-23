# Incident Response Commands

- [Automated Toolkit](#automated-toolkit)
- [Domain Wide Commands](#domain-wide-commands)
- [Password Rotation](#password-rotation)
- [Remote Access](#remote-access)
- [Network & Processes](#network--processes)
- [Event Log Analysis](#event-log-analysis)
- [Threat Hunting](#threat-hunting)

---

## Automated Toolkit

Run all detection functions at once:
```powershell
.\scripts\IncidentResponse.ps1
```

Run a specific function:
```powershell
.\scripts\IncidentResponse.ps1 -Function Find-HiddenExecutables
.\scripts\IncidentResponse.ps1 -Function Block-OutboundIP -IP "10.0.0.50"
.\scripts\IncidentResponse.ps1 -Function Get-RecentProcesses -MinutesAgo 30
```

Available functions: `Block-OutboundIP`, `Find-RecentAccounts`, `Get-RecentSecurityEvents`, `Search-FailedLogons`, `Find-HiddenExecutables`, `Get-SuspiciousConnections`, `Get-RecentProcesses`

---

## Domain Wide Commands
```powershell
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
Invoke-Command -ComputerName $computers -ScriptBlock { <your command here> } -Credential (Get-Credential)
```

---

## Password Rotation

### Rotate Domain Account Passwords
**Script:** `scripts\RotateDomainPass.ps1`

> [!NOTE]
> This script outputs passwords to `C:\Users\Administrator\domain_user_passwords.csv`

### Rotate Local Account Passwords
**Script:** `scripts\LocalPassRotation.ps1`

> [!NOTE]
> This script outputs passwords to `C:\Users\Administrator\local_user_passwords.csv`

---

## Remote Access

### WinRM Session
```powershell
Enter-PSSession -ComputerName 192.168.1.100 -Credential (Get-Credential)
```

### Add Trusted Host
```powershell
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.100" -Force
```

### Enable RDP
**Script:** `scripts\enableRDP.ps1`

Through firewall:
```powershell
Get-NetFirewallRule -DisplayGroup "Remote Desktop"
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

Through registry:
```powershell
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1
```

---

## Network & Processes

### List TCP Connections (netstat)
```powershell
Get-NetTCPConnection | Sort-Object State | Format-Table -AutoSize
```

### List Connections with Process Info
```powershell
.\scripts\IncidentResponse.ps1 -Function Get-SuspiciousConnections
```

### Kill Known Malware Processes
**Script:** `scripts\KillKnownMalwareProceses.ps1`

### Flush DNS
```powershell
Clear-DnsClientCache
```

---

## Event Log Analysis

### Recent Security Events
```powershell
.\scripts\IncidentResponse.ps1 -Function Get-RecentSecurityEvents
```

### Failed Logon Attempts
```powershell
.\scripts\IncidentResponse.ps1 -Function Search-FailedLogons
```

### Recently Created Accounts
```powershell
.\scripts\IncidentResponse.ps1 -Function Find-RecentAccounts
```

See also: [Event IDs Reference](event-ids.md)

---

## Threat Hunting

### Find Hidden Executables
```powershell
.\scripts\IncidentResponse.ps1 -Function Find-HiddenExecutables
```

### Recent Processes (last 10 min)
```powershell
.\scripts\IncidentResponse.ps1 -Function Get-RecentProcesses
```

### Block Outbound IP
```powershell
.\scripts\IncidentResponse.ps1 -Function Block-OutboundIP -IP "123.456.789.0"
```

### Create File Watcher
**Script:** `scripts\CreateFileWatcher.ps1`

To unregister:
```powershell
Unregister-Event -SubscriptionId 1
```

List event IDs:
```powershell
Get-EventSubscriber
```

### OU Permissions Export (DC only)
**Script:** `scripts\GetOUPermissions.ps1`

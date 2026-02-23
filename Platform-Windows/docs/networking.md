# Networking

- [Firewall Port Reference](#firewall-port-reference)
- [Data Export Commands](#data-export-commands)
  - [Firewall Rules Dump](#firewall-rules-dump)
  - [AD Dump](#ad-dump)
  - [DNS Records Dump](#dns-records-dump)

---

## Firewall Port Reference

| Port | Service | Status |
|------|---------|--------|
| 50, 500, 4500 UDP | IPSEC | Block unless using IPsec within the domain |
| 53 UDP | DNS | |
| 67 UDP | DHCP | If server is used for DHCP, do not block |
| 135, 593 TCP/UDP | RPC | If domain-connected, restrict to local DC. If on the DC or cert authority, allow local networks. Otherwise, block. |
| 137, 138, 139 TCP/UDP | NetBIOS | Not necessary in 2019, block access |
| 389, 636 TCP | LDAP | Necessary on DC |
| 3389 TCP | RDP | If RDP is necessary for local management but not for scoring, restrict to local network. |
| 5985, 5986 TCP | WinRM | Best to leave alone if present - blocking will break Ansible/management |

---

## Data Export Commands

### Firewall Rules Dump
```powershell
$basePath = [System.IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "Dump")
if (!(Test-Path -Path $basePath)) {
    New-Item -ItemType Directory -Force -Path $basePath
}

function Export-FirewallRules {
    param ([string]$profile)
    $outputFile = Join-Path $basePath "FirewallRules_$profile.txt"
    Get-NetFirewallRule -Enabled True -Profile $profile | Format-Table -Property DisplayName, Action, Direction, Profile, Enabled, Group, LocalPort, RemotePort, Protocol | Out-File -FilePath $outputFile
    Write-Host "Exported firewall rules for $profile profile to $outputFile"
}

Export-FirewallRules -profile "Domain"
Export-FirewallRules -profile "Private"
Export-FirewallRules -profile "Public"
```

### AD Dump
```powershell
$basePath = [System.IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "Dump")
if (!(Test-Path -Path $basePath)) {
    New-Item -ItemType Directory -Force -Path $basePath
}

function Export-ADConfiguration {
    Get-ADDomain | Export-Clixml -Path "$basePath\DomainConfig.xml"
    Get-ADOrganizationalUnit -Filter * | Export-Clixml -Path "$basePath\OrganizationalUnits.xml"
    Get-ADUser -Filter * | Export-Clixml -Path "$basePath\Users.xml"
    Get-ADGroup -Filter * | Export-Clixml -Path "$basePath\Groups.xml"
    Get-GPO -All | Export-Clixml -Path "$basePath\GPOs.xml"
}

Export-ADConfiguration
Write-Host "Active Directory data exported to $basePath"
```

### DNS Records Dump
```powershell
$folderPath = [System.IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "Dump")
if (!(Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Force -Path $folderPath
}

# Check if Domain Controller
$dc = (Get-WmiObject Win32_ComputerSystem).DomainRole
if ($dc -eq 5 -or $dc -eq 6) {
    $dnsZones = Get-DnsServerZone
    foreach ($zone in $dnsZones) {
        $zoneName = $zone.ZoneName
        $records = Get-DnsServerResourceRecord -ZoneName $zoneName
        $records | Export-Csv -Path "$folderPath\DNS_$zoneName.csv" -NoTypeInformation
    }
    Get-ChildItem "$folderPath\DNS_*.csv" | Get-Content | Out-File "$folderPath\DNS.txt" -Encoding utf8
    Get-ChildItem "$folderPath\DNS_*.csv" | Remove-Item
} else {
    Write-Host "This machine is not a Domain Controller."
}
```

### Scheduled Tasks Export
**Script:** `scripts\exportScheduled.ps1`

Exports scheduled tasks to `C:\validTaskSchedulerXREF.csv` with TaskName, TaskPath, Description, Actions, and Arguments.

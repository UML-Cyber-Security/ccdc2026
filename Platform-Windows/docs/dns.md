# DNS

- [Overview](#overview)
- [Installation](#installation)
- [DNS Manager](#dns-manager)
- [DNS Commands Reference](#dns-commands-reference)

---

## Overview

DNS (Domain Name System) translates human-readable domain names (e.g. www.example.com) into machine-readable IP addresses (e.g. 192.0.2.1). It functions like a phonebook for the internet.

---

## Installation

1. Open Server Manager -> top right -> Add or Remove Features -> Add
2. Select **DNS Server** and click next
3. Use default options until Install

> [!NOTE]
> If you will be downloading AD DS, install it at the same time as DNS for seamless integration.

---

## DNS Manager

Open via Server Manager -> Tools -> **DNS Manager**. From here you can create:
- Forward and reverse lookup zones
- Trust points
- Conditional forwarders
- Server properties (security, logging)

### Creating a Forward Lookup Zone
1. Right click Forward Lookup Zone -> New Zone
2. Select **Primary zone**
3. Enter zone name (e.g. `zodu.com`) - Host A records will be like `example.zodu.com`
4. Use defaults for remaining pages

The zone will contain:
- **SOA (State of Authority)** - stores zone info (last updated, refresh interval, etc.)
- **NS (Name Server)** - points to authoritative name server

### Creating an A Record
1. Right click your Forward Lookup Zone -> New A record
2. Enter name (e.g. `nginx`) and IP address (e.g. `192.168.2.250`)
3. Click Add Host

Now `nginx.zodu.com` resolves to `192.168.2.250`.

---

## DNS Commands Reference

### Module Setup
```powershell
Import-Module DnsServer
```

### Server Information
```powershell
Get-DnsServer
```

### Zone Management

#### List Zones
```powershell
Get-DnsServerZone
```

#### Get Zone Details
```powershell
Get-DnsServerZone -Name "example.com"
```

#### Create Primary Zone
```powershell
Add-DnsServerPrimaryZone -Name "example.com" -ZoneFile "example.com.dns"
```

#### Create Secondary Zone
```powershell
Add-DnsServerSecondaryZone -Name "example.com" -MasterServers "192.168.1.1"
```

### Record Management

#### Add A Record
```powershell
Add-DnsServerResourceRecordA -Name "host1" -ZoneName "example.com" -IPv4Address "192.168.1.100"
```

#### List All Records
```powershell
Get-DnsServerResourceRecord -ZoneName "example.com"
```

#### List Specific Record Type
```powershell
Get-DnsServerResourceRecordA -ZoneName "example.com"
```

#### Remove Record
```powershell
Remove-DnsServerResourceRecord -ZoneName "example.com" -Name "host1" -RecordType A -Force
```

#### Modify Record
```powershell
Set-DnsServerResourceRecordA -ZoneName "example.com" -Name "host1" -IPv4Address "192.168.1.101"
```

### Cache and Queries

#### Clear Cache
```powershell
Clear-DnsServerCache
```

#### Query DNS Record
```powershell
Resolve-DnsName "host1.example.com"
```

### Forwarders

#### Add Forwarder
```powershell
Set-DnsServerForwarder -IPAddress "192.168.1.1"
```

#### Remove Forwarder
```powershell
Remove-DnsServerForwarder -IPAddress "192.168.1.1"
```

#### Conditional Forwarder
```powershell
Add-DnsServerConditionalForwarderZone -Name "externaldomain.com" -MasterServers "8.8.8.8" -ReplicationScope "Forest"
```

### Recursion
```powershell
Set-DnsServerRecursionScope -Enable $true
```

### Health and Logs

#### Test DNS Server
```powershell
Test-DnsServer
```

#### Get Event Logs
```powershell
Get-WinEvent -LogName "DNS Server" -MaxEvents 10
```

### Zone Import/Export

#### Export Zone
```powershell
Export-DnsServerZone -Name "example.com" -FileName "C:\path\to\export\example.com.dns"
```

#### Import Zone
```powershell
Import-DnsServerZone -FileName "C:\path\to\import\example.com.dns"
```

### Zone Transfers
```powershell
Set-DnsServerZoneTransferPolicy -ZoneName "example.com" -AllowZoneTransfers $true
```

### DNS Server Policies

#### Create Zone Scope
```powershell
Add-DnsServerZoneScope -ZoneName "example.com" -Name "Scope1"
```

#### Get Zone Scope
```powershell
Get-DnsServerZoneScope -ZoneName "example.com"
```

#### Create Subnet
```powershell
Add-DnsServerZoneScopeSubnet -ZoneName "example.com" -ZoneScope "Scope1" -Subnet "192.168.1.0/24"
```

#### Display All Policies
```powershell
Get-DnsServerQueryResolutionPolicy
```

#### Display Specific Policy
```powershell
Get-DnsServerQueryResolutionPolicy | Where-Object { $_.Name -eq "DenyInternalToExternal" }
```

#### Remove Policy
```powershell
Remove-DnsServerQueryResolutionPolicy -Name "PolicyName"
```

#### Whitelist/Blacklist Policies
```powershell
Add-DnsServerQueryResolutionPolicy -Name "AllowDevZodu" -Action ALLOW -ClientSubnet "eq,InternalSubnet" -ZoneScope "InternalScope,2" -ZoneName "zodu.com"
Add-DnsServerQueryResolutionPolicy -Name "AllowProxyZodu" -Action ALLOW -ClientSubnet "eq,ProxySubnet" -ZoneScope "ProxyScope,1" -ZoneName "zodu.com"
Add-DnsServerQueryResolutionPolicy -Name "DenyDevToPub" -Action DENY -ClientSubnet "eq,InternalSubnet" -ZoneName "zodu.com"
```

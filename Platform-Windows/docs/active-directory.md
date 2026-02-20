# Active Directory

- [Installation](#installation)
  - [Install AD DS (GUI)](#install-ad-ds-gui)
  - [Install AD DS (PowerShell)](#install-ad-ds-powershell)
  - [CA Installation (GUI)](#ca-installation-gui)
  - [CA Installation (PowerShell)](#ca-installation-powershell)
- [Joining a Windows Machine to AD](#joining-a-windows-machine-to-ad)
- [Account & Password Group Policies](#account--password-group-policies)
- [Split-Brain DNS with Multiple Domains](#split-brain-dns-with-multiple-domains)
- [AD Commands Reference](#ad-commands-reference)
  - [Setup](#setup)
  - [User Management](#user-management-commands)
  - [Group Management](#group-management-commands)
  - [Computer Management](#computer-management-commands)
  - [OU Management](#organizational-units-ou-management-commands)
  - [Querying and Reporting](#querying-and-reporting-commands)
  - [Domain Services](#active-directory-domain-services-commands)
  - [Replication](#replicating-and-synchronizing-ad)
  - [Backup and Restore](#active-directory-backup-and-restore-dssu)

---

## Installation

Authors: Ofir and Irakli

### Install AD DS (GUI)
**Install the AD DS role**:
  1. Open Server Manager
  2. Click Manage -> Add Roles and Features
  3. Server Roles: check Active Directory Domain Services
      - When prompted, click Add Features
  4. Click Install

**Promote the server to a Domain Controller (new forest)**:
  1. When the role is done installing, in Server Manager click the yellow flag
  2. Click Promote this server to a domain controller
  3. In Deployment Configuration:
      - For new environment: choose Add a new forest
      - Enter Root domain name (e.g. zodu.com)
  4. Domain Controller Options:
      - Choose Forest functional level and Domain functional level (Windows Server 2016 is the newest one)
      - Leave Domain Name System (DNS) server checked (if this will be DNS)
      - Set Directory Services Restore Mode (DSRM) password
  5. Let prerequisite check run -> if no blocking errors, click Install
  6. Server will reboot and come back as a domain controller for the new forest

### Install AD DS (PowerShell)
Open PowerShell as administrator and run:
```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest `
    -DomainName "zodu.com" `
    -DomainNetbiosName "ZODU" `
    -InstallDNS `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "1qazxsW@1" -AsPlainText -Force) `
    -ForestMode "Win2016" `
    -DomainMode "Win2016" `
    -Force
```
Then reboot the machine.

### CA Installation (GUI)
> [!IMPORTANT]
> Make sure to log on as Domain\Administrator
1. Check if the CA is joined to the AD machine, if not join it
2. Open Server Manager -> click Manage -> Add Roles and Features
3. Select the local server -> click Next
4. Under Server Roles, select Active Directory Certificate Services
	- Click Add Features when prompted
5. When installation finishes, click Configure Active Directory Certificate Services on the destination server
6. On Role Services, check Certification Authority (and optionally Certification Authority Web Enrollment)
7. On Setup Type, choose: Enterprise CA
8. On CA Type, choose Root CA (first CA in hierarchy)
9. On Private Key, choose: Create a new private key for a new CA
10. Choose cryptographic options (RSA 2048) -> Next
11. On CA Name, accept default (e.g., ZODU-CA) or customize
12. On CA Database, leave defaults or specify custom paths -> Next -> Configure
13. Verify the CA service is running: Open Server Manager -> Tools -> Certification Authority

### CA Installation (PowerShell)
> [!IMPORTANT]
> Make sure to log on as Domain\Administrator

Open PowerShell as administrator and run:
```powershell
Install-WindowsFeature AD-Certificate -IncludeManagementTools

Install-AdcsCertificationAuthority `
    -CAType EnterpriseRootCA `
    -CACommonName "ZODU for example" `
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -KeyLength 2048 `
    -HashAlgorithmName SHA256 `
    -ValidityPeriod Years `
    -ValidityPeriodUnits 10 `
    -Force
```

---

## Joining a Windows Machine to AD

Author: Ofir and Irakli

If your windows machine does not have a unique SID start by running sysprep and selecting generalize:
```
cd C:\Windows\System32\Sysprep
sysprep.exe
```

After the computer rebooted open:
Control Panel -> Network and Internet -> Network and Sharing Center -> Change adapter settings -> Right-click Ethernet -> Properties -> Select Internet Protocol Version 4 (TCP/IPv4) -> click Properties

- Set IP to match spreadsheet
- Changed Subnet mask to: 255.255.255.0
- Changed the Default gateway to: 10.0.1.1
- Changed Preferred DNS to match the IP of the AD machine: 10.0.1.10

Open "View advanced system settings" -> Click on Computer Name -> Change -> Add the machine as a member of the base url (e.g. "ad.zodu.com")

---

## Account & Password Group Policies

Authors: Ofir and Irakli

To follow CIS Benchmark and NIST 800-63B recommendations:

### Getting to Account Policies
1. Open **Group Policy Management**
2. Click on the arrow besides **Forest: \<your forest name\>** -> **Domains** -> **\<your forest name\>.com**
3. Right click **Default Domain Policy** -> **Edit**
4. Click on the arrow besides **Computer Configuration** -> **Windows Settings** -> **Security Settings** -> **Account Policies**

### Password Policy
- **Enforce password history** = 24 passwords remembered
- **Minimum password age** = 0
- **Minimum password length** = 14 characters

### Account Lockout Policy
- **Account lockout duration** = 15 minutes
- **Account lockout threshold** = 10 invalid logon attempts
- **Allow Administrator account lockout** = Enabled
- **Reset account lockout counter after** 15 minutes

---

## Split-Brain DNS with Multiple Domains

Authors: Ofir, Irakli, Seamus

### New Domain Setup
```powershell
Add-DnsServerPrimaryZone -Name "dev.zodu.com" -ReplicationScope "Domain" -DynamicUpdate "Secure"
```

Verify:
```powershell
Get-DnsServerZone -Name "dev.zodu.com"
```

### Setting up InternalScope and Client Subnet
```powershell
Add-DnsServerZoneScope -ZoneName "dev.zodu.com" -Name "InternalScope"
```

Limit access with subnets:
```powershell
Add-DnsServerClientSubnet -Name "<NAME>" -IPv4Subnet "10.0.x.0/24"
Add-DnsServerClientSubnet -Name "ExternalNetwork" -IPv4Subnet "0.0.0.0/0"
```

Block external, allow internal:
```powershell
Add-DnsServerQueryResolutionPolicy -Name "DenyExternalDevZone" -Action DENY -ClientSubnet "eq,ExternalNetwork" -ZoneName "dev.zodu.com"
Add-DnsServerQueryResolutionPolicy -Name "<NAME>" -Action ALLOW -ZoneScope "InternalScope" -ClientSubnet "eq,<SUBNET NAME>" -ZoneName "dev.zodu.com"
```

### Setting up DNS entries
```powershell
Add-DnsServerResourceRecordA -Name "@" -ZoneName "dev.zodu.com" -ZoneScope "InternalScope" -IPv4Address "10.0.1.10"
```

---

## AD Commands Reference

### Setup
```powershell
Import-Module ActiveDirectory
```

### User Management Commands

#### Create a New User
```powershell
New-ADUser -SamAccountName "jdoe" -UserPrincipalName "jdoe@domain.com" -Name "John Doe" -GivenName "John" -Surname "Doe" -DisplayName "John Doe" -Path "CN=Users,DC=domain,DC=com" -AccountPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -Enabled $true
```

#### Modify User Information
```powershell
Set-ADUser -Identity "jdoe" -Title "Manager"
```

#### Disable a User Account
```powershell
Disable-ADUser -Identity "jdoe"
```

#### Enable a User Account
```powershell
Enable-ADUser -Identity "jdoe"
```

#### Reset a User's Password
```powershell
Set-ADAccountPassword -Identity "jdoe" -NewPassword (ConvertTo-SecureString "NewP@ssw0rd" -AsPlainText -Force) -Reset
```

#### Unlock a User Account
```powershell
Unlock-ADAccount -Identity "jdoe"
```

### Group Management Commands

#### Create a New Group
```powershell
New-ADGroup -Name "HR_Group" -GroupCategory Security -GroupScope Global -Path "CN=Users,DC=domain,DC=com"
```

#### Add a User to a Group
```powershell
Add-ADGroupMember -Identity "HR_Group" -Members "jdoe"
```

#### Remove a User from a Group
```powershell
Remove-ADGroupMember -Identity "HR_Group" -Members "jdoe" -Confirm:$false
```

#### Get Group Members
```powershell
Get-ADGroupMember -Identity "HR_Group"
```

### Computer Management Commands

#### Create a New Computer Account
```powershell
New-ADComputer -Name "PC-01" -Path "CN=Computers,DC=domain,DC=com"
```

#### Rename a Computer Account
```powershell
Rename-ADObject -Identity "CN=PC-01,CN=Computers,DC=domain,DC=com" -NewName "PC-02"
```

#### Move a Computer Account
```powershell
Move-ADObject -Identity "CN=PC-01,OU=OldComputers,DC=domain,DC=com" -TargetPath "OU=NewComputers,DC=domain,DC=com"
```

### Organizational Units (OU) Management Commands

#### Create a New Organizational Unit
```powershell
New-ADOrganizationalUnit -Name "Sales" -Path "DC=domain,DC=com"
```

#### Move an Object to an Organizational Unit
```powershell
Move-ADObject -Identity "CN=John Doe,OU=Users,DC=domain,DC=com" -TargetPath "OU=Sales,DC=domain,DC=com"
```

### Querying and Reporting Commands

#### Get User Information
```powershell
Get-ADUser -Identity "jdoe" -Properties *
```

#### Search for Users by Attribute
```powershell
Get-ADUser -Filter {Surname -eq "Doe"} -Properties DisplayName, EmailAddress
```

#### Get All Active Directory Users
```powershell
Get-ADUser -Filter * -Properties DisplayName
```

#### Get Group Membership for a User
```powershell
Get-ADUser -Identity "jdoe" | Get-ADUserMembership
```

#### Get All Groups in AD
```powershell
Get-ADGroup -Filter * | Select-Object Name
```

#### Check Group Membership of a User
```powershell
Get-ADUser -Identity "jdoe" | Get-ADUserMembership | Where-Object { $_.Name -eq "HR_Group" }
```

### Active Directory Domain Services Commands

#### Get Domain Controllers
```powershell
Get-ADDomainController -Filter *
```

#### Get Forest Information
```powershell
Get-ADForest
```

### Replicating and Synchronizing AD
```powershell
Sync-ADObject -Object "CN=John Doe,OU=Users,DC=domain,DC=com" -SourceDC "DC1.domain.com" -TargetDC "DC2.domain.com"
```

### Active Directory Backup and Restore (DSSU)

#### Backup AD Database
```powershell
ntdsutil.exe "activate instance ntds" "ifm" "create full c:\ADBackup"
```

#### Restore AD Database
```powershell
ntdsutil.exe "activate instance ntds" "restore database c:\ADBackup"
```

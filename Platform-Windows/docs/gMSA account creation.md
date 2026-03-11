# gMSA Account Creation
## Creating a KDS Root Key (On DC)
### Check if a KDS root key already exists
```powershell
Get-KdsRootKey
```

> [!IMPORTANT]
> Do the following only if there is only 1 dc in your domain

### If no KDS root key exists, create one. Run the following command:
```powershell
Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))
```

## Creating a Security Group (On DC)
### Create a security group
```powershell
New-ADGroup -Name "<INSERT GROUP NAME HERE>" `
    -GroupScope DomainLocal `
    -Description "<INSERT DESC HERE>" `
    -PassThru
```
### Add computers that need access to the gMSA account to the group
```powershell
$adfsServer = Get-ADComputer -Identity "<YOUR-SERVER>"
Add-ADGroupMember -Identity "<INSERT GROUP NAME HERE>" -Members $adfsServer
```
### Verify the server was added
```powershell
Get-ADGroupMember -Identity "<INSERT GROUP NAME HERE>"
```

## Creating a gMSA Account (On DC)
### Create the gMSA account
```powershell
$group = Get-ADGroup "<INSERT GROUP NAME HERE>"

New-ADServiceAccount -Name "<INSERT gMSA ACC NAME HERE>" `
    -DNSHostName "<INSERT gMSA ACC NAME HERE>.$env:USERDNSDOMAIN" `
    -KerberosEncryptionType AES256 `
    -PrincipalsAllowedToRetrieveManagedPassword $group `
    -Enabled $true
```


### The encryption type should show 16 or 24.
```powershell
Get-ADServiceAccount -Identity <INSERT gMSA ACC NAME HERE> -Properties * | 
    Select-Object Name, Enabled, 
        @{Name="EncryptionType";Expression={$_.'msDS-SupportedEncryptionTypes'}},
        @{Name="AllowedPrincipals";Expression={$_.PrincipalsAllowedToRetrieveManagedPassword}}
```
### If the encryption value shows 28
```powershell
Set-ADServiceAccount -Identity <INSERT gMSA ACC NAME HERE> -KerberosEncryptionType AES256
```

## Attaching an SPN to the gMSA Account (On DC)
### Attach an SPN to the gMSA account
```powershell
setspn -s host/<example.domain.com> <domain.com>\<INSERT gMSA ACC NAME HERE>$
```
### Verify the SPN was added successfully
```powershell
setspn -L <domain.com>\<INSERT gMSA ACC NAME HERE>$
```

## Installing the gMSA Account on Other Machines

### First kill kerberos tickets and restart the machine.
```powershell
klist purge
Restart-Computer
```

### Install the gMSA account
```powershell
Install-WindowsFeature RSAT-AD-PowerShell
Import-Module ActiveDirectory
Install-ADServiceAccount -Identity <INSERT gMSA ACC NAME HERE>
Test-ADServiceAccount -Identity <INSERT gMSA ACC NAME HERE>
```
### If you encounter an access deny error you cannot fix use the following command on your DC
```powershell
$computer = Get-ADComputer "<SERVER NAME>"
Set-ADServiceAccount -Identity <INSERT gMSA ACC NAME HERE> -PrincipalsAllowedToRetrieveManagedPassword $computer
```
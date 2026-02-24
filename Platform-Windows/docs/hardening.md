# Windows Hardening

- [Access Hardening](#access-hardening)
  - [WinRM](#winrm)
  - [SSH](#ssh)
  - [RDP](#rdp)
  - [Other](#other)
- [DNS Hardening](#dns-hardening)
- [Kerberos](#kerberos)

---

## Access Hardening

There are three built-in ways the attacker can access the machine:
1. WinRM
2. SSH
3. RDP

> [!WARNING]
> Two important notes:
> 1. Disabling an account does **not** kick active sessions
> 2. Windows has accounts in many places: local accounts, AD users, other AD objects, and hidden system accounts (e.g. krbtgt). Look into `suborner` attacks for hidden account creation.

### WinRM
WinRM is a remote management session used for scripting tools like Ansible. Disable when not needed:
```powershell
Stop-Service -Name WinRM
Set-Service -Name WinRM -StartupType Disabled
```

### SSH
SSH can be installed via Server Manager. Uninstall if not needed.

Kick all SSH sessions:
```powershell
$sshSessions = Get-Process | Where-Object { $_.Name -eq 'sshd' -or $_.Name -eq 'ssh' }
foreach ($session in $sshSessions) {
    Stop-Process -Id $session.Id -Force
    Write-Output "SSH session terminated: $($session.Id)"
}
```

### RDP
Configure RDP access as needed. See `scripts/enableRDP.ps1` for enabling RDP.

### Other
In the past, the red team has installed an OpenSSH Server not through Server Manager.

---

## DNS Hardening

Reset your hosts file to default and erase any entries that were there before (red team may have poisoned DNS entries to redirect downloads to malware):

```powershell
$DocumentsPath = [System.Environment]::GetFolderPath("MyDocuments")
$HostsFilePath = "C:\Windows\System32\drivers\etc\hosts"
$BackupPath = Join-Path -Path $DocumentsPath -ChildPath "hosts_backup.txt"

# Backup current hosts file
Copy-Item -Path $HostsFilePath -Destination $BackupPath -Force

# Reset to default
$defaultHostsContent = @"
127.0.0.1       localhost
::1             localhost
"@
Set-Content -Path $HostsFilePath -Value $defaultHostsContent -Force
```

---

## Kerberos

Golden Tickets and Silver Tickets can be invalidated by changing the password of the `krbtgt` user.

To view the `krbtgt` user, go to **View** -> **Advanced Features** in the AD Users and Computers menu.

Reset krbtgt password (run twice):
```powershell
Get-ADUser krbtgt | Set-ADAccountPassword -Reset -NewPassword (ConvertTo-SecureString (([char[]]([char]33..[char]122) | Get-Random -Count 32) -join '') -AsPlainText -Force)
```

> [!NOTE]
> Reset twice because AD keeps current + previous hash. May briefly break Kerberos auth.

Reference: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/forest-recovery-guide/ad-forest-recovery-reset-the-krbtgt-password

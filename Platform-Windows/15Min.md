# Windows First 15 Minutes - CCDC 2026

## Step 1: Immediate Actions (Run on Each Windows Host)

### Install Firefox
```powershell
$firefoxInstallerUrl = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
$installerPath = "$env:TEMP\firefox_installer.exe"
Invoke-WebRequest -Uri $firefoxInstallerUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -Args "/S" -Wait
Remove-Item -Path $installerPath
```
### Reset Hosts File 
```powershell
$DocumentsPath = [System.Environment]::GetFolderPath("MyDocuments")
$HostsFilePath = "C:\Windows\System32\drivers\etc\hosts"
$BackupPath = Join-Path -Path $DocumentsPath -ChildPath "hosts_backup.txt"
Copy-Item -Path $HostsFilePath -Destination $BackupPath -Force
$defaultHostsContent = @"
127.0.0.1       localhost
::1             localhost
"@
Set-Content -Path $HostsFilePath -Value $defaultHostsContent -Force
```
### Install Sysinternals
```powershell
$url = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
$destination = "$env:USERPROFILE\Downloads\SysinternalsSuite.zip"
$extractPath = "C:\Sysinternals"
$importantToolsPath = "C:\Important-Sysinternals"

$importantTools = @(
    'procexp64.exe', 
    'Procmon64.exe', 
    'Autoruns64.exe', 
    'PsLoggedOn.exe', 
    'LogonSessions.exe', 
    'AccessChk.exe', 
    'VMMap.exe', 
    'Sigcheck.exe', 
    'Tcpview.exe', 
    'PsService.exe',
    'Sysmon64.exe'
)

Invoke-WebRequest -Uri $url -OutFile $destination

if (-not (Test-Path $extractPath)) {
    New-Item -Path $extractPath -ItemType Directory
}

Expand-Archive -Path $destination -DestinationPath $extractPath -Force

if (-not (Test-Path $importantToolsPath)) {
    New-Item -Path $importantToolsPath -ItemType Directory
}

foreach ($tool in $importantTools) {
    $currentToolPath = Join-Path $extractPath $tool
    if (Test-Path $currentToolPath) {
        Copy-Item -Path $currentToolPath -Destination $importantToolsPath -Force
    }
}

Write-Output "Files processed to C: root folders."
```

### Get and Disable Local Accounts
```powershell
Get-LocalUser
```
```powershell
net user <USERNAME> /active:no
```

### Get and Disable AD Accounts
```powershell
Get-ADUser -Filter *
```
```powershell
Disable-ADAccount -Identity <USERNAME>
```

### Reset Passwords Local Accounts
```powershell
net user <USERNAME> *
```

### Reset Passwords AD Accounts
```powershell
Set-ADAccountPassword -Identity <USERNAME> -Reset
```

### Reset krbtgt twice (DC only)
https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/forest-recovery-guide/ad-forest-recovery-reset-the-krbtgt-password

### Kick all RDP Sessions
```powershell
qwinsta | ForEach-Object {
    $line = $_.Trim()
    if ($line -match "rdp-tcp" -or ($line -match "Disc" -and $line -notmatch "services|console")) {
        if ($_ -match "\s+(\d+)\s+") {
            $sessionId = $matches[1]
            logoff $sessionId
        }
    }
}
```

### Kick SSH Sessions
```powershell
   $sshSessions = Get-Process | Where-Object { $_.Name -eq 'sshd' -or $_.Name -eq 'ssh' }

    foreach ($session in $sshSessions) {
        Stop-Process -Id $session.Id -Force
        Write-Output "SSH session terminated: $($session.Id)"
    }
```

### Launch procexp64.exe, Autoruns64.exe, Tcpview.exe

### Run sysmon
```powershell
.\Sysmon64.exe -i -n -accepteula
```

### Install nmap
```powershell
$nmapUrl = "https://nmap.org/dist/nmap-7.93-setup.exe"
$installerPath = "$env:USERPROFILE\Downloads\nmap-setup.exe"

Invoke-WebRequest -Uri $nmapUrl -OutFile $installerPath
$installArguments = '/forceinstall /NpcapInstallMode=1'

Start-Process -FilePath $installerPath -ArgumentList $installArguments -Wait

Remove-Item -Path $installerPath -Force

Write-Host "Nmap installation completed!"
```

### Install Wireshark
```powershell
$installerUrl = "https://2.na.dl.wireshark.org/win64/Wireshark-4.6.2-x64.exe"
$installerPath = "wireshark.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait

Remove-Item -Path $installerPath
```

### Enable Firewall Rules
```powershell

Set-NetFirewallProfile -All -Enabled True

$IsAdmin = [bool]([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "This script must be run as Administrator. Please re-run the script with elevated privileges."
    exit
}

Write-Host "Enabling Remote Desktop Firewall rule..."
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

Write-Host "Enabling File and Printer Sharing Firewall rules..."
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"

Write-Host "Enabling ICMP Echo Requests (Ping)..."
Enable-NetFirewallRule -DisplayGroup "Windows Defender Firewall Remote Management"

Write-Host "Enabling Windows Defender inbound rules..."
Enable-NetFirewallRule -DisplayGroup "Windows Defender Firewall"

Write-Host "Enabling RDP port (3389) manually..."
New-NetFirewallRule -Name "Allow RDP" -DisplayName "Allow RDP" -Enabled True -Protocol TCP -LocalPort 3389 -Action Allow -Direction Inbound

Write-Host "Firewall rules have been successfully enabled. You should now be able to access the machine via RDP and other network services."

Get-NetFirewallProfile
```

### Remove Bad GPOs (DC only) | Open `gpmc.msc`, delete suspicious GPOs

### Reset GPOs to Default (DC only)
```powershell
dcgpofix /target:both
```
### Force GPO Update
```powershell
gpupdate /force
```

### Run sigcheck
```powershell
.\sigcheck.exe -i "C:\\
```

### Enable ICMPv4
```powershell
function Enable-ICMP {
    param (
        [bool]$Enable = $true
    )

    $fw = New-Object -ComObject HNetCfg.FwPolicy2
    $icmpRules = $fw.Rules | Where-Object { $_.Name -like "File and Printer Sharing (Echo*" }

    foreach ($rule in $icmpRules) {
        $rule.Enabled = $Enable
    }
}

Enable-ICMP -Enable $true
```

### Enable ansible
https://github.com/NE-Collegiate-Cyber-Defense-League/neccdc-2024-public/blob/main/ansible/regionals/pre/windows/core/packer/scripts/ansible.ps1

### Install chainsaw
```powershell
$url = "https://github.com/WithSecureLabs/chainsaw/releases/latest/download/chainsaw_all_platforms+rules.zip"

$zipPath = "$env:USERPROFILE\Downloads\chainsaw_package.zip"
$tempExtractPath = "$env:USERPROFILE\Downloads\chainsaw_temp"
$destinationPath = "C:\Chainsaw"

Write-Host "Downloading Chainsaw..."
Invoke-WebRequest -Uri $url -OutFile $zipPath

Write-Host "Preparing folders..."
Remove-Item $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
New-Item $tempExtractPath -ItemType Directory | Out-Null

Write-Host "Extracting package..."
Expand-Archive -Path $zipPath -DestinationPath $tempExtractPath -Force

if (-not (Test-Path $destinationPath)) {
    New-Item $destinationPath -ItemType Directory | Out-Null
}

Write-Host "Locating Windows executable..."
$exeFile = Get-ChildItem $tempExtractPath -Recurse -Filter "chainsaw_x86_64-pc-windows-msvc.exe" |
    Select-Object -First 1

if (-not $exeFile) {
    throw "Windows executable not found!"
}

Write-Host "Installing executable..."
Copy-Item $exeFile.FullName "$destinationPath\chainsaw.exe" -Force

Write-Host "Copying rules..."
$rules = Get-ChildItem $tempExtractPath -Recurse -Directory -Filter "rules" |
    Select-Object -First 1
if ($rules) {
    Copy-Item $rules.FullName $destinationPath -Recurse -Force
}

Write-Host "Copying mappings..."
$mappings = Get-ChildItem $tempExtractPath -Recurse -Directory -Filter "mappings" |
    Select-Object -First 1
if ($mappings) {
    Copy-Item $mappings.FullName $destinationPath -Recurse -Force
}

Write-Host "Cleaning up..."
Remove-Item $zipPath -Force
Remove-Item $tempExtractPath -Recurse -Force

Write-Host "`nInstallation complete!"
Get-ChildItem $destinationPath

```

### Commands Not in Other Files:
| Task | Copy Command From |
|------|-------------------|
| Disable LLMNR | `gpedit.msc -> Computer Configuration -> Administrative Templates -> Network -> DNS Client -> Turn off multicast name resolution -> Enable` |
| Disable NBT-NS | `Control Panel > Network and Sharing Center > Change adapter settings -> Properties -> Internet Protocol Version 4 (TCP/IPv4) Properties -> Advanced -> WINS -> Disable NetBIOS over TCP/IP`|
| Enable Windows Defender | https://learn.microsoft.com/en-us/powershell/module/defender/set-mppreference |
| SMB Signing | `gpedit.msc -> Computer Configuration -> Policies -> Windows Settings -> Security Settings -> Local Policies -> Security Options.Microsoft network client: Digitally sign communications (always) — Set to Enabled. Microsoft network server: Digitally sign communications (always) — Set to Enabled.` |
| Disable SMB1 | `Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart` |
| Disable Services | `gsv RemoteRegistry,TlntSvr,SNMP -ea 0 \| spsv -f -pas \| Set-Service -st Disabled` |

---

## Step 2: Threat Detection

Run on each Windows machine from `Platform-Windows\`:

| Task | Script |
|------|--------|
| Kill Malware | `Nat-Win\KillKnownMalwareProceses.ps1` |
| Dump AD Config (DC only) | `0-Scripts\Dumping\ADDump.md` |
| Dump DNS Records (DC only) | `0-Scripts\Dumping\DNSDump.md` (**requires DNS server on same machine**) |
| Hidden Files | `Nat-Win\SearchPotentialMaliciousFiles.ps1` |
| Recent Events | `Nat-Win\RecentEventLogEntries.ps1` |
| File Watcher | `Nat-Win\CreateFileWatcher.ps1` |
| Run Autoruns | `Autoruns64.exe` from Sysinternals folder |

---

# Post-15 Minutes

## Step 3.1 Reenable accounts
### Remove accoubts premissions and groups.
### Reenable Local and AD user accounts.

## Step 3.2 Disable programs you didnt install such as browsers, chocolatey, WSL, etc.

## Step 3.3: Ansible Setup (On Ubuntu Control Node)

### 3.4 Install Ansible
```bash
sudo apt update && sudo apt install python3-pip -y
python3 -m pip install --user ansible pywinrm
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

### 3.5 Navigate to Playbook Directory
```bash
cd /path/to/ccdc2026/Platform-Windows/1-Ansible/playbook
```

### 3.6 Edit Inventory
```bash
nano inventory/inventory.ini
```

Add your Windows machines:
```ini
[windows]
<IP> ansible_user=Administrator ansible_password=<PASSWORD>

[windows:vars]
ansible_connection=winrm
ansible_port=5985
ansible_winrm_transport=ntlm
ansible_winrm_server_cert_validation=ignore
```

### 3.7 Test Connection
```bash
ansible windows -i inventory/inventory.ini -m win_ping
```

### 3.8 Run Playbook
```bash
nano playbook.yml
```

Add roles:
```yaml
roles:
  - check-alive          # SAFE
  - create-team-accounts # SAFE
  - find-DC              # SAFE
  - install-chocolatey   # SAFE
  - list-process         # SAFE 
  - sysinternal          # SAFE
  - kill ssh             # SAFE 
  - rotate-user-creds    # RISKY - do manually for qualifiers
```

```bash
ansible-playbook -i inventory/inventory.ini playbook.yml
```

---

## Step 4: Log Analysis

### Option A: Simple PowerShell (Recommended for Qualifiers)
```powershell
# Recent security events
.\Nat-Win\RecentEventLogEntries.ps1

# Failed logons (Event 4625)
.\Nat-Win\SearchEventViewerID.ps1
```

### Option B: LogonTracer (Regionals)
```bash
cd Platform-Windows/1-Ansible/playbook/logontracer
nano inventory/hosts.ini
ansible-playbook -i inventory/hosts.ini setup/full_setup.yml
```

---

## Ansible Roles Summary

| Role | What It Does | Risk |
|------|--------------|------|
| `sysinternal` | Install Firefox, Nmap, Wireshark, Sysinternals | SAFE |
| `kill ssh` | Kill SSH, uninstall OpenSSH, block ports 22/2222 | SAFE |
| `list-process` | List running processes, save to JSON | SAFE |
| `create-team-accounts` | Create blueteam + SirTempleton users | SAFE |
| `rotate-user-creds` | Rotate local passwords, export CSV | RISKY |
| `rotate-domain-acc` | Rotate domain passwords | RISKY |
| `Install-win2ban` | Install IPBan intrusion prevention | MODERATE |

---

## Manual Scripts Reference

| Script | Path |
|--------|------|
| Kill Malware | `Nat-Win\KillKnownMalwareProceses.ps1` |
| Export Tasks | `0-Scripts\Dumping\exportScheduled.ps1` |
| List Connections | `Nat-Win\ListTCPConnections.ps1` |
| Recent Processes | `Nat-Win\AllProcessesCreatedLast10min.ps1` |
| Hidden Files | `Nat-Win\SearchPotentialMaliciousFiles.ps1` |
| Recent Events | `Nat-Win\RecentEventLogEntries.ps1` |
| Local Pass Rotate | `Nat-Win\LocalPassRotation.ps1` |
| Domain Pass Rotate | `Nat-Win\RotateDomainPass.ps1` |
| File Watcher | `Nat-Win\CreateFileWatcher.ps1` |
| Block IP | `Nat-Win\BlockOutboundIP.ps1` |
| OU Permissions | `Nat-Win\GetOUPermissions.ps1` (DC only) |
| Search Event ID | `Nat-Win\SearchEventViewerID.ps1` |

All paths relative to `Platform-Windows\`

---

## Important Event IDs

| ID | Meaning |
|----|---------|
| 4624 | Successful logon |
| 4625 | Failed logon |
| 4720 | Account created |
| 4722 | Account enabled |
| 4725 | Account deleted |
| 4698 | Scheduled task created |
| 4699 | Scheduled task deleted |
| 4768 | TGT requested (kerberoast/golden ticket) |
| 4724 | Password reset |
| 4946 | Firewall rule added |

---

## SOC Tools (If Requested)

| Tool | Script |
|------|--------|
| Wazuh Agent | `Service-SOC\Wazuh\0-Scripts\WIN_agent_install.ps1` (edit IP first) |
| Graylog Sidecar | `Service-SOC\Graylog\0-Scripts\WIN - (Sidecar) winlogbeat.ps1` |

---

## Warnings

> **Disabling an account does NOT kick active sessions.** You must also logoff/terminate existing sessions.

---
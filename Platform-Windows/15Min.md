# Windows First 15 Minutes - CCDC 2026

> [!CAUTION]
> **Time-critical.** Run Step 1 on every Windows host immediately. DC-only steps are marked.

---

## Step 1: Immediate Actions (Run on Each Windows Host)

> [!TIP]
> **Setup & Tools** — Get your environment ready

### 1. Reset Hosts File
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

### 2. Install Firefox
```powershell
$firefoxInstallerUrl = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
$installerPath = "$env:TEMP\firefox_installer.exe"
Invoke-WebRequest -Uri $firefoxInstallerUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -Args "/S" -Wait
Remove-Item -Path $installerPath
```

### 3. Install Sysinternals
<details>
<summary>Downloads suite, extracts important tools to C:\Important-Sysinternals</summary>

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
</details>

---

> [!CAUTION]
> **Lock Down Accounts** — Highest priority security actions

### 4. Disable & Reset Accounts

**Local accounts:**
```powershell
Get-LocalUser
```
```powershell
net user <USERNAME> /active:no
```
```powershell
net user <USERNAME> *
```

**AD accounts:**
```powershell
Get-ADUser -Filter *
```
```powershell
Disable-ADAccount -Identity <USERNAME>
```
```powershell
Set-ADAccountPassword -Identity <USERNAME> -Reset
```

**Reset krbtgt twice (DC only)** — kills Golden Tickets. Reset twice because AD keeps current + previous hash.
```powershell
Get-ADUser krbtgt | Set-ADAccountPassword -Reset -NewPassword (ConvertTo-SecureString (([char[]]([char]33..[char]122) | Get-Random -Count 32) -join '') -AsPlainText -Force)
```
Run the above command **twice** back-to-back. May briefly break Kerberos auth.

### 5. Kick Active Sessions

> [!WARNING]
> **Disabling an account does NOT kick active sessions.** You must also logoff/terminate existing sessions.

**Kick all RDP sessions:**
```powershell
qwinsta | ForEach-Object { if ($_ -match "\s+(\d+)\s+" -and ($_ -match "rdp-tcp|Disc")) { logoff $matches[1] } }
```

**Kick SSH sessions:**
```powershell
Get-Process | Where-Object { $_.Name -eq 'sshd' -or $_.Name -eq 'ssh' } | Stop-Process -Force
```

---

> [!TIP]
> **Monitoring & Detection** — Get visibility before hardening

### 6. Launch Sysinternals Tools (as admin)
- `procexp64.exe` — process explorer
- `Autoruns64.exe` — startup/persistence items
- `Tcpview.exe` — live network connections

### 7. Run Sysmon
```powershell
.\Sysmon64.exe -i -n -accepteula
```

### 8. Run Sigcheck
```powershell
.\sigcheck.exe -i "C:\\
```

---

> [!NOTE]
> **Network & Tools** — Install remaining tools, configure firewall

### 9. Install Nmap
```powershell
$nmapUrl = "https://nmap.org/dist/nmap-7.93-setup.exe"
$installerPath = "$env:USERPROFILE\Downloads\nmap-setup.exe"
Invoke-WebRequest -Uri $nmapUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -ArgumentList '/forceinstall /NpcapInstallMode=1' -Wait
Remove-Item -Path $installerPath -Force
```

### 10. Install Wireshark
```powershell
$installerUrl = "https://2.na.dl.wireshark.org/win64/Wireshark-4.6.2-x64.exe"
$installerPath = "wireshark.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
Remove-Item -Path $installerPath
```

### 11. Enable Firewall
```powershell
Set-NetFirewallProfile -All -Enabled True
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
New-NetFirewallRule -Name "Allow RDP" -DisplayName "Allow RDP" -Enabled True -Protocol TCP -LocalPort 3389 -Action Allow -Direction Inbound
```

<details>
<summary>Full firewall script (with ICMP, admin check, status output)</summary>

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

Write-Host "Firewall rules have been successfully enabled."
Get-NetFirewallProfile
```

**Enable ICMPv4:**
```powershell
$fw = New-Object -ComObject HNetCfg.FwPolicy2
$fw.Rules | Where-Object { $_.Name -like "File and Printer Sharing (Echo*" } | ForEach-Object { $_.Enabled = $true }
```
</details>

---

> [!IMPORTANT]
> **Domain Hardening** — DC-only steps that protect the whole domain

### 12. Run Harden-GPO.ps1 (DC only)
Resets GPOs, then hardens domain-wide: audit logging, password policy, SMB signing, disable SMB1, LLMNR, NBT-NS, WPAD, credential protection, and more.
```powershell
# Safe mode (recommended for qualifiers — won't break services)
powershell -ExecutionPolicy Bypass -File scripts\Harden-GPO.ps1 -S
```
```powershell
# Full hardening (more aggressive — can break WinRM by IP, RC4 services)
powershell -ExecutionPolicy Bypass -File scripts\Harden-GPO.ps1 -SkipReset
```

<details>
<summary>Manual alternatives (if script fails or for non-DC machines)</summary>

#### Remove Bad GPOs (DC only)
Open `gpmc.msc`, delete suspicious GPOs

#### Reset GPOs to Default (DC only)
```powershell
dcgpofix /target:both
```
#### Force GPO Update
```powershell
gpupdate /force
```
#### Disable LLMNR
`gpedit.msc -> Computer Configuration -> Administrative Templates -> Network -> DNS Client -> Turn off multicast name resolution -> Enable`

#### Disable NBT-NS
`Control Panel > Network and Sharing Center > Change adapter settings -> Properties -> Internet Protocol Version 4 (TCP/IPv4) Properties -> Advanced -> WINS -> Disable NetBIOS over TCP/IP`

#### SMB Signing
`gpedit.msc -> Computer Configuration -> Policies -> Windows Settings -> Security Settings -> Local Policies -> Security Options -> Microsoft network client: Digitally sign communications (always) = Enabled. Microsoft network server: Digitally sign communications (always) = Enabled.`

#### Disable SMB1
```powershell
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
```

#### Disable Services
```powershell
gsv RemoteRegistry,TlntSvr,SNMP -ea 0 | spsv -f -pas | Set-Service -st Disabled
```
</details>

---

> [!WARNING]
> **Defense** — Re-enable protections red team may have disabled

### 13. Enable Windows Defender
<details>
<summary>Remove red team blocks, re-enable, clear exclusions, update & scan</summary>

```powershell
# Remove registry keys that red team uses to disable Defender
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableBehaviorMonitoring" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableOnAccessProtection" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableScanOnRealtimeEnable" -ErrorAction SilentlyContinue

# Re-enable the Defender service if it was disabled
Set-Service -Name WinDefend -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name WinDefend -ErrorAction SilentlyContinue

# Remove any exclusions red team may have added (exclude nothing)
$prefs = Get-MpPreference
$prefs.ExclusionPath | ForEach-Object { Remove-MpPreference -ExclusionPath $_ -ErrorAction SilentlyContinue }
$prefs.ExclusionProcess | ForEach-Object { Remove-MpPreference -ExclusionProcess $_ -ErrorAction SilentlyContinue }
$prefs.ExclusionExtension | ForEach-Object { Remove-MpPreference -ExclusionExtension $_ -ErrorAction SilentlyContinue }

# Enable real-time protection
Set-MpPreference -DisableRealtimeMonitoring $false

# Enable cloud-delivered protection
Set-MpPreference -MAPSReporting Advanced

# Enable automatic sample submission
Set-MpPreference -SubmitSamplesConsent SendAllSamples

# Enable behavior monitoring
Set-MpPreference -DisableBehaviorMonitoring $false

# Enable scanning of network files
Set-MpPreference -DisableScanningNetworkFiles $false

# Enable PUA (potentially unwanted application) detection
Set-MpPreference -PUAProtection Enabled

# Update signatures and run a quick scan
Update-MpSignature
Start-MpScan -ScanType QuickScan
```

> [!NOTE]
> If Defender still won't start, check: `Get-MpComputerStatus` — if `AMServiceEnabled` is false, the binary may have been deleted or Tamper Protection is blocking changes via GPO. Try `gpmc.msc` to remove any GPO disabling Defender.

</details>

---

> [!NOTE]
> **Prep for Automation** — Set up for Ansible and log analysis

### 14. Enable WinRM for Ansible (run on each Windows machine)
Configures WinRM, creates SSL cert, opens firewall — required before Ansible can connect.
```powershell
powershell -ExecutionPolicy Bypass -File scripts\Enable-WinRM.ps1
```

### 15. Install Chainsaw
<details>
<summary>Download, extract, install to C:\Chainsaw</summary>

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
</details>

---

## Step 2: Threat Detection

> [!CAUTION]
> Run on each Windows machine from `Platform-Windows\`

| Task | Script |
|------|--------|
| Kill Malware | `scripts\KillKnownMalwareProceses.ps1` |
| Run All Detection | `scripts\IncidentResponse.ps1` |
| Dump AD Config (DC only) | See `docs\networking.md` (AD Dump section) |
| Dump DNS Records (DC only) | See `docs\networking.md` (DNS Dump section) |
| Hidden Files | `scripts\IncidentResponse.ps1 -Function Find-HiddenExecutables` |
| Recent Events | `scripts\IncidentResponse.ps1 -Function Get-RecentSecurityEvents` |
| File Watcher | `scripts\CreateFileWatcher.ps1` |
| Run Autoruns | `Autoruns64.exe` from Sysinternals folder |

---

# Post-15 Minutes

> [!TIP]
> **Recover & Automate** — Re-enable accounts, set up Ansible, start log analysis

## Step 3.1 Re-enable accounts
### Remove account permissions and groups.
### Re-enable Local and AD user accounts.

## Step 3.2 Disable programs you didn't install such as browsers, chocolatey, WSL, etc.

## Step 3.3: Ansible Setup (On Ubuntu Control Node)

<details>
<summary>Install Ansible</summary>

```bash
sudo apt update && sudo apt install python3-pip -y
python3 -m pip install --user ansible pywinrm
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```
</details>

<details>
<summary>Configure inventory & run playbook</summary>

```bash
cd /path/to/ccdc2026/Platform-Windows/ansible
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

Test connection:
```bash
ansible windows -i inventory/inventory.ini -m win_ping
```

Run playbook:
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
</details>

---

## Step 4: Log Analysis

<details>
<summary>Option A: Simple PowerShell (Recommended for Qualifiers)</summary>

```powershell
# Run all detection (recent events, failed logons, hidden files, connections, recent processes)
.\scripts\IncidentResponse.ps1

# Or run individually:
.\scripts\IncidentResponse.ps1 -Function Get-RecentSecurityEvents
.\scripts\IncidentResponse.ps1 -Function Search-FailedLogons
```
</details>

<details>
<summary>Option B: LogonTracer (Regionals)</summary>

```bash
cd Platform-Windows/ansible/logontracer
nano inventory/hosts.ini
ansible-playbook -i inventory/hosts.ini setup/full_setup.yml
```
</details>

---

## Reference

<details>
<summary>Ansible Roles Summary</summary>

| Role | What It Does | Risk |
|------|--------------|------|
| `sysinternal` | Install Firefox, Nmap, Wireshark, Sysinternals | SAFE |
| `kill ssh` | Kill SSH, uninstall OpenSSH, block ports 22/2222 | SAFE |
| `list-process` | List running processes, save to JSON | SAFE |
| `create-team-accounts` | Create blueteam + SirTempleton users | SAFE |
| `rotate-user-creds` | Rotate local passwords, export CSV | RISKY |
| `rotate-domain-acc` | Rotate domain passwords | RISKY |
| `Install-win2ban` | Install IPBan intrusion prevention | MODERATE |
</details>

<details>
<summary>Manual Scripts Reference</summary>

| Script | Path |
|--------|------|
| Kill Malware | `scripts\KillKnownMalwareProceses.ps1` |
| Export Tasks | `scripts\exportScheduled.ps1` |
| Incident Response | `scripts\IncidentResponse.ps1` (runs all detection) |
| Local Pass Rotate | `scripts\LocalPassRotation.ps1` |
| Domain Pass Rotate | `scripts\RotateDomainPass.ps1` |
| File Watcher | `scripts\CreateFileWatcher.ps1` |
| OU Permissions | `scripts\GetOUPermissions.ps1` (DC only) |
| Enable RDP | `scripts\enableRDP.ps1` |
| Harden GPO | `scripts\Harden-GPO.ps1` (DC only) |
| Enable WinRM | `scripts\Enable-WinRM.ps1` |
| AD Installer | `scripts\AD_Installer.ps1` |
| CA Installer | `scripts\CA_Enterprise_Installer.ps1` |

All paths relative to `Platform-Windows\`
</details>

<details>
<summary>Important Event IDs</summary>

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
</details>

<details>
<summary>SOC Tools (If Requested)</summary>

| Tool | Script |
|------|--------|
| Wazuh Agent | `Service-SOC\Wazuh\0-Scripts\WIN_agent_install.ps1` (edit IP first) |
| Graylog Sidecar | `Service-SOC\Graylog\0-Scripts\WIN - (Sidecar) winlogbeat.ps1` |
</details>

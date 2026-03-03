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
<summary>Downloads suite to C:\Sysinternals, accepts EULAs</summary>

```powershell
$url = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
$zip = "$env:TEMP\SysinternalsSuite.zip"
$temp = "$env:TEMP\SysinternalsExtract"
$dest = "C:\Sysinternals"

$keep = @(
    'procexp64.exe', 'Procmon64.exe', 'Autoruns64.exe', 'autorunsc64.exe',
    'Tcpview.exe', 'Sysmon64.exe', 'Sigcheck64.exe',
    'PsLoggedOn.exe', 'PsService.exe', 'AccessChk64.exe',
    'handle64.exe', 'listdlls64.exe', 'strings64.exe'
)

Invoke-WebRequest -Uri $url -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $temp -Force
New-Item $dest -ItemType Directory -ErrorAction SilentlyContinue
foreach ($tool in $keep) {
    $src = Join-Path $temp $tool
    if (Test-Path $src) { Copy-Item $src $dest -Force }
}
Remove-Item $zip, $temp -Recurse -Force

# Accept all Sysinternals EULAs so tools don't pop a dialog on first run
reg add "HKCU\Software\Sysinternals" /v EulaAccepted /t REG_DWORD /d 1 /f | Out-Null

# Set all .exe files to always run as admin
Get-ChildItem "$dest\*.exe" | ForEach-Object {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" `
        -Name $_.FullName -Value "~ RUNASADMIN" -ErrorAction SilentlyContinue
}

# Install Sysmon with config
@'
<Sysmon schemaversion="4.50">
  <EventFiltering>
    <ProcessCreate onmatch="exclude" />
    <NetworkConnect onmatch="exclude" />
    <FileCreate onmatch="include">
      <TargetFilename condition="end with">.exe</TargetFilename>
      <TargetFilename condition="end with">.dll</TargetFilename>
      <TargetFilename condition="end with">.sys</TargetFilename>
      <TargetFilename condition="end with">.scr</TargetFilename>
      <TargetFilename condition="end with">.ps1</TargetFilename>
      <TargetFilename condition="end with">.bat</TargetFilename>
      <TargetFilename condition="end with">.cmd</TargetFilename>
      <TargetFilename condition="end with">.vbs</TargetFilename>
      <TargetFilename condition="end with">.js</TargetFilename>
      <TargetFilename condition="end with">.wsf</TargetFilename>
      <TargetFilename condition="end with">.hta</TargetFilename>
      <TargetFilename condition="end with">.msi</TargetFilename>
    </FileCreate>
  </EventFiltering>
</Sysmon>
'@ | Out-File "$env:TEMP\sc.xml" -Encoding UTF8
Start-Process -FilePath "$dest\Sysmon64.exe" -ArgumentList "-i `"$env:TEMP\sc.xml`" -accepteula" -Wait -NoNewWindow

# Launch the tools you actually need open during competition
Start-Process "$dest\procexp64.exe"   # process explorer
Start-Process "$dest\Autoruns64.exe"  # startup/persistence items
Start-Process "$dest\Tcpview.exe"     # live network connections

Write-Host "[+] Sysinternals installed to $dest — Sysmon running, tools launched" -ForegroundColor Green
```
</details>

<details>
<summary>Manual Sysmon / legacy full Sysinternals install</summary>

```powershell
# Sysmon: check status
sc query Sysmon64
# Sysmon: update config (re-run the install script's XML block first)
C:\Sysinternals\Sysmon64.exe -c "$env:TEMP\sc.xml"
# Sysmon: uninstall
C:\Sysinternals\Sysmon64.exe -u
```
```powershell
# Legacy: download full suite (all tools, no filtering)
Invoke-WebRequest "https://download.sysinternals.com/files/SysinternalsSuite.zip" -OutFile "$env:TEMP\ss.zip"
Expand-Archive "$env:TEMP\ss.zip" -DestinationPath "C:\Sysinternals" -Force
Remove-Item "$env:TEMP\ss.zip"
reg add "HKCU\Software\Sysinternals" /v EulaAccepted /t REG_DWORD /d 1 /f
```
</details>

---

> [!CAUTION]
> **Lock Down Accounts** — Highest priority security actions

### 4. Disable & Reset Accounts

**Local accounts:**
<details>
<summary>List all local users with group memberships</summary>

```powershell
Get-LocalUser | Select-Object Name, Enabled, LastLogon, @{N='Groups';E={
    $user = $_.Name
    $g = @()
    Get-LocalGroup | ForEach-Object {
        if ((Get-LocalGroupMember $_ -ErrorAction SilentlyContinue).Name -like "*\$user") { $g += $_.Name }
    }
    $g -join ', '
}} | Format-Table -AutoSize
```
</details>
**Disable:**
```powershell
"Guest","Administrator" | ForEach-Object { Disable-LocalUser -Name $_; Write-Host "  Disabled: $_" -ForegroundColor Yellow }
```
**Re-enable:**
```powershell
"Guest","Administrator" | ForEach-Object { Enable-LocalUser -Name $_; Write-Host "  Enabled: $_" -ForegroundColor Green }
```

**AD accounts (DC only):**
<details>
<summary>List all AD users with group memberships</summary>

```powershell
Get-ADUser -Filter * -Properties MemberOf, LastLogonDate | Select-Object Name, Enabled, LastLogonDate, @{N='Groups';E={
    ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace 'CN=' }) -join ', '
}} | Format-Table -AutoSize
```
</details>
**Disable:**
```powershell
"Guest","krbtgt" | ForEach-Object { Disable-ADAccount -Identity $_; Write-Host "  Disabled: $_" -ForegroundColor Yellow }
```
**Re-enable:**
```powershell
"Guest" | ForEach-Object { Enable-ADAccount -Identity $_; Write-Host "  Enabled: $_" -ForegroundColor Green }
```
**Strip all groups from all users EXCEPT a keep list** (leaves them in Domain Users only — enabled but powerless):
<details>
<summary>Dry-run preview, then batch strip by group</summary>

```powershell
$keep = @("Administrator","krbtgt")
$users = @(Get-ADUser -Filter * -Properties MemberOf | Where-Object { $_.SamAccountName -notin $keep -and $_.MemberOf })

# Preview what will be stripped
Write-Host "`n=== DRY RUN — will strip groups from $($users.Count) users ===" -ForegroundColor Cyan
Write-Host "  Keeping: $($keep -join ', ')" -ForegroundColor Green
Write-Host ""
foreach ($u in $users) {
    $groups = ($u.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace 'CN=' }) -join ', '
    Write-Host "  $($u.SamAccountName) — $groups" -ForegroundColor Yellow
}
Write-Host ""
$confirm = Read-Host "Proceed? (y/n)"
if ($confirm -ne 'y') { Write-Host "  Aborted." -ForegroundColor Red; return }

# Execute
$groupMap = @{}
foreach ($u in $users) {
    foreach ($g in $u.MemberOf) { if (-not $groupMap[$g]) { $groupMap[$g] = @() }; $groupMap[$g] += $u.SamAccountName }
}
foreach ($g in $groupMap.Keys) {
    $name = ($g -split ',')[0] -replace 'CN='
    Remove-ADGroupMember -Identity $g -Members $groupMap[$g] -Confirm:$false
    Write-Host "  $name — removed: $($groupMap[$g] -join ', ')" -ForegroundColor Green
}
Write-Host "`n  Done. Stripped $($users.Count) users." -ForegroundColor Cyan
```
</details>

**Reset krbtgt twice (DC only)** — kills Golden Tickets. Reset twice because AD keeps current + previous hash.
```powershell
Get-ADUser krbtgt | Set-ADAccountPassword -Reset -NewPassword (ConvertTo-SecureString (([char[]]([char]33..[char]122) | Get-Random -Count 32) -join '') -AsPlainText -Force)
```
Run the above command **twice** back-to-back. May briefly break Kerberos auth.

### 5. Review & Kick Active Sessions

> [!WARNING]
> **Disabling an account does NOT kick active sessions.** You must also logoff/terminate existing sessions.

**Show all active sessions (RDP, SSH, WinRM):**
<details>
<summary>Lists RDP, SSH, WinRM sessions with color-coded status</summary>

```powershell
Write-Host "`n=== RDP Sessions ===" -ForegroundColor Cyan
$rdp = qwinsta 2>&1 | Where-Object { $_ -match "rdp-tcp|console" -and $_ -notmatch "^SESSIONNAME" }
if ($rdp) { $rdp | ForEach-Object { Write-Host "  $_" } } else { Write-Host "  None" -ForegroundColor Gray }

Write-Host "`n=== SSH ===" -ForegroundColor Cyan
$sshService = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshService) {
    Write-Host "  OpenSSH Server: $($sshService.Status)" -ForegroundColor $(if($sshService.Status -eq 'Running'){'Yellow'}else{'Green'})
    $sshProcs = Get-Process sshd -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $sshService.Id }
    if ($sshProcs) {
        Write-Host "  Active SSH sessions:" -ForegroundColor Yellow
        $sshProcs | ForEach-Object { Write-Host "    PID $($_.Id) — started $($_.StartTime)" }
    } else { Write-Host "  No active SSH sessions" -ForegroundColor Gray }
} else { Write-Host "  OpenSSH Server: Not installed" -ForegroundColor Green }

Write-Host "`n=== WinRM ===" -ForegroundColor Cyan
$winrmService = Get-Service WinRM -ErrorAction SilentlyContinue
if ($winrmService) {
    Write-Host "  WinRM Service: $($winrmService.Status)" -ForegroundColor $(if($winrmService.Status -eq 'Running'){'Yellow'}else{'Green'})
    if ($winrmService.Status -eq 'Running') {
        $sessions = Get-WSManInstance -ResourceURI shell -Enumerate -ErrorAction SilentlyContinue
        if ($sessions) {
            Write-Host "  Active WinRM sessions:" -ForegroundColor Yellow
            $sessions | ForEach-Object { Write-Host "    Owner: $($_.Owner) — Shell: $($_.ShellId) — Idle: $($_.ShellInactivity)s" }
        } else { Write-Host "  No active WinRM sessions" -ForegroundColor Gray }
    }
} else { Write-Host "  WinRM Service: Not installed" -ForegroundColor Green }

Write-Host ""
```
</details>

**Kick all RDP sessions:**
```powershell
qwinsta | ForEach-Object { if ($_ -match "\s+(\d+)\s+" -and ($_ -match "rdp-tcp|Disc")) { logoff $matches[1] } }
```
**Kick a specific RDP session** (use session ID from `qwinsta` output):
```powershell
logoff <SESSION_ID>
```

**Kill all SSH sessions:**
```powershell
Get-Process sshd, ssh -ErrorAction SilentlyContinue | Stop-Process -Force
```

**Kill all WinRM sessions:**
```powershell
Get-WSManInstance -ResourceURI shell -Enumerate -ErrorAction SilentlyContinue | ForEach-Object { Remove-WSManInstance -ResourceURI shell -SelectorSet @{ShellId=$_.ShellId} }
```

---

> [!TIP]
> **Monitoring & Detection** — Get visibility before hardening

### 6. Run Sigcheck
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
Hardens domain-wide: audit logging (tuned for WinStride/Sysmon), password policy (NIST 800-63B), SMB signing, disable SMB1, LLMNR, NBT-NS, WPAD, credential protection, Windows Defender, and more. Verifies every setting after apply.
```powershell
# Safe mode (recommended for qualifiers — won't break services)
powershell -ExecutionPolicy Bypass -File scripts\Harden-GPO.ps1 -S
```
```powershell
# Full hardening (more aggressive — can break WinRM by IP, RC4 services)
powershell -ExecutionPolicy Bypass -File scripts\Harden-GPO.ps1 -SkipReset
```

<details>
<summary>Full Harden-GPO.ps1 script (753 lines)</summary>

```powershell
<#
.SYNOPSIS
    Domain GPO hardening script. Run once on the DC; settings propagate domain-wide.

.DESCRIPTION
    Replaces the old enforce-gpo Ansible role. Creates a "Hardening" GPO (or custom name)
    linked to the domain root, then applies audit, password, encryption, credential-protection,
    network-hardening, and Windows Defender enablement settings through that GPO.

.EXAMPLE
    # Full hardening (reset + everything)
    powershell -ExecutionPolicy Bypass -File Harden-GPO.ps1

    # Everything WITHOUT resetting GPOs
    powershell -ExecutionPolicy Bypass -File Harden-GPO.ps1 -SkipReset

    # Just audit + encryption
    powershell -ExecutionPolicy Bypass -File Harden-GPO.ps1 -AuditPolicy -Encryption

    # Just reset (no hardening)
    powershell -ExecutionPolicy Bypass -File Harden-GPO.ps1 -Reset

    # Safe mode - won't break standard services
    powershell -ExecutionPolicy Bypass -File Harden-GPO.ps1 -S

    # Super-safe mode - guaranteed zero breakage (logging + passwords only)
    powershell -ExecutionPolicy Bypass -File Harden-GPO.ps1 -SS
#>

param(
    [switch]$All,              # Run everything (default if no flags)
    [switch]$Reset,            # dcgpofix /target:both
    [switch]$AuditPolicy,      # Audit logging + PowerShell logging
    [switch]$PasswordPolicy,   # Password + lockout policy
    [switch]$ScriptPolicy,     # AllSigned execution policy
    [switch]$Encryption,       # SMB, Kerberos, NTLM, LDAP
    [switch]$CredProtection,   # WDigest, LSA RunAsPPL, anonymous restriction
    [switch]$NetworkHardening, # LLMNR, NBT-NS, WPAD, NLA for RDP
    [switch]$SkipReset,        # Run -All but skip GPO reset
    [Alias("S")]
    [switch]$Safe,             # Safe mode: skips settings that could break services
    [Alias("SS")]
    [switch]$SuperSafe,        # Super-safe: only logging + password policy (zero breakage)
    [string]$GPOName = "Hardening"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Banner { param([string]$Text); Write-Host "`n=== $Text ===" -ForegroundColor Cyan }
function Write-Setting { param([string]$Text); Write-Host "  [+] $Text" -ForegroundColor Green }
function Write-Warn    { param([string]$Text); Write-Host "  [!] $Text" -ForegroundColor Yellow }
function Write-Verify  { param([string]$Text); Write-Host "  [?] $Text" -ForegroundColor Magenta }
function Write-Fail    { param([string]$Text); Write-Host "  [X] $Text" -ForegroundColor Red; $script:failures += $Text }

$script:failures = @()

function Test-Result {
    param([string]$Label, $Expected, $Actual)
    if ("$Actual" -eq "$Expected") {
        Write-Verify "PASS: $Label (expected=$Expected)"
    } else {
        Write-Fail "FAIL: $Label (expected=$Expected, got=$Actual)"
    }
}

function Set-RegValue {
    param(
        [string]$GPOName,
        [string]$Key,
        [string]$ValueName,
        $Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )
    Set-GPRegistryValue -Name $GPOName -Key $Key -ValueName $ValueName -Value $Value -Type $Type | Out-Null
    Write-Setting "$Key\$ValueName = $Value"
    try {
        $readBack = (Get-GPRegistryValue -Name $GPOName -Key $Key -ValueName $ValueName -ErrorAction Stop).Value
        Test-Result "$Key\$ValueName" $Value $readBack
    } catch {
        Write-Fail "FAIL: Could not read back $Key\$ValueName"
    }
}

# ── Preflight ────────────────────────────────────────────────────────────────

Write-Banner "Preflight checks"

# Must be Domain Controller
$os = Get-CimInstance Win32_OperatingSystem
if ($os.ProductType -ne 2) {
    Write-Error "This script must run on a Domain Controller (ProductType 2). Current: $($os.ProductType)"
    exit 1
}
Write-Setting "Running on Domain Controller: $($env:COMPUTERNAME)"

# Import required modules
foreach ($mod in @("GroupPolicy", "ActiveDirectory")) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Error "Required module '$mod' is not installed."
        exit 1
    }
    Import-Module $mod -ErrorAction Stop
    Write-Setting "Module loaded: $mod"
}

$Domain = (Get-ADDomain).DNSRoot
$DomainDN = (Get-ADDomain).DistinguishedName
Write-Setting "Domain: $Domain ($DomainDN)"

# ── Resolve which sections to run ────────────────────────────────────────────

# Safety modes override individual flags
if ($SuperSafe) {
    Write-Banner "Mode: SUPER-SAFE (logging + passwords only)"
    $runReset            = $false
    $runAuditPolicy      = $true
    $runPasswordPolicy   = $true
    $runScriptPolicy     = $false
    $runEncryption       = $false
    $runCredProtection   = $false
    $runNetworkHardening = $false
} elseif ($Safe) {
    Write-Banner "Mode: SAFE (skipping risky settings)"
    $runReset            = $false
    $runAuditPolicy      = $true
    $runPasswordPolicy   = $true
    $runScriptPolicy     = $false
    $runEncryption       = $true
    $runCredProtection   = $true
    $runNetworkHardening = $true
} else {
    $flags = @($Reset, $AuditPolicy, $PasswordPolicy, $ScriptPolicy,
               $Encryption, $CredProtection, $NetworkHardening, $SkipReset)
    $anyFlag = $flags | Where-Object { $_ }

    if (-not $anyFlag) { $All = [switch]::Present }
    if ($SkipReset) { $All = [switch]::Present }

    $runReset            = $All -and -not $SkipReset -or $Reset
    $runAuditPolicy      = $All -or $AuditPolicy
    $runPasswordPolicy   = $All -or $PasswordPolicy
    $runScriptPolicy     = $All -or $ScriptPolicy
    $runEncryption       = $All -or $Encryption
    $runCredProtection   = $All -or $CredProtection
    $runNetworkHardening = $All -or $NetworkHardening
}

$summary = @()

# ── Reset ────────────────────────────────────────────────────────────────────

if ($runReset) {
    Write-Banner "GPO Reset (dcgpofix)"
    Write-Warn "Resetting Default Domain Policy and Default Domain Controllers Policy"
    "Y","Y" | dcgpofix /target:both 2>&1 | ForEach-Object { Write-Host "    $_" }
    $dcgpofixExit = $LASTEXITCODE
    & gpupdate /force 2>&1 | Out-Null
    $summary += "GPO Reset"
    Write-Setting "GPO reset complete"
    Test-Result "dcgpofix exit code" 0 $dcgpofixExit
}

# ── Create / Get hardening GPO ───────────────────────────────────────────────

$needGPO = $runAuditPolicy -or $runScriptPolicy -or $runEncryption -or $runCredProtection -or $runNetworkHardening

if ($needGPO) {
    Write-Banner "GPO Setup"
    $gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $GPOName
        Write-Setting "Created GPO: $GPOName"
    } else {
        Write-Setting "Using existing GPO: $GPOName"
    }

    try {
        New-GPLink -Name $GPOName -Target $DomainDN -LinkEnabled Yes -ErrorAction Stop | Out-Null
        Write-Setting "Linked GPO to $DomainDN"
    } catch {
        if ($_.Exception.Message -match "already linked|already exists") {
            Write-Setting "GPO already linked to $DomainDN"
        } else { throw }
    }

    $verifyGpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    Test-Result "GPO '$GPOName' exists" $true ($null -ne $verifyGpo)
    $inheritance = Get-GPInheritance -Target $DomainDN
    $linked = $inheritance.GpoLinks | Where-Object { $_.DisplayName -eq $GPOName }
    Test-Result "GPO '$GPOName' linked to domain" $true ($null -ne $linked)
}

# ── Audit Policy ─────────────────────────────────────────────────────────────

if ($runAuditPolicy) {
    Write-Banner "Audit Policy"

    Write-Setting "Writing audit policy to GptTmpl.inf"
    $gpoId = "{$($gpo.Id.ToString().ToUpper())}"
    $secEditPath = "\\$Domain\SYSVOL\$Domain\Policies\$gpoId\Machine\Microsoft\Windows NT\SecEdit"

    if (-not (Test-Path $secEditPath)) {
        New-Item -Path $secEditPath -ItemType Directory -Force | Out-Null
    }

    # 3 = Success and Failure; 0 = No Auditing
    # Only enable categories that WinStride/Sysmon actually consume
    $gptTmpl = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Event Audit]
AuditSystemEvents = 3
AuditLogonEvents = 3
AuditObjectAccess = 3
AuditPrivilegeUse = 0
AuditPolicyChange = 0
AuditAccountManage = 3
AuditProcessTracking = 3
AuditDSAccess = 3
AuditAccountLogon = 3
"@
    $gptTmpl | Out-File -FilePath "$secEditPath\GptTmpl.inf" -Encoding Unicode -Force
    Write-Setting "GptTmpl.inf written (7 categories enabled, 2 disabled)"

    $securityCSE = "[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]"
    $gpoDN = "CN=$gpoId,CN=Policies,CN=System,$DomainDN"
    $gpoAD = Get-ADObject -Identity $gpoDN -Properties gPCMachineExtensionNames
    $currentCSE = $gpoAD.gPCMachineExtensionNames
    if (-not $currentCSE) { $currentCSE = "" }
    if ($currentCSE -notmatch [regex]::Escape($securityCSE)) {
        $currentCSE += $securityCSE
        Set-ADObject -Identity $gpoDN -Replace @{gPCMachineExtensionNames = $currentCSE}
        Write-Setting "Security CSE registered"
    } else {
        Write-Setting "Security CSE already present"
    }

    $gpoAD = Get-ADObject -Identity $gpoDN -Properties versionNumber
    $newVer = [int]$gpoAD.versionNumber + 65536
    Set-ADObject -Identity $gpoDN -Replace @{versionNumber = $newVer}
    $gptIniPath = "\\$Domain\SYSVOL\$Domain\Policies\$gpoId\GPT.INI"
    $gptIniContent = Get-Content $gptIniPath -Raw -ErrorAction SilentlyContinue
    if ($gptIniContent) {
        $gptIniContent = $gptIniContent -replace "Version=\d+", "Version=$newVer"
        $gptIniContent | Out-File -FilePath $gptIniPath -Encoding ASCII -Force
    }
    Write-Setting "GPO version bumped to $newVer"

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "SCENoApplyLegacyAuditPolicy" -Value 0
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "SCENoApplyLegacyAuditPolicy" -Value 0 -Type DWord -Force
    Write-Setting "SCENoApplyLegacyAuditPolicy = 0 (legacy audit enabled)"

    # Only PowerShell logging — Sysmon handles process/cmdline tracking
    Write-Setting "Configuring registry-based logging"

    # PowerShell Script Block Logging (Event 4104)
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
        -ValueName "EnableScriptBlockLogging" -Value 1

    # PowerShell Module Logging (Event 4103)
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging" `
        -ValueName "EnableModuleLogging" -Value 1
    Set-GPRegistryValue -Name $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" `
        -ValueName "*" -Value "*" -Type String | Out-Null
    Write-Setting "  ModuleNames\* = *"

    # Security log size: 1 GB
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\EventLog\Security" `
        -ValueName "MaxSize" -Value 1048576

    # Verify audit policy in GptTmpl.inf
    $verifyInf = Get-Content "$secEditPath\GptTmpl.inf" -ErrorAction SilentlyContinue
    if ($verifyInf) {
        $expectedAudit = @{
            AuditSystemEvents    = "3"
            AuditLogonEvents     = "3"
            AuditObjectAccess    = "3"
            AuditPrivilegeUse    = "0"
            AuditPolicyChange    = "0"
            AuditAccountManage   = "3"
            AuditProcessTracking = "3"
            AuditDSAccess        = "3"
            AuditAccountLogon    = "3"
        }
        foreach ($cat in $expectedAudit.Keys) {
            $match = $verifyInf | Where-Object { $_ -match "^\s*$cat\s*=" }
            if ($match -and $match -match "=\s*(\d+)") { $val = $Matches[1] } else { $val = "MISSING" }
            Test-Result "Audit $cat" $expectedAudit[$cat] $val
        }
    } else {
        Write-Fail "FAIL: Could not read back GptTmpl.inf for audit verification"
    }

    $summary += "Audit Policy"
}

# ── Password Policy ──────────────────────────────────────────────────────────

if ($runPasswordPolicy) {
    Write-Banner "Password & Lockout Policy"

    $ddpGpo = Get-GPO -Name "Default Domain Policy" -ErrorAction Stop
    $ddpId = "{$($ddpGpo.Id.ToString().ToUpper())}"
    $ddpSecEditPath = "\\$Domain\SYSVOL\$Domain\Policies\$ddpId\Machine\Microsoft\Windows NT\SecEdit"

    if (-not (Test-Path $ddpSecEditPath)) {
        New-Item -Path $ddpSecEditPath -ItemType Directory -Force | Out-Null
    }

    $ddpInfPath = "$ddpSecEditPath\GptTmpl.inf"

    # Enable MinimumPasswordLength > 14 (required before setting length to 16)
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\SAM" `
        -Name "RelaxMinimumPasswordLengthLimits" -Value 1 -Type DWord -Force
    Write-Setting "RelaxMinimumPasswordLengthLimits = 1 (allows MinPasswordLength > 14)"

    Set-GPRegistryValue -Name "Default Domain Policy" `
        -Key "HKLM\System\CurrentControlSet\Control\SAM" `
        -ValueName "RelaxMinimumPasswordLengthLimits" -Value 1 -Type DWord | Out-Null
    Write-Setting "RelaxMinimumPasswordLengthLimits pushed via Default Domain Policy GPO"

    # NIST SP 800-63B 2024: length-based policy, no composition rules
    $pwdSettings = [ordered]@{
        MinimumPasswordLength = 16
        PasswordHistorySize   = 24
        MinimumPasswordAge    = 0
        MaximumPasswordAge    = -1
        PasswordComplexity    = 0
        ClearTextPassword     = 0
        LockoutBadCount       = 10
        ResetLockoutCount     = 15
        LockoutDuration       = 15
    }

    if (Test-Path $ddpInfPath) {
        $infContent = Get-Content $ddpInfPath -Raw
    } else {
        $infContent = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
"@
    }

    if ($infContent -notmatch '\[System Access\]') {
        $infContent += "`r`n[System Access]`r`n"
    }

    foreach ($key in $pwdSettings.Keys) {
        $val = $pwdSettings[$key]
        if ($infContent -match "(?m)^\s*$key\s*=") {
            $infContent = $infContent -replace "(?m)^\s*$key\s*=\s*.*$", "$key = $val"
        } else {
            $infContent = $infContent -replace "(\[System Access\])", "`$1`r`n$key = $val"
        }
    }

    $infContent | Out-File -FilePath $ddpInfPath -Encoding Unicode -Force
    foreach ($key in $pwdSettings.Keys) {
        Write-Setting "$key = $($pwdSettings[$key])"
    }

    $securityCSE = "[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]"
    $ddpDN = "CN=$ddpId,CN=Policies,CN=System,$DomainDN"
    $ddpAD = Get-ADObject -Identity $ddpDN -Properties gPCMachineExtensionNames
    $currentCSE = $ddpAD.gPCMachineExtensionNames
    if (-not $currentCSE) { $currentCSE = "" }
    if ($currentCSE -notmatch [regex]::Escape($securityCSE)) {
        $currentCSE += $securityCSE
        Set-ADObject -Identity $ddpDN -Replace @{gPCMachineExtensionNames = $currentCSE}
        Write-Setting "Security CSE registered on Default Domain Policy"
    } else {
        Write-Setting "Security CSE already present on Default Domain Policy"
    }

    $ddpAD = Get-ADObject -Identity $ddpDN -Properties versionNumber
    $ddpNewVer = [int]$ddpAD.versionNumber + 65536
    Set-ADObject -Identity $ddpDN -Replace @{versionNumber = $ddpNewVer}
    $ddpGptIniPath = "\\$Domain\SYSVOL\$Domain\Policies\$ddpId\GPT.INI"
    $ddpGptIniContent = Get-Content $ddpGptIniPath -Raw -ErrorAction SilentlyContinue
    if ($ddpGptIniContent) {
        $ddpGptIniContent = $ddpGptIniContent -replace "Version=\d+", "Version=$ddpNewVer"
        $ddpGptIniContent | Out-File -FilePath $ddpGptIniPath -Encoding ASCII -Force
    }
    Write-Setting "Default Domain Policy version bumped to $ddpNewVer"

    # NIST SP 800-63B 2024: complexity disabled (no composition rules)
    Set-ADDefaultDomainPasswordPolicy -Identity $Domain `
        -MinPasswordLength 16 `
        -PasswordHistoryCount 24 `
        -MinPasswordAge ([TimeSpan]::Zero) `
        -MaxPasswordAge ([TimeSpan]::Zero) `
        -ComplexityEnabled $false `
        -LockoutThreshold 10 `
        -LockoutDuration (New-TimeSpan -Minutes 15) `
        -LockoutObservationWindow (New-TimeSpan -Minutes 15)
    Write-Setting "AD attributes set via Set-ADDefaultDomainPasswordPolicy"

    $verifyPwdInf = Get-Content $ddpInfPath -ErrorAction SilentlyContinue
    if ($verifyPwdInf) {
        foreach ($key in $pwdSettings.Keys) {
            $expected = "$($pwdSettings[$key])"
            $match = $verifyPwdInf | Where-Object { $_ -match "^\s*$key\s*=" }
            if ($match -and $match -match "=\s*(-?\d+)") { $val = $Matches[1] } else { $val = "MISSING" }
            Test-Result "Password GptTmpl $key" $expected $val
        }
    } else {
        Write-Fail "FAIL: Could not read back GptTmpl.inf for password verification"
    }

    $adPwd = Get-ADDefaultDomainPasswordPolicy -Identity $Domain
    Test-Result "AD MinPasswordLength" "16" "$($adPwd.MinPasswordLength)"
    Test-Result "AD PasswordHistoryCount" "24" "$($adPwd.PasswordHistoryCount)"
    Test-Result "AD ComplexityEnabled" "False" "$($adPwd.ComplexityEnabled)"
    Test-Result "AD LockoutThreshold" "10" "$($adPwd.LockoutThreshold)"

    $summary += "Password Policy"
}

# ── Script Execution Policy ──────────────────────────────────────────────────

if ($runScriptPolicy) {
    Write-Banner "Script Execution Policy"

    Set-GPRegistryValue -Name $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell" `
        -ValueName "ExecutionPolicy" -Value "AllSigned" -Type String | Out-Null
    Write-Setting "ExecutionPolicy = AllSigned"

    try {
        $readBack = (Get-GPRegistryValue -Name $GPOName `
            -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell" `
            -ValueName "ExecutionPolicy" -ErrorAction Stop).Value
        Test-Result "ExecutionPolicy" "AllSigned" $readBack
    } catch {
        Write-Fail "FAIL: Could not read back ExecutionPolicy"
    }

    $summary += "Script Policy"
}

# ── Encryption Hardening ─────────────────────────────────────────────────────

if ($runEncryption) {
    Write-Banner "Encryption Hardening"

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\LanManServer\Parameters" `
        -ValueName "RequireSecuritySignature" -Value 1

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
        -ValueName "RequireSecuritySignature" -Value 1

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\LanManServer\Parameters" `
        -ValueName "SMB1" -Value 0

    if (-not $Safe) {
        Set-RegValue -GPOName $GPOName `
            -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" `
            -ValueName "SupportedEncryptionTypes" -Value 24

        Set-RegValue -GPOName $GPOName `
            -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
            -ValueName "LmCompatibilityLevel" -Value 5
    } else {
        Set-RegValue -GPOName $GPOName `
            -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
            -ValueName "LmCompatibilityLevel" -Value 3
        Write-Warn "Skipped Kerberos AES-only (Safe mode)"
        Write-Warn "Using LmCompatibilityLevel 3 instead of 5 (Safe mode)"
    }

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\NTDS\Parameters" `
        -ValueName "LDAPServerIntegrity" -Value 2

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\ldap" `
        -ValueName "LDAPClientIntegrity" -Value 2

    if (-not $Safe) {
        Set-RegValue -GPOName $GPOName `
            -Key "HKLM\System\CurrentControlSet\Services\NTDS\Parameters" `
            -ValueName "LdapEnforceChannelBinding" -Value 2
    } else {
        Write-Warn "Skipped LDAP channel binding enforcement (Safe mode)"
    }

    $summary += "Encryption"
}

# ── Credential Protection ────────────────────────────────────────────────────

if ($runCredProtection) {
    Write-Banner "Credential Protection"

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\SecurityProviders\WDigest" `
        -ValueName "UseLogonCredential" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "RunAsPPL" -Value 2

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "RestrictAnonymousSAM" -Value 1

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "RestrictAnonymous" -Value 1

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "EveryoneIncludesAnonymous" -Value 0

    Set-GPRegistryValue -Name $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "RestrictRemoteSAM" -Value "O:BAG:BAD:(A;;RC;;;BA)" -Type String | Out-Null
    Write-Setting "HKLM\System\CurrentControlSet\Control\Lsa\RestrictRemoteSAM = O:BAG:BAD:(A;;RC;;;BA)"

    $summary += "Credential Protection"
}

# ── Windows Defender (via GPO) ───────────────────────────────────────────────

if ($runCredProtection) {
    Write-Banner "Windows Defender (GPO)"

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender" `
        -ValueName "DisableAntiSpyware" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender" `
        -ValueName "DisableAntiVirus" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -ValueName "DisableRealtimeMonitoring" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -ValueName "DisableBehaviorMonitoring" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -ValueName "DisableOnAccessProtection" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -ValueName "DisableScanOnRealtimeEnable" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -ValueName "DisableIOAVProtection" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender\Spynet" `
        -ValueName "SpynetReporting" -Value 2

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows Defender\MpEngine" `
        -ValueName "MpEnablePus" -Value 1

    $summary += "Windows Defender"
}

# ── Network Hardening ────────────────────────────────────────────────────────

if ($runNetworkHardening) {
    Write-Banner "Network Hardening"

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows NT\DNSClient" `
        -ValueName "EnableMulticast" -Value 0

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\NetBT\Parameters" `
        -ValueName "NodeType" -Value 2

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" `
        -ValueName "DisableWpad" -Value 1

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -ValueName "UserAuthentication" -Value 1

    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -ValueName "SecurityLayer" -Value 2

    if (-not $Safe) {
        foreach ($svc in @("TlntSvr", "SNMP")) {
            Set-RegValue -GPOName $GPOName `
                -Key "HKLM\System\CurrentControlSet\Services\$svc" `
                -ValueName "Start" -Value 4
        }
    } else {
        Write-Warn "Skipped disabling services (Safe mode)"
    }

    $summary += "Network Hardening"
}

# ── Force GP Update ──────────────────────────────────────────────────────────

Write-Banner "Applying Group Policy"
& gpupdate /force 2>&1 | ForEach-Object { Write-Host "    $_" }

# ── Post-gpupdate Verification ──────────────────────────────────────────────

Write-Banner "Post-gpupdate Verification"

if ($runPasswordPolicy) {
    $netAccounts = net accounts 2>&1
    foreach ($line in $netAccounts) {
        if ($line -match "Minimum password length\s+(\d+)") {
            Test-Result "Effective MinPasswordLength" "16" $Matches[1]
        }
        if ($line -match "Lockout threshold\s+(\d+)") {
            Test-Result "Effective LockoutThreshold" "10" $Matches[1]
        }
        if ($line -match "Lockout duration.*?(\d+)") {
            Test-Result "Effective LockoutDuration" "15" $Matches[1]
        }
        if ($line -match "Length of password history\s+(\d+)") {
            Test-Result "Effective PasswordHistory" "24" $Matches[1]
        }
    }
}

if ($runAuditPolicy) {
    $auditOut = auditpol /get /category:* 2>&1
    $auditCategories = @{
        "Logon/Logoff"       = "Success and Failure"
        "Account Logon"      = "Success and Failure"
        "Account Management" = "Success and Failure"
        "Object Access"      = "Success and Failure"
        "DS Access"          = "Success and Failure"
        "Policy Change"      = "No Auditing"
        "Privilege Use"      = "No Auditing"
        "System"             = "Success and Failure"
        "Detailed Tracking"  = "Success and Failure"
    }
    foreach ($cat in $auditCategories.Keys) {
        $match = $auditOut | Where-Object { $_ -match "^\s+$cat\s+" }
        if ($match -and $match -match "(Success and Failure|Success|Failure|No Auditing)") {
            Test-Result "Effective Audit '$cat'" $auditCategories[$cat] $Matches[1]
        }
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────

Write-Banner "Complete"
Write-Host ""
if ($summary.Count -eq 0) {
    Write-Host "  No sections were executed." -ForegroundColor Yellow
} else {
    Write-Host "  Sections applied:" -ForegroundColor Green
    foreach ($s in $summary) { Write-Host "    - $s" -ForegroundColor Green }
}

# ── Verification Summary ────────────────────────────────────────────────────

Write-Banner "Verification Summary"
if ($script:failures.Count -eq 0) {
    Write-Host "  All verifications passed." -ForegroundColor Green
} else {
    Write-Host "  $($script:failures.Count) verification(s) FAILED:" -ForegroundColor Red
    foreach ($f in $script:failures) {
        Write-Host "    - $f" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  Manual checks:" -ForegroundColor White
Write-Host "    gpmc.msc            - '$GPOName' GPO linked to domain" -ForegroundColor Gray
Write-Host "    auditpol /get /category:* - audit categories on DC" -ForegroundColor Gray
Write-Host "    gpresult /r         - on remote machines after gpupdate" -ForegroundColor Gray
Write-Host "    net accounts        - password policy" -ForegroundColor Gray
Write-Host ""

if ($script:failures.Count -gt 0) { exit 1 }
```

</details>

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
<summary>Apply GPO, clean up exclusions, verify Defender is running</summary>

> [!IMPORTANT]
> `Harden-GPO.ps1` (step 12) handles enabling Defender via GPO. This script pulls that policy, does local cleanup GPO can't do, and confirms everything works.

```powershell
# ── Pull GPO and start the service ───────────────────────────────────────────
gpupdate /force
sc.exe config WinDefend start= auto 2>&1 | Out-Null
net start WinDefend 2>&1 | Out-Null
Start-Sleep -Seconds 3

# Re-enable Defender scheduled tasks red team may have disabled
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\*" -ErrorAction SilentlyContinue |
    Enable-ScheduledTask -ErrorAction SilentlyContinue

# ── Remove exclusions red team added (GPO can't do this) ────────────────────
$prefs = Get-MpPreference -ErrorAction SilentlyContinue
if ($prefs) {
    @($prefs.ExclusionPath)      | Where-Object { $_ } | ForEach-Object { Remove-MpPreference -ExclusionPath $_ -ErrorAction SilentlyContinue }
    @($prefs.ExclusionProcess)   | Where-Object { $_ } | ForEach-Object { Remove-MpPreference -ExclusionProcess $_ -ErrorAction SilentlyContinue }
    @($prefs.ExclusionExtension) | Where-Object { $_ } | ForEach-Object { Remove-MpPreference -ExclusionExtension $_ -ErrorAction SilentlyContinue }
}

# ── Update signatures and scan ───────────────────────────────────────────────
Update-MpSignature
Start-MpScan -ScanType QuickScan

# ── Verify ───────────────────────────────────────────────────────────────────
$s = Get-MpComputerStatus
Write-Host ""
Write-Host "=== Defender Status ===" -ForegroundColor Cyan
Write-Host "  AMServiceEnabled:        $($s.AMServiceEnabled)"          -ForegroundColor $(if($s.AMServiceEnabled){'Green'}else{'Red'})
Write-Host "  RealTimeProtection:      $($s.RealTimeProtectionEnabled)" -ForegroundColor $(if($s.RealTimeProtectionEnabled){'Green'}else{'Red'})
Write-Host "  BehaviorMonitor:         $($s.BehaviorMonitorEnabled)"    -ForegroundColor $(if($s.BehaviorMonitorEnabled){'Green'}else{'Red'})
Write-Host "  OnAccessProtection:      $($s.OnAccessProtectionEnabled)" -ForegroundColor $(if($s.OnAccessProtectionEnabled){'Green'}else{'Red'})
Write-Host "  IoavProtection:          $($s.IoavProtectionEnabled)"     -ForegroundColor $(if($s.IoavProtectionEnabled){'Green'}else{'Red'})
Write-Host "  AntivirusSignatureAge:   $($s.AntivirusSignatureAge) days" -ForegroundColor $(if($s.AntivirusSignatureAge -le 1){'Green'}else{'Yellow'})
Write-Host ""
if ($s.AMServiceEnabled -and $s.RealTimeProtectionEnabled) {
    Write-Host "[OK] Defender is fully operational" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Defender is NOT fully operational — check GPO on DC" -ForegroundColor Red
}
```

> [!NOTE]
> **If Defender still won't start:**
> 1. On the DC: `gpmc.msc` > look for GPOs disabling Defender under Computer Config > Policies > Admin Templates > Windows Components > Windows Defender Antivirus — delete them
> 2. On this machine: `gpupdate /force` and re-run the script above
> 3. If the WinDefend binary was deleted: `sfc /scannow` or `DISM /Online /Cleanup-Image /RestoreHealth`

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

### 16. Chainsaw Triage
<details>
<summary>Run from C:\Chainsaw — targeted hunts, not a firehose</summary>

All commands assume `cd C:\Chainsaw`. Set `$from` to competition start time (UTC) to ignore old noise.

```powershell
cd C:\Chainsaw
$logs = "C:\Windows\System32\winevt\Logs"
$from = "2026-03-14T09:00:00"  # ← SET TO COMPETITION START (UTC)
```

#### A. Critical + High hits only (run this first)
Shows only high-confidence detections. Start here.
```powershell
.\chainsaw.exe hunt $logs -s rules/ --mapping mappings/sigma-event-logs-all.yml `
    --level high --from $from --full -q
```

#### B. Lateral movement
PsExec, WMI, DCOM, remote services, pass-the-hash.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/lateral_movement/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full -q
```

#### C. Persistence
Scheduled tasks, malicious services, registry run keys.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/persistence/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full -q
```

#### D. Credential access
LSASS dumps, credential theft, Kerberoasting.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/credential_access/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full -q
```

#### E. Log tampering / defense evasion
Event log clearing, Defender disabled, audit policy changed.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/log_tampering/ -r rules/evtx/defense_evasion/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full -q
```

#### F. Suspicious PowerShell
Encoded commands, obfuscation, known tool invocations.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/powershell/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full -q
```

#### G. Search for a specific IOC
Replace the search term with whatever you're looking for.
```powershell
# Known tool name
.\chainsaw.exe search mimikatz $logs -i --from $from -q

# Suspicious username
.\chainsaw.exe search -t "Event.EventData.TargetUserName: =svc_backup" "$logs\Security.evtx" --from $from -q

# IP address
.\chainsaw.exe search -e "10\.0\.0\.200" $logs --from $from -q
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

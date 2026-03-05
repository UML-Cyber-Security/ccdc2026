# Windows First 15 Minutes - CCDC 2026

> [!CAUTION]
> **Time-critical.** Run Step 1 on every Windows host immediately. DC-only steps are marked.

---

## First 15 Minutes

<details>
<summary><b>1. Setup & Tools</b> — Reset hosts, install Firefox, Sysinternals + Sysmon</summary>

#### Reset Hosts File
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

#### Install Firefox
```powershell
$firefoxInstallerUrl = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
$installerPath = "$env:TEMP\firefox_installer.exe"
Invoke-WebRequest -Uri $firefoxInstallerUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -Args "/S" -Wait
Remove-Item -Path $installerPath
```

#### Install Sysinternals

```powershell
$dest = "C:\Sysinternals"
New-Item $dest -ItemType Directory -ErrorAction SilentlyContinue

$tools = @(
    'procexp64.exe', 'Procmon64.exe', 'Autoruns64.exe', 'autorunsc64.exe',
    'Tcpview.exe', 'Sysmon64.exe', 'Sigcheck64.exe',
    'PsLoggedOn.exe', 'PsService.exe', 'AccessChk64.exe',
    'handle64.exe', 'listdlls64.exe', 'strings64.exe'
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")
foreach ($t in $tools) {
    $wc.DownloadFile("https://live.sysinternals.com/$t", "$dest\$t")
}
$wc.Dispose()

# Accept all Sysinternals EULAs per-tool so dialogs never appear
Write-Host "[*] Accepting EULAs..." -ForegroundColor Cyan
$eulaNames = @(
    'Process Explorer','Process Monitor','Autoruns','AutorunsC',
    'TCPView','Sysmon','Sigcheck','PsLoggedOn','PsService',
    'AccessChk','Handle','ListDLLs','Strings'
)
foreach ($t in $eulaNames) {
    reg add "HKCU\Software\Sysinternals\$t" /v EulaAccepted /t REG_DWORD /d 1 /f | Out-Null
}

# Set all .exe files to always run as admin
Write-Host "[*] Setting run-as-admin..." -ForegroundColor Cyan
Get-ChildItem "$dest\*.exe" | ForEach-Object {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" `
        -Name $_.FullName -Value "~ RUNASADMIN" -ErrorAction SilentlyContinue
}

# Install Sysmon with config (XML built via string to keep markdown rendering clean)
$exts = '.exe','.dll','.sys','.scr','.ps1','.bat','.cmd','.vbs','.js','.wsf','.hta','.msi'
$lines = @('<Sysmon schemaversion="4.50">','  <EventFiltering>',
    '    <ProcessCreate onmatch="exclude" />','    <NetworkConnect onmatch="exclude" />',
    '    <FileCreate onmatch="include">')
$exts | ForEach-Object { $lines += "      <TargetFilename condition=`"end with`">$_</TargetFilename>" }
$lines += '    </FileCreate>','  </EventFiltering>','</Sysmon>'
($lines -join "`r`n") | Out-File "$env:TEMP\sc.xml" -Encoding UTF8
Write-Host "[*] Installing Sysmon..." -ForegroundColor Cyan
cmd /c "`"$dest\Sysmon64.exe`" -accepteula -i `"$env:TEMP\sc.xml`" >nul 2>&1"

# Launch the tools you actually need open during competition
Start-Process "$dest\procexp64.exe"   # process explorer
Start-Process "$dest\Autoruns64.exe"  # startup/persistence items
Start-Process "$dest\Tcpview.exe"     # live network connections

Write-Host "[+] Sysinternals installed to $dest — Sysmon running, tools launched" -ForegroundColor Green
```

</details>

<details>
<summary><b>2. Disable & Reset Accounts</b> — Local + AD accounts, group membership reset, krbtgt</summary>

#### Local accounts

**List local users:**
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

**Disable:**
```powershell
"Guest","Administrator" | ForEach-Object { Disable-LocalUser -Name $_; Write-Host "  Disabled: $_" -ForegroundColor Yellow }
```

#### AD accounts (DC only)

**List AD users:**
```powershell
Get-ADUser -Filter * -Properties MemberOf, LastLogonDate | Select-Object Name, Enabled, LastLogonDate, @{N='Groups';E={
    ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace 'CN=' }) -join ', '
}} | Format-Table -AutoSize
```

**Disable:**
```powershell
"Guest","Administrator" | ForEach-Object { Disable-ADAccount -Identity $_; Write-Host "  Disabled: $_" -ForegroundColor Yellow }
```

#### Reset privileged groups to default AD membership
```powershell
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  DESIRED STATE — default AD privileged group memberships                   ║
# ║  Only Administrator should be in these. Everything else gets removed.      ║
# ║  Groups listed here get their nested group memberships enforced too.       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Which users belong in which groups (by default only Administrator)
$defaultUsers = @{
    "Domain Admins"          = @("Administrator")
    "Enterprise Admins"      = @("Administrator")
    "Schema Admins"          = @("Administrator")
    "Administrators"         = @("Administrator")
    "Group Policy Creator Owners" = @("Administrator")
    "Server Operators"       = @()
    "Account Operators"      = @()
    "Backup Operators"       = @()
    "Print Operators"        = @()
    "Remote Desktop Users"   = @()
    "DnsAdmins"              = @()
}

# Which groups should be nested in which groups
$defaultGroupNesting = @{
    "Administrators" = @("Domain Admins", "Enterprise Admins")
    "Denied RODC Password Replication Group" = @(
        "Domain Admins", "Enterprise Admins", "Schema Admins",
        "Read-only Domain Controllers", "Domain Controllers"
    )
    "Group Policy Creator Owners" = @()
    "Schema Admins"          = @()
    "Domain Admins"          = @()
    "Enterprise Admins"      = @()
    "Server Operators"       = @()
    "Account Operators"      = @()
    "Backup Operators"       = @()
    "Print Operators"        = @()
    "Remote Desktop Users"   = @()
}

# ── Step 1: Backup current state ─────────────────────────────────────────────
$backupFile = "$env:USERPROFILE\Desktop\ad-groups-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$backupRows = @()
foreach ($groupName in ($defaultUsers.Keys + $defaultGroupNesting.Keys | Sort-Object -Unique)) {
    try {
        $members = Get-ADGroupMember -Identity $groupName -ErrorAction Stop
        foreach ($m in $members) {
            $backupRows += [PSCustomObject]@{
                Group      = $groupName
                Member     = $m.SamAccountName
                MemberType = $m.objectClass
                MemberDN   = $m.distinguishedName
            }
        }
    } catch {}
}
$backupRows | Export-Csv -Path $backupFile -NoTypeInformation
Write-Host "[+] Backed up current state to $backupFile" -ForegroundColor Green

# ── Step 2: Dry run — show what will change ──────────────────────────────────
$toRemove = @()
$toAdd    = @()

foreach ($groupName in ($defaultUsers.Keys + $defaultGroupNesting.Keys | Sort-Object -Unique)) {
    try { $currentMembers = @(Get-ADGroupMember -Identity $groupName -ErrorAction Stop) } catch { continue }

    $allowedUsers  = if ($defaultUsers.ContainsKey($groupName))        { $defaultUsers[$groupName] }        else { @() }
    $allowedGroups = if ($defaultGroupNesting.ContainsKey($groupName)) { $defaultGroupNesting[$groupName] } else { @() }

    foreach ($m in $currentMembers) {
        if ($m.objectClass -eq 'user' -and $m.SamAccountName -notin $allowedUsers) {
            $toRemove += [PSCustomObject]@{ Group=$groupName; Member=$m.SamAccountName; Type='user'; DN=$m.distinguishedName }
        }
        if ($m.objectClass -eq 'group' -and $m.SamAccountName -notin $allowedGroups -and $m.Name -notin $allowedGroups) {
            $toRemove += [PSCustomObject]@{ Group=$groupName; Member=$m.Name; Type='group'; DN=$m.distinguishedName }
        }
    }

    # Check if any default members are missing (red team may have removed Administrator from Domain Admins)
    $currentNames = $currentMembers | ForEach-Object { $_.SamAccountName }
    foreach ($u in $allowedUsers) {
        if ($u -notin $currentNames) {
            $toAdd += [PSCustomObject]@{ Group=$groupName; Member=$u; Type='user' }
        }
    }
    $currentGroupNames = $currentMembers | Where-Object { $_.objectClass -eq 'group' } | ForEach-Object { $_.Name }
    foreach ($g in $allowedGroups) {
        if ($g -notin $currentGroupNames) {
            $toAdd += [PSCustomObject]@{ Group=$groupName; Member=$g; Type='group' }
        }
    }
}

Write-Host "`n=== WILL REMOVE ($($toRemove.Count)) ===" -ForegroundColor Red
foreach ($r in $toRemove) { Write-Host "  [$($r.Type)] $($r.Member) from $($r.Group)" -ForegroundColor Yellow }

Write-Host "`n=== WILL ADD BACK ($($toAdd.Count)) ===" -ForegroundColor Green
foreach ($a in $toAdd) { Write-Host "  [$($a.Type)] $($a.Member) to $($a.Group)" -ForegroundColor Cyan }

if ($toRemove.Count -eq 0 -and $toAdd.Count -eq 0) {
    Write-Host "`n[OK] All privileged groups already match defaults." -ForegroundColor Green
    return
}

Write-Host ""
$confirm = Read-Host "Proceed? (y/n)"
if ($confirm -ne 'y') { Write-Host "  Aborted." -ForegroundColor Red; return }

# ── Step 3: Execute removals ─────────────────────────────────────────────────
foreach ($r in $toRemove) {
    try {
        Remove-ADGroupMember -Identity $r.Group -Members $r.DN -Confirm:$false
        Write-Host "  REMOVED [$($r.Type)] $($r.Member) from $($r.Group)" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED to remove $($r.Member) from $($r.Group): $_" -ForegroundColor Red
    }
}

# ── Step 4: Execute additions (restore missing defaults) ─────────────────────
foreach ($a in $toAdd) {
    try {
        Add-ADGroupMember -Identity $a.Group -Members $a.Member -ErrorAction Stop
        Write-Host "  ADDED [$($a.Type)] $($a.Member) to $($a.Group)" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED to add $($a.Member) to $($a.Group): $_" -ForegroundColor Red
    }
}

Write-Host "`n  Done. Removed $($toRemove.Count), added $($toAdd.Count). Backup: $backupFile" -ForegroundColor Cyan
```

**Reset krbtgt twice (DC only)** — kills Golden Tickets. Reset twice because AD keeps current + previous hash. Do this manually through Active Directory Users and Computers: right-click `krbtgt` > Reset Password. Run it **twice** back-to-back. May briefly break Kerberos auth.

</details>

<details>
<summary><b>3. Review & Kick Active Sessions</b> — Show/kill RDP, disable SSH/WinRM</summary>

> [!WARNING]
> **Disabling an account does NOT kick active sessions.** You must also logoff/terminate existing sessions.

#### Show all active sessions (RDP, SSH, WinRM)
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

#### Kick a specific RDP session
Use session ID from `qwinsta` output above:
```powershell
logoff SESSION_ID
```

#### Disable SSH (kill sessions, stop, block firewall, prevent startup)
```powershell
Get-Process sshd, ssh -ErrorAction SilentlyContinue | Stop-Process -Force
Stop-Service sshd -Force -ErrorAction SilentlyContinue
Set-Service sshd -StartupType Disabled -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Block SSH Inbound" -Direction Inbound -Protocol TCP -LocalPort 22,2222 -Action Block -ErrorAction SilentlyContinue
Write-Host "[+] SSH killed, disabled, and blocked" -ForegroundColor Green
```

</details>

<details>
<summary><b>4. Network & Tools</b> — Install Nmap, Wireshark, enable firewall</summary>

#### Install Nmap
```powershell
$nmapUrl = "https://nmap.org/dist/nmap-7.93-setup.exe"
$installerPath = "$env:USERPROFILE\Downloads\nmap-setup.exe"
Invoke-WebRequest -Uri $nmapUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -ArgumentList '/forceinstall /NpcapInstallMode=1' -Wait
Remove-Item -Path $installerPath -Force
```

#### Install Wireshark
```powershell
$installerUrl = "https://2.na.dl.wireshark.org/win64/Wireshark-4.6.2-x64.exe"
$installerPath = "wireshark.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
Remove-Item -Path $installerPath
```

#### Enable Firewall
```powershell
# Turn on firewall for all profiles
Set-NetFirewallProfile -All -Enabled True

# Allow RDP, File/Printer Sharing, and ICMP ping
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)"

# Verify
Get-NetFirewallProfile | Format-Table Name, Enabled -AutoSize
```

</details>

<details>
<summary><b>5. Harden GPO (DC only)</b> — Import pre-built GPO backups (audit, password, encryption, Defender, network)</summary>

> [!NOTE]
> GPO backups were pre-built in the lab using `scripts/Harden-GPO.ps1` and exported with `Backup-GPO`.
> This imports them — much faster than building GPOs from scratch during competition.
> **If GPOBackups.zip is not available**, fall back to `scripts/Harden-GPO.ps1` (save it as a .ps1 file and run with `-Safe`).

#### Option A: GPOBackups.zip is on a USB or local path
```powershell

# ── Point this to the extracted GPOBackups folder ───────────────────────────
$backupPath = "C:\GPOBackups"   # <-- CHANGE to wherever you extracted GPOBackups.zip

# ── Import ──────────────────────────────────────────────────────────────────
Import-Module GroupPolicy, ActiveDirectory
$DomainDN = (Get-ADDomain).DistinguishedName

New-GPO -Name "Hardening" -ErrorAction SilentlyContinue
Import-GPO -BackupGpoName "Hardening" -Path $backupPath -TargetName "Hardening"
New-GPLink -Name "Hardening" -Target $DomainDN -LinkEnabled Yes -ErrorAction SilentlyContinue

Import-GPO -BackupGpoName "Default Domain Policy" -Path $backupPath -TargetName "Default Domain Policy"

# Local registry fix (GPO import doesn't do this)
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" `
    -Name "SCENoApplyLegacyAuditPolicy" -Value 0 -Type DWord -Force

gpupdate /force
Write-Host "[+] GPO import complete" -ForegroundColor Green
```

</details>


<details>
<summary><b>6. Enable Windows Defender</b> — Fix sabotage, clean exclusions, verify running (run step 5 first!)</summary>

> [!CAUTION]
> **You must run step 5 (Harden-GPO.ps1) before this.** That script enables Defender via GPO. This step pulls that policy, does local cleanup GPO can't do, and confirms everything works.

```powershell
# ── Phase 0: Preflight checks ────────────────────────────────────────────────
Write-Host "=== Preflight ===" -ForegroundColor Cyan

# Binaries exist?
# WinDefend service exists?
$defSvc = Get-Service WinDefend -ErrorAction SilentlyContinue
if (-not $defSvc) {
    Write-Host "  WinDefend service:       MISSING" -ForegroundColor Red
    Write-Host ""
    Write-Host "[!] Defender is not installed. Run these manually (slow, may impact services):" -ForegroundColor Red
    Write-Host "      Install-WindowsFeature -Name Windows-Defender -IncludeManagementTools  # Server only" -ForegroundColor Yellow
    Write-Host "      sfc /scannow" -ForegroundColor Yellow
    Write-Host "      DISM /Online /Cleanup-Image /RestoreHealth" -ForegroundColor Yellow
    Write-Host "    Then re-run this script." -ForegroundColor Red
    Write-Host ""
    return
}
Write-Host "  WinDefend service:       Present ($($defSvc.Status))" -ForegroundColor $(if($defSvc.Status -eq 'Running'){'Green'}else{'Yellow'})

# Engine binary exists? (check actual path from service, not hardcoded)
$imgPath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" -Name ImagePath -EA SilentlyContinue).ImagePath -replace '"',''
$engExists = $imgPath -and (Test-Path $imgPath)
Write-Host "  Engine binary:           $(if($engExists){'OK'}else{'MISSING'}) ($imgPath)" -ForegroundColor $(if($engExists){'Green'}else{'Red'})
if (-not $engExists) {
    Write-Host ""
    Write-Host "[!] Defender binary missing or corrupted. Run these manually (slow, may impact services):" -ForegroundColor Red
    Write-Host "      sfc /scannow" -ForegroundColor Yellow
    Write-Host "      DISM /Online /Cleanup-Image /RestoreHealth" -ForegroundColor Yellow
    Write-Host "    Then re-run this script." -ForegroundColor Red
    Write-Host ""
    return
}

# Feature installed? (Server only — silently skips on workstations)
$feat = Get-WindowsFeature -Name Windows-Defender* -ErrorAction SilentlyContinue
if ($feat -and $feat.InstallState -ne 'Installed') {
    Write-Host "  Windows-Defender feature: $($feat.InstallState)" -ForegroundColor Red
    Write-Host ""
    Write-Host "[!] Defender feature not installed. Run manually (may require reboot):" -ForegroundColor Red
    Write-Host "      Install-WindowsFeature -Name Windows-Defender -IncludeManagementTools" -ForegroundColor Yellow
    Write-Host "    Then re-run this script." -ForegroundColor Red
    Write-Host ""
    return
} elseif ($feat) {
    Write-Host "  Windows-Defender feature: $($feat.InstallState)" -ForegroundColor Green
}

# Services
foreach ($sn in @("WinDefend","WdNisSvc")) {
    $st = (sc.exe query $sn 2>&1 | Select-String "STATE").ToString().Trim()
    Write-Host "  ${sn}: $st" -ForegroundColor $(if($st -match 'RUNNING'){'Green'}else{'Yellow'})
}

# Drivers
foreach ($dn in @("WdFilter","WdBoot","WdNisDrv")) {
    $dv = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$dn" -Name Start -EA SilentlyContinue).Start
    $disabled = $dv -eq 4
    Write-Host "  Driver ${dn}: Start=$dv$(if($disabled){' (DISABLED)'})" -ForegroundColor $(if($disabled){'Red'}else{'Green'})
}

# Policy disable flags
$polDis = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -EA SilentlyContinue).DisableAntiSpyware
$locDis = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Defender" -EA SilentlyContinue).DisableAntiSpyware
if ($polDis -eq 1) { Write-Host "  [!] Policy DisableAntiSpyware = 1 (will fix)" -ForegroundColor Red }
if ($locDis -eq 1) { Write-Host "  [!] Local DisableAntiSpyware = 1 (will fix)" -ForegroundColor Red }

# Exclusions planted
$mp = Get-MpPreference -ErrorAction SilentlyContinue
$exTotal = (@($mp.ExclusionPath) + @($mp.ExclusionProcess) + @($mp.ExclusionExtension) + @($mp.ExclusionIpAddress) | Where-Object { $_ }).Count
Write-Host "  Exclusions planted:      $exTotal" -ForegroundColor $(if($exTotal -eq 0){'Green'}else{'Red'})

Write-Host ""

# ── Phase 1: Fix red team sabotage that prevents Defender from starting ──────

# 1a. Reset ACLs on Defender service keys (red team often locks these out)
# Strategy: try gentle Get-Acl first (preserves existing ACEs like TrustedInstaller),
# fall back to nuclear New-Object only if red team locked us out completely.
$svcKeys = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WdFilter",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisDrv",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WdBoot",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService",
    "HKLM:\SYSTEM\CurrentControlSet\Services\wscsvc"
)

# Helper: build the "nuclear" ACL that matches Windows defaults for service keys
function New-DefenderServiceAcl {
    $acl = New-Object System.Security.AccessControl.RegistrySecurity
    # Not protected — inherits from parent (HKLM:\SYSTEM\CurrentControlSet\Services)
    $acl.SetAccessRuleProtection($false, $true)
    # Owner = SYSTEM (matches default)
    $acl.SetOwner([System.Security.Principal.NTAccount]"NT AUTHORITY\SYSTEM")

    $rules = @(
        # SYSTEM — FullControl (default)
        @("NT AUTHORITY\SYSTEM",          "FullControl",
          "ContainerInherit,ObjectInherit", "None", "Allow"),
        # Administrators — FullControl (default)
        @("BUILTIN\Administrators",       "FullControl",
          "ContainerInherit,ObjectInherit", "None", "Allow"),
        # TrustedInstaller — FullControl (default — owns these keys, needed for servicing)
        @("NT SERVICE\TrustedInstaller",  "FullControl",
          "ContainerInherit,ObjectInherit", "None", "Allow"),
        # CREATOR OWNER — FullControl on subkeys only (standard default)
        @("CREATOR OWNER",                "FullControl",
          "ContainerInherit,ObjectInherit", "InheritOnly", "Allow"),
        # Users — Read (standard default)
        @("BUILTIN\Users",                "ReadKey",
          "ContainerInherit,ObjectInherit", "None", "Allow"),
        # ALL APPLICATION PACKAGES — Read (default, needed for AppContainer sandboxes)
        @("APPLICATION PACKAGE AUTHORITY\ALL APPLICATION PACKAGES", "ReadKey",
          "ContainerInherit,ObjectInherit", "None", "Allow"),
        # ALL RESTRICTED APP PACKAGES — Read (default on RS3+, safe no-op on older)
        @("APPLICATION PACKAGE AUTHORITY\ALL RESTRICTED APPLICATION PACKAGES", "ReadKey",
          "ContainerInherit,ObjectInherit", "None", "Allow")
    )
    foreach ($r in $rules) {
        try {
            $ace = New-Object System.Security.AccessControl.RegistryAccessRule(
                $r[0], $r[1], $r[2], $r[3], $r[4])
            $acl.AddAccessRule($ace)
        } catch {
            # ALL RESTRICTED APPLICATION PACKAGES may not exist on Server 2012 R2; skip safely
            Write-Host "    [i] Skipped ACE for $($r[0]) (SID not found on this OS)" -ForegroundColor DarkGray
        }
    }
    return $acl
}

foreach ($key in $svcKeys) {
    if (-not (Test-Path $key)) { continue }
    $keyName = ($key -split '\\')[-1]

    # ── Attempt 1: Gentle — read existing ACL, add SYSTEM+Admins if missing ──
    $gentle = $false
    try {
        $acl = Get-Acl -Path $key -ErrorAction Stop

        # Ensure inheritance is enabled (red team may have disabled it)
        if ($acl.AreAccessRulesProtected) {
            $acl.SetAccessRuleProtection($false, $true)
            Write-Host "    [~] $keyName : re-enabled ACL inheritance" -ForegroundColor Cyan
        }

        # Add SYSTEM FullControl if missing
        $hasSystem = $acl.Access | Where-Object {
            $_.IdentityReference -eq "NT AUTHORITY\SYSTEM" -and
            $_.RegistryRights -band [System.Security.AccessControl.RegistryRights]::FullControl }
        if (-not $hasSystem) {
            $acl.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule(
                "NT AUTHORITY\SYSTEM","FullControl","ContainerInherit,ObjectInherit","None","Allow")))
            Write-Host "    [~] $keyName : added SYSTEM FullControl" -ForegroundColor Cyan
        }

        # Add Administrators FullControl if missing
        $hasAdmin = $acl.Access | Where-Object {
            $_.IdentityReference -eq "BUILTIN\Administrators" -and
            $_.RegistryRights -band [System.Security.AccessControl.RegistryRights]::FullControl }
        if (-not $hasAdmin) {
            $acl.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule(
                "BUILTIN\Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow")))
            Write-Host "    [~] $keyName : added Administrators FullControl" -ForegroundColor Cyan
        }

        # Add TrustedInstaller FullControl if missing
        $hasTI = $acl.Access | Where-Object {
            $_.IdentityReference -eq "NT SERVICE\TrustedInstaller" -and
            $_.RegistryRights -band [System.Security.AccessControl.RegistryRights]::FullControl }
        if (-not $hasTI) {
            try {
                $acl.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule(
                    "NT SERVICE\TrustedInstaller","FullControl","ContainerInherit,ObjectInherit","None","Allow")))
                Write-Host "    [~] $keyName : added TrustedInstaller FullControl" -ForegroundColor Cyan
            } catch { }  # TI SID resolution may fail on some editions
        }

        # Remove any explicit Deny rules (red team plants these to block SYSTEM/Admins)
        $denyRules = $acl.Access | Where-Object { $_.AccessControlType -eq 'Deny' }
        foreach ($deny in $denyRules) {
            $acl.RemoveAccessRule($deny) | Out-Null
            Write-Host "    [!] $keyName : removed Deny rule for $($deny.IdentityReference)" -ForegroundColor Yellow
        }

        Set-Acl -Path $key -AclObject $acl -ErrorAction Stop
        $gentle = $true
        Write-Host "[+] $keyName — ACL verified/repaired (gentle)" -ForegroundColor Green

    } catch {
        Write-Host "[-] $keyName — Get-Acl failed ($($_.Exception.Message)), trying nuclear reset..." -ForegroundColor Yellow
    }

    # ── Attempt 2: Nuclear — red team locked ACL so hard we can't read it ──
    if (-not $gentle) {
        try {
            # Take ownership first (required if even Administrators have no access)
            $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                ($key -replace '^HKLM:\\','').Replace('\','\'),
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                [System.Security.AccessControl.RegistryRights]::TakeOwnership)
            if ($regKey) {
                $blank = New-Object System.Security.AccessControl.RegistrySecurity
                $blank.SetOwner([System.Security.Principal.NTAccount]"BUILTIN\Administrators")
                $regKey.SetAccessControl($blank)
                $regKey.Close()
            }

            # Now re-open with ChangePermissions and apply full default ACL
            $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                ($key -replace '^HKLM:\\','').Replace('\','\'),
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                [System.Security.AccessControl.RegistryRights]::ChangePermissions)
            if ($regKey) {
                $nuclearAcl = New-DefenderServiceAcl
                $regKey.SetAccessControl($nuclearAcl)
                $regKey.Close()
                Write-Host "[+] $keyName — ACL rebuilt from scratch (nuclear)" -ForegroundColor Green
            } else {
                Write-Host "[X] $keyName — could not open key even for TakeOwnership" -ForegroundColor Red
            }
        } catch {
            Write-Host "[X] $keyName — nuclear ACL reset failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 1b. Re-enable Defender drivers red team may have disabled (Start=4 means disabled)
# SAFETY: A corrupt/missing boot-start driver (Start=0) = BSOD on reboot.
# We verify binary existence + Microsoft Authenticode signature before touching Start values.
$drivers = @{ "WdFilter" = 0; "WdNisDrv" = 3; "WdBoot" = 0 }
foreach ($drv in $drivers.GetEnumerator()) {
    $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($drv.Key)"

    if (-not (Test-Path $svcPath)) {
        Write-Host "  [i] $($drv.Key) service key missing — skipping" -ForegroundColor Gray
        continue
    }

    $curStart = (Get-ItemProperty $svcPath -Name Start -ErrorAction SilentlyContinue).Start
    if ($curStart -ne 4) {
        Write-Host "  [i] $($drv.Key) Start=$curStart (not disabled) — no change needed" -ForegroundColor Gray
        continue
    }

    # Resolve driver binary path from ImagePath registry value
    $rawImagePath = (Get-ItemProperty $svcPath -Name ImagePath -ErrorAction SilentlyContinue).ImagePath
    if (-not $rawImagePath) {
        Write-Host "  [X] $($drv.Key) has no ImagePath — SKIPPING (cannot verify binary)" -ForegroundColor Red
        Write-Host "      ACTION: Manually inspect HKLM\SYSTEM\CurrentControlSet\Services\$($drv.Key)" -ForegroundColor Red
        continue
    }
    $binaryPath = $rawImagePath -replace '(?i)^\\SystemRoot\\', "$env:SystemRoot\"
    $binaryPath = $binaryPath -replace '(?i)^system32\\', "$env:SystemRoot\System32\"
    $binaryPath = $binaryPath -replace '(?i)^\\\?\?\\', ''
    if ($binaryPath -match '^"([^"]+)"') { $binaryPath = $Matches[1] }

    # Check binary exists
    if (-not (Test-Path $binaryPath)) {
        Write-Host "  [X] $($drv.Key) BINARY MISSING: $binaryPath" -ForegroundColor Red
        Write-Host "      DANGER: Re-enabling would cause BSOD on reboot!" -ForegroundColor Red
        Write-Host "      ACTION: Restore binary (sfc /scannow or DISM), then re-run." -ForegroundColor Red
        continue
    }

    # Check Authenticode signature — must be valid AND signed by Microsoft
    $sig = Get-AuthenticodeSignature -FilePath $binaryPath -ErrorAction SilentlyContinue
    $sigOk = $false
    if ($sig -and $sig.Status -eq 'Valid') {
        if ($sig.SignerCertificate.Subject -match 'O=Microsoft Corporation') {
            $sigOk = $true
        } else {
            Write-Host "  [X] $($drv.Key) signed but NOT by Microsoft: $($sig.SignerCertificate.Subject)" -ForegroundColor Red
            Write-Host "      DANGER: Binary may have been replaced by attacker." -ForegroundColor Red
            Write-Host "      ACTION: Investigate and restore from known-good source." -ForegroundColor Red
            continue
        }
    }
    if (-not $sigOk) {
        $statusText = if ($sig) { $sig.Status } else { "No signature data" }
        Write-Host "  [X] $($drv.Key) signature FAILED: $statusText" -ForegroundColor Red
        Write-Host "      Binary: $binaryPath" -ForegroundColor Red
        Write-Host "      DANGER: Re-enabling a tampered boot-start driver causes BSOD!" -ForegroundColor Red
        Write-Host "      ACTION: Restore binary (sfc /scannow or DISM), then re-run." -ForegroundColor Red
        continue
    }

    # Sanity: reject suspiciously small files
    $fileSize = (Get-Item $binaryPath).Length
    if ($fileSize -lt 1024) {
        Write-Host "  [X] $($drv.Key) binary is only $fileSize bytes — suspiciously small" -ForegroundColor Red
        Write-Host "      ACTION: Investigate before re-enabling." -ForegroundColor Red
        continue
    }

    # All checks passed — safe to re-enable
    try {
        Set-ItemProperty $svcPath -Name Start -Value $drv.Value -ErrorAction Stop
        Write-Host "[+] Re-enabled $($drv.Key) (Start: 4 -> $($drv.Value)) — binary verified OK" -ForegroundColor Green
        Write-Host "    Binary: $binaryPath ($fileSize bytes, Microsoft-signed)" -ForegroundColor Green
        Write-Host "    NOTE: REBOOT REQUIRED for driver changes to take effect." -ForegroundColor Yellow
    } catch {
        Write-Host "[X] Failed to set Start value for $($drv.Key): $_" -ForegroundColor Red
    }
}

# 1c. Re-enable all Defender-related services (with third-party AV guard)
$thirdPartyAV = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue |
    Where-Object { $_.displayName -notmatch 'Windows Defender|Microsoft Defender' }
$services = @("WinDefend", "WdNisSvc", "SecurityHealthService", "wscsvc")
if ($thirdPartyAV) {
    Write-Host "[!] Third-party AV detected — skipping Defender service auto-enable:" -ForegroundColor Yellow
    $thirdPartyAV | ForEach-Object { Write-Host "      $($_.displayName)" -ForegroundColor Yellow }
    Write-Host "    Enabling Defender alongside another AV causes driver conflicts and high CPU." -ForegroundColor Yellow
    Write-Host "    Remove the third-party AV first, then re-run this script." -ForegroundColor Yellow
} else {
    foreach ($svc in $services) {
        $svcObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if (-not $svcObj) {
            Write-Host "  [-] Service $svc does not exist on this machine — skipped" -ForegroundColor Gray
            continue
        }
        $scOut = sc.exe config $svc start= auto 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [+] $svc set to auto-start" -ForegroundColor Green
        } else {
            Write-Host "  [-] Failed to set $svc to auto-start: $scOut" -ForegroundColor Red
        }
    }
}

# 1d. Remove local registry keys that disable Defender outside of GPO
# Detect Tamper Protection state first — if active, direct registry writes are blocked
$tamperStatus = (Get-MpComputerStatus -ErrorAction SilentlyContinue).IsTamperProtected
if ($tamperStatus) {
    Write-Host "  [i] Tamper Protection is ON — registry writes may be blocked (that's good, it means" -ForegroundColor Cyan
    Write-Host "      Defender is protecting itself). Flags set via policy/MpPreference will still work." -ForegroundColor Cyan
}
$disableKeys = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender"; Name = "DisableAntiSpyware" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender"; Name = "DisableAntiVirus" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableRealtimeMonitoring" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableBehaviorMonitoring" }
)
$flagsFound = 0; $flagsCleared = 0; $flagsFailed = 0
foreach ($entry in $disableKeys) {
    $val = Get-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
    if ($null -ne $val -and $val.($entry.Name) -ne $null) {
        $flagsFound++
        Write-Host "  [!] Found $($entry.Name) = $($val.($entry.Name)) at $($entry.Path)" -ForegroundColor Yellow
        try {
            Remove-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction Stop
            # Verify removal
            $check = Get-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
            if ($null -eq $check -or $check.($entry.Name) -eq $null) {
                $flagsCleared++
                Write-Host "      Removed successfully" -ForegroundColor Green
            } else {
                $flagsFailed++
                Write-Host "      Remove-ItemProperty returned success but value persists (Tamper Protection?)" -ForegroundColor Red
            }
        } catch {
            $flagsFailed++
            Write-Host "      Failed to remove: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
if ($flagsFound -eq 0) {
    Write-Host "[+] No local disable flags found (clean)" -ForegroundColor Green
} elseif ($flagsFailed -eq 0) {
    Write-Host "[+] Cleared $flagsCleared/$flagsFound local disable flags" -ForegroundColor Green
} else {
    Write-Host "[-] Cleared $flagsCleared/$flagsFound flags; $flagsFailed failed (Tamper Protection may be blocking — try Set-MpPreference instead)" -ForegroundColor Red
}

# 1e. Boot integrity check (ADVISORY — never auto-change, boot failure risk)
# If disableintegritycheck is set and unsigned boot drivers exist, removing it = BSOD.
# We scan, report, and tell the operator what to do — but do NOT change BCD automatically.
Write-Host "`n--- Boot Integrity Check ---" -ForegroundColor Cyan
$bcdOutput = bcdedit /enum "{current}" 2>&1 | Out-String
$integrityDisabled = $bcdOutput -match 'disableintegritychecks\s+Yes'
$testsigningOn     = $bcdOutput -match 'testsigning\s+Yes'

if ($integrityDisabled) {
    Write-Host "[!] BOOT INTEGRITY CHECKS ARE DISABLED (disableintegritychecks=Yes)" -ForegroundColor Red
    Write-Host "    This may be attacker sabotage OR required for unsigned drivers." -ForegroundColor Yellow

    # Scan boot-start drivers for unsigned binaries to help operator decide
    Write-Host "    Scanning boot-start drivers for unsigned binaries..." -ForegroundColor Yellow
    $unsignedDrivers = @()
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($props.Start -eq 0 -and $props.Type -eq 1) {  # Boot-start kernel drivers
            $drvImgPath = $props.ImagePath
            if (-not $drvImgPath) { return }
            $resolved = $drvImgPath -replace '(?i)^\\SystemRoot\\', "$env:SystemRoot\"
            $resolved = $resolved -replace '(?i)^system32\\', "$env:SystemRoot\System32\"
            $resolved = $resolved -replace '(?i)^\\\?\?\\', ''
            if (Test-Path $resolved) {
                $drvSig = Get-AuthenticodeSignature -FilePath $resolved -ErrorAction SilentlyContinue
                if (-not $drvSig -or $drvSig.Status -ne 'Valid') {
                    $unsignedDrivers += [PSCustomObject]@{
                        Name   = $_.PSChildName
                        Path   = $resolved
                        Status = if ($drvSig) { $drvSig.Status } else { "NoSignature" }
                    }
                }
            }
        }
    }

    if ($unsignedDrivers.Count -gt 0) {
        Write-Host "    WARNING: Found $($unsignedDrivers.Count) unsigned boot-start driver(s):" -ForegroundColor Red
        foreach ($ud in $unsignedDrivers) {
            Write-Host "      - $($ud.Name): $($ud.Path) [$($ud.Status)]" -ForegroundColor Red
        }
        Write-Host "    DO NOT remove disableintegritychecks — it WILL cause BSOD!" -ForegroundColor Red
    } else {
        Write-Host "    All boot-start drivers appear properly signed." -ForegroundColor Green
        Write-Host "    To re-enable integrity checks MANUALLY:" -ForegroundColor Yellow
        Write-Host '      bcdedit /deletevalue "{current}" disableintegritychecks' -ForegroundColor White
        Write-Host '      bcdedit /set "{current}" integrityservices enable' -ForegroundColor White
    }
} else {
    Write-Host "[+] Boot integrity checks already enabled (good)" -ForegroundColor Green
}

if ($testsigningOn) {
    Write-Host "[!] TEST SIGNING IS ENABLED — unsigned drivers can load" -ForegroundColor Red
    Write-Host "    To disable MANUALLY (only if no test-signed drivers needed):" -ForegroundColor Yellow
    Write-Host "      bcdedit /set testsigning off" -ForegroundColor White
} else {
    Write-Host "[+] Test signing not enabled (good)" -ForegroundColor Green
}

# ── Phase 2: Pull GPO and start services ─────────────────────────────────────
gpupdate /force
foreach ($svc in $services) { net start $svc 2>&1 | Out-Null }
Start-Sleep -Seconds 3

# If service still won't start, try MpCmdRun -wdenable
if ((Get-Service WinDefend -ErrorAction SilentlyContinue).Status -ne 'Running') {
    Write-Host "[-] WinDefend not running — trying MpCmdRun -wdenable" -ForegroundColor Yellow
    & "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -wdenable 2>&1 | Out-Null
    Start-Service WinDefend -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

# Re-enable Defender scheduled tasks red team may have disabled
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\*" -ErrorAction SilentlyContinue |
    Enable-ScheduledTask -ErrorAction SilentlyContinue

# Force-enable settings the service may not pick up from registry alone
Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue

# ── ASR: Block credential stealing from LSASS (immediate, no reboot) ─────────
try {
    Add-MpPreference -AttackSurfaceReductionRules_Ids 9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2 -AttackSurfaceReductionRules_Actions Enabled -ErrorAction Stop
    Write-Host "[+] ASR rule enabled: Block credential stealing from LSASS" -ForegroundColor Green
} catch {
    Write-Host "[!] ASR LSASS rule failed (Defender may not be fully functional yet): $_" -ForegroundColor Yellow
}

# ── Phase 3: Nuke ALL exclusions (local prefs + direct registry + policy) ────

# 3-pre. LOG all existing exclusions for forensic evidence before removing
$evidenceFile = "$env:USERPROFILE\Desktop\defender-exclusions-evidence-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$evidenceLines = @("=== Defender Exclusion Evidence Log ===", "Captured: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "Hostname: $env:COMPUTERNAME", "")

# Log from MpPreference (WMI store)
$prefsSnap = Get-MpPreference -ErrorAction SilentlyContinue
if ($prefsSnap) {
    $evidenceLines += "--- MpPreference Exclusions ---"
    @("ExclusionPath","ExclusionProcess","ExclusionExtension","ExclusionIpAddress") | ForEach-Object {
        $vals = @($prefsSnap.$_) | Where-Object { $_ }
        if ($vals) { $vals | ForEach-Object { $evidenceLines += "  [MpPref] ${_}: $_" } }
    }
}

# Log from direct registry (may differ from MpPreference — red team plants here directly)
$exclusionRegKeys = @(
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths",
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes",
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Extensions",
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\TemporaryPaths",
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\IpAddresses",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Processes",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Extensions",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\TemporaryPaths"
)
$evidenceLines += ""
$evidenceLines += "--- Registry Exclusions ---"
foreach ($rk in $exclusionRegKeys) {
    $vals = reg.exe query $rk 2>&1
    if ($LASTEXITCODE -eq 0) {
        $evidenceLines += "  [$rk]"
        $vals | Where-Object { $_ -match 'REG_' } | ForEach-Object { $evidenceLines += "    $_" }
    }
}
$evidenceLines | Out-File -FilePath $evidenceFile -Encoding UTF8
Write-Host "[+] Exclusion evidence saved to $evidenceFile" -ForegroundColor Cyan

# 3a. reg.exe force-clear all exclusion keys (works even with locked ACLs / service down)
$regCleared = 0; $regFailed = 0; $regEmpty = 0
foreach ($rk in $exclusionRegKeys) {
    # Check if key has values first
    $queryOut = reg.exe query $rk 2>&1
    if ($LASTEXITCODE -ne 0) {
        $regEmpty++  # key doesn't exist or no access — nothing to clear
        continue
    }
    $hasValues = $queryOut | Where-Object { $_ -match 'REG_' }
    if (-not $hasValues) {
        $regEmpty++  # key exists but has no values
        continue
    }
    $delOut = reg.exe delete $rk /va /f 2>&1
    if ($LASTEXITCODE -eq 0) {
        $regCleared++
        $keyShort = ($rk -split '\\')[-1]
        $parentShort = ($rk -split '\\')[-2]
        Write-Host "  [+] Cleared $parentShort\$keyShort" -ForegroundColor Green
    } else {
        $regFailed++
        Write-Host "  [-] Failed to clear $rk : $delOut" -ForegroundColor Red
    }
}
if ($regCleared -eq 0 -and $regFailed -eq 0) {
    Write-Host "[+] No exclusion registry values found (already clean)" -ForegroundColor Green
} elseif ($regFailed -gt 0) {
    Write-Host "[-] Registry exclusions: $regCleared cleared, $regFailed failed (Tamper Protection or ACL issue)" -ForegroundColor Red
} else {
    Write-Host "[+] Cleared exclusion values from $regCleared registry keys" -ForegroundColor Green
}

# 3b. Also clean via MpPreference (clears WMI store the cmdlet reads from)
$prefs = Get-MpPreference -ErrorAction SilentlyContinue
$mpCleared = 0; $mpFailed = 0
if ($prefs) {
    $exclusionTypes = @(
        @{ Prop = "ExclusionPath";      Cmd = { param($v) Remove-MpPreference -ExclusionPath $v -ErrorAction Stop } },
        @{ Prop = "ExclusionProcess";   Cmd = { param($v) Remove-MpPreference -ExclusionProcess $v -ErrorAction Stop } },
        @{ Prop = "ExclusionExtension"; Cmd = { param($v) Remove-MpPreference -ExclusionExtension $v -ErrorAction Stop } },
        @{ Prop = "ExclusionIpAddress"; Cmd = { param($v) Remove-MpPreference -ExclusionIpAddress $v -ErrorAction Stop } }
    )
    foreach ($et in $exclusionTypes) {
        @($prefs.($et.Prop)) | Where-Object { $_ } | ForEach-Object {
            try {
                & $et.Cmd $_
                $mpCleared++
                Write-Host "  [+] Removed $($et.Prop): $_" -ForegroundColor Green
            } catch {
                $mpFailed++
                Write-Host "  [-] Failed to remove $($et.Prop) '$_': $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
if ($mpCleared -eq 0 -and $mpFailed -eq 0) {
    Write-Host "[+] No MpPreference exclusions found (already clean)" -ForegroundColor Green
} elseif ($mpFailed -gt 0) {
    Write-Host "[-] MpPreference exclusions: $mpCleared removed, $mpFailed failed" -ForegroundColor Red
} else {
    Write-Host "[+] Removed $mpCleared exclusions via MpPreference" -ForegroundColor Green
}

# ── Phase 4: Update signatures and scan ──────────────────────────────────────
Update-MpSignature -ErrorAction SilentlyContinue
Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue

# ── Phase 5: Verify ──────────────────────────────────────────────────────────
$s = Get-MpComputerStatus -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "=== Defender Status ===" -ForegroundColor Cyan
if ($s) {
    Write-Host "  AMServiceEnabled:        $($s.AMServiceEnabled)"          -ForegroundColor $(if($s.AMServiceEnabled){'Green'}else{'Red'})
    Write-Host "  RealTimeProtection:      $($s.RealTimeProtectionEnabled)" -ForegroundColor $(if($s.RealTimeProtectionEnabled){'Green'}else{'Red'})
    Write-Host "  BehaviorMonitor:         $($s.BehaviorMonitorEnabled)"    -ForegroundColor $(if($s.BehaviorMonitorEnabled){'Green'}else{'Red'})
    Write-Host "  OnAccessProtection:      $($s.OnAccessProtectionEnabled)" -ForegroundColor $(if($s.OnAccessProtectionEnabled){'Green'}else{'Red'})
    Write-Host "  IoavProtection:          $($s.IoavProtectionEnabled)"     -ForegroundColor $(if($s.IoavProtectionEnabled){'Green'}else{'Red'})
    Write-Host "  TamperProtection:        $($s.IsTamperProtected)"        -ForegroundColor $(if($s.IsTamperProtected){'Green'}else{'Red'})
    Write-Host "  AntivirusSignatureAge:   $($s.AntivirusSignatureAge) days" -ForegroundColor $(if($s.AntivirusSignatureAge -le 1){'Green'}else{'Yellow'})
} else {
    Write-Host "  [!] Get-MpComputerStatus failed — Defender may not be installed" -ForegroundColor Red
}

# Check ASR LSASS rule
$asrPrefs = Get-MpPreference -ErrorAction SilentlyContinue
$asrIds = $asrPrefs.AttackSurfaceReductionRules_Ids
$asrActions = $asrPrefs.AttackSurfaceReductionRules_Actions
$lsassRuleId = "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2"
$lsassEnabled = $false
if ($asrIds -and $asrActions) {
    $lsassIdx = [array]::IndexOf($asrIds, $lsassRuleId)
    if ($lsassIdx -ge 0) { $lsassEnabled = ($asrActions[$lsassIdx] -eq 1) }
}
Write-Host "  ASR LSASS Protection:    $lsassEnabled" -ForegroundColor $(if($lsassEnabled){'Green'}else{'Red'})
Write-Host ""

# Check remaining exclusions
$finalPrefs = Get-MpPreference -ErrorAction SilentlyContinue
$exCount = (@($finalPrefs.ExclusionPath) + @($finalPrefs.ExclusionProcess) + @($finalPrefs.ExclusionExtension) |
    Where-Object { $_ }).Count
if ($exCount -gt 0) {
    Write-Host "[WARN] $exCount exclusions still present:" -ForegroundColor Yellow
    @($finalPrefs.ExclusionPath)      | Where-Object { $_ } | ForEach-Object { Write-Host "  Path: $_" -ForegroundColor Yellow }
    @($finalPrefs.ExclusionProcess)   | Where-Object { $_ } | ForEach-Object { Write-Host "  Proc: $_" -ForegroundColor Yellow }
    @($finalPrefs.ExclusionExtension) | Where-Object { $_ } | ForEach-Object { Write-Host "  Ext:  $_" -ForegroundColor Yellow }
} else {
    Write-Host "[OK] No exclusions remain" -ForegroundColor Green
}

if ($s -and $s.AMServiceEnabled -and $s.RealTimeProtectionEnabled) {
    Write-Host "[OK] Defender is fully operational" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Defender is NOT fully operational — see troubleshooting below" -ForegroundColor Red
}
```

> [!NOTE]
> **If Defender still won't start after the script above:**
> 1. **Rogue GPOs on DC:** `gpmc.msc` > look for GPOs disabling Defender under Computer Config > Policies > Admin Templates > Windows Components > Microsoft Defender Antivirus — delete them
> 2. **Competing GPOs:** Run `gpresult /h gpresult.html` on the affected machine — look for any GPO setting `DisableAntiSpyware=1` or exclusions you didn't add
> 3. **Repair Defender binaries:** `sfc /scannow` then `DISM /Online /Cleanup-Image /RestoreHealth`
> 4. **Check for WMI persistence re-disabling Defender:**
>    ```powershell
>    Get-WMIObject -Namespace root\Subscription -Class __EventFilter
>    Get-WMIObject -Namespace root\Subscription -Class CommandLineEventConsumer
>    # Delete anything suspicious
>    ```
> 5. **Nuclear option:** `& "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -wdenable`
> 6. **Reboot required** if drivers were re-enabled in Phase 1 (WdFilter/WdBoot changes only take effect after reboot)

</details>

<details>
<summary><b>7. Install Chainsaw</b> — Download, extract, install to C:\Chainsaw</summary>

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

<details>
<summary><b>8. Chainsaw Triage</b> — Run from C:\Chainsaw, targeted hunts</summary>

All commands assume `cd C:\Chainsaw`. Set `$hoursAgo` to how far back you want to look.

```powershell
cd C:\Chainsaw
$logs = "C:\Windows\System32\winevt\Logs"
$hoursAgo = 10  # ← CHANGE THIS: how many hours back to search
$from = (Get-Date).ToUniversalTime().AddHours(-$hoursAgo).ToString("yyyy-MM-ddTHH:mm:ss")
Write-Host "Searching from: $from (UTC)"
```

#### A. Critical + High hits only (run this first)
Shows only high-confidence detections. Start here.
```powershell
.\chainsaw.exe hunt $logs -s rules/ --mapping mappings/sigma-event-logs-all.yml `
    --level high --from $from --full
```

#### B. Lateral movement
PsExec, WMI, DCOM, remote services, pass-the-hash.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/lateral_movement/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full
```

#### C. Persistence
Scheduled tasks, malicious services, registry run keys.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/persistence/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full
```

#### D. Credential access
LSASS dumps, credential theft, Kerberoasting.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/credential_access/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full
```

#### E. Log tampering / defense evasion
Event log clearing, Defender disabled, audit policy changed.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/log_tampering/ -r rules/evtx/defense_evasion/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full
```

#### F. Suspicious PowerShell
Encoded commands, obfuscation, known tool invocations.
```powershell
.\chainsaw.exe hunt $logs -r rules/evtx/powershell/ `
    --mapping mappings/sigma-event-logs-all.yml --from $from --full
```

#### G. Ansible detection (red team indicator)
If Ansible was run on a box, it's red team. Ansible leaves `ansible-tmp-*` paths and module names in PowerShell/WinRM logs.
```powershell
.\chainsaw.exe search ansible $logs -i --from $from
.\chainsaw.exe search "ansible-tmp" $logs -i --from $from
.\chainsaw.exe search "winrm" $logs -i --from $from
```

#### H. Search for a specific IOC
Replace the search term with whatever you're looking for.
```powershell
# Known tool name
.\chainsaw.exe search mimikatz $logs -i --from $from

# Suspicious username
.\chainsaw.exe search -t "Event.EventData.TargetUserName: =svc_backup" "$logs\Security.evtx" --from $from

# IP address
.\chainsaw.exe search -e "10\.0\.0\.200" $logs --from $from
```

</details>

<details>
<summary><b>9. Rotate All Passwords</b> — Local + AD password reset, saves to CSV</summary>

#### Local accounts (run on every machine)
```powershell
$excludedUsers = @("Administrator", "Guest")
$logFile = "$env:USERPROFILE\Desktop\local_passwords.csv"
"Username,NewPassword" | Out-File -FilePath $logFile

function Generate-RandomPassword {
    param ([int]$length = 20)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+'
    -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}

Get-LocalUser | Where-Object { $_.Enabled -eq $true } | ForEach-Object {
    if ($excludedUsers -contains $_.Name) { Write-Host "Skipping: $($_.Name)" -ForegroundColor Yellow; return }
    $pw = Generate-RandomPassword
    try {
        Set-LocalUser -Name $_.Name -Password (ConvertTo-SecureString $pw -AsPlainText -Force)
        "$($_.Name),$pw" | Out-File -FilePath $logFile -Append
        Write-Host "[+] $($_.Name)" -ForegroundColor Green
    } catch { Write-Host "[-] $($_.Name): $_" -ForegroundColor Red }
}
Write-Host "`n[*] Passwords saved to $logFile" -ForegroundColor Cyan
```

#### AD accounts (DC only)
```powershell
Import-Module ActiveDirectory
$excludedUsers = @("Administrator", "krbtgt")
$logFile = "$env:USERPROFILE\Desktop\domain_passwords.csv"
"Username,NewPassword" | Out-File -FilePath $logFile

function Generate-RandomPassword {
    param ([int]$length = 20)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+'
    -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}

Get-ADUser -Filter * | ForEach-Object {
    if ($excludedUsers -contains $_.SamAccountName) { Write-Host "Skipping: $($_.SamAccountName)" -ForegroundColor Yellow; return }
    $pw = Generate-RandomPassword
    try {
        Set-ADAccountPassword -Identity $_.SamAccountName -Reset -NewPassword (ConvertTo-SecureString $pw -AsPlainText -Force)
        Set-ADUser -Identity $_.SamAccountName -ChangePasswordAtLogon $true
        "$($_.SamAccountName),$pw" | Out-File -FilePath $logFile -Append
        Write-Host "[+] $($_.SamAccountName)" -ForegroundColor Green
    } catch { Write-Host "[-] $($_.SamAccountName): $_" -ForegroundColor Red }
}
Write-Host "`n[*] Passwords saved to $logFile" -ForegroundColor Cyan
```

</details>

---

## Reference

<details>
<summary>WinRM Commands</summary>

```powershell
# FIRST: trust all machines (required when connecting by IP, not hostname)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Check if WinRM is enabled
Get-Service WinRM
Test-WSMan -ComputerName TARGET_IP

# Run on all domain machines at once (run from DC)
$computers = (Get-ADComputer -Filter {OperatingSystem -like "*Windows*"}).Name
$cred = Get-Credential
Invoke-Command -ComputerName $computers -Credential $cred -ScriptBlock {
    # paste your script block here — runs on all machines in parallel
}

# Check if WinRM is enabled on a remote machine
Test-WSMan -ComputerName TARGET_IP

# Check with credentials
$cred = Get-Credential
Test-WSMan -ComputerName TARGET_IP -Authentication Negotiate -Credential $cred

# Open interactive session (like SSH)
Enter-PSSession -ComputerName TARGET_IP -Credential $cred

# Run a single command without a session
Invoke-Command -ComputerName TARGET_IP -Credential $cred -ScriptBlock { hostname }

# Run a script file remotely
Invoke-Command -ComputerName TARGET_IP -Credential $cred -FilePath C:\scripts\myscript.ps1

# ── Run on multiple machines at once ──────────────────────────────────────────
# Hardcoded IPs
Invoke-Command -ComputerName 10.0.0.1,10.0.0.2,10.0.0.3 -Credential $cred -ScriptBlock { Get-Service WinDefend }

# From a text file (one IP/hostname per line)
$computers = Get-Content "C:\computers.txt"
Invoke-Command -ComputerName $computers -Credential $cred -ScriptBlock { hostname }

# From Active Directory (all Windows machines)
$computers = (Get-ADComputer -Filter {OperatingSystem -like "*Windows*"}).Name
Invoke-Command -ComputerName $computers -Credential $cred -ScriptBlock { hostname }

# Throttle if you have many machines (default is 32 at a time)
Invoke-Command -ComputerName $computers -Credential $cred -ThrottleLimit 10 -ScriptBlock { hostname }

# Copy a file to a remote machine
$s = New-PSSession -ComputerName TARGET_IP -Credential $cred
Copy-Item -Path C:\local\file.ps1 -Destination C:\remote\file.ps1 -ToSession $s
Remove-PSSession $s

# Bulk check which machines have WinRM enabled
$machines = @("10.0.0.1","10.0.0.2","10.0.0.3")
foreach ($m in $machines) {
    $r = Test-WSMan -ComputerName $m -ErrorAction SilentlyContinue
    if ($r) { Write-Host "[OK] $m" -ForegroundColor Green }
    else    { Write-Host "[FAIL] $m" -ForegroundColor Red }
}
```

</details>

<details>
<summary>Audit Unwanted Programs & Services</summary>

```powershell
# ============================================================
#  AUDIT: Find programs/services that shouldn't be here
# ============================================================

Write-Host "`n========== UNWANTED SERVICES CHECK ==========" -ForegroundColor Cyan

$suspectServices = @(
    # Web servers
    @{ Name = "W3SVC";        Label = "IIS Web Server" },
    @{ Name = "WAS";          Label = "IIS Process Activation" },
    @{ Name = "IISADMIN";     Label = "IIS Admin" },
    # SQL Server (all common instance names)
    @{ Name = "MSSQLSERVER";  Label = "SQL Server (Default)" },
    @{ Name = "MSSQL`$*";     Label = "SQL Server (Named Instance)" },
    @{ Name = "SQLBrowser";   Label = "SQL Server Browser" },
    @{ Name = "SQLSERVERAGENT"; Label = "SQL Server Agent" },
    @{ Name = "SQLWriter";    Label = "SQL Server VSS Writer" },
    @{ Name = "MsDtsServer*"; Label = "SQL Server Integration Services" },
    @{ Name = "ReportServer*"; Label = "SQL Server Reporting Services" },
    # Remote access / management
    @{ Name = "sshd";         Label = "OpenSSH Server" },
    @{ Name = "WinRM";        Label = "WinRM" },
    @{ Name = "TermService";  Label = "Remote Desktop Services" },
    @{ Name = "TlntSvr";      Label = "Telnet Server" },
    @{ Name = "RemoteRegistry"; Label = "Remote Registry" },
    @{ Name = "RasMan";       Label = "Remote Access Connection Manager" },
    @{ Name = "SNMP";         Label = "SNMP Service" },
    # Package managers / dev tools
    @{ Name = "chocolatey*";  Label = "Chocolatey Agent" },
    # Containers / WSL
    @{ Name = "LxssManager";  Label = "WSL (Windows Subsystem for Linux)" },
    @{ Name = "Docker*";      Label = "Docker" },
    @{ Name = "com.docker*";  Label = "Docker Desktop" },
    # FTP / file sharing
    @{ Name = "FTPSVC";       Label = "FTP Server (IIS)" },
    # Print / misc
    @{ Name = "Spooler";      Label = "Print Spooler" },
    @{ Name = "BITS";         Label = "BITS (Background Transfer)" },
    @{ Name = "XblGameSave";  Label = "Xbox Live" },
    @{ Name = "WSearch";      Label = "Windows Search Indexer" },
    @{ Name = "WMPNetworkSvc"; Label = "Windows Media Sharing" }
)

foreach ($svc in $suspectServices) {
    $found = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    foreach ($s in $found) {
        $status = $s.Status
        $start  = $s.StartType
        $color  = if ($status -eq "Running") { "Red" } elseif ($start -eq "Disabled") { "DarkGray" } else { "Yellow" }
        Write-Host "  [$status / $start] $($svc.Label) ($($s.Name))" -ForegroundColor $color
    }
}

Write-Host "`n========== IIS DETAILS ==========" -ForegroundColor Cyan
$iis = Get-Service W3SVC -ErrorAction SilentlyContinue
if ($iis) {
    $ver = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction SilentlyContinue).VersionString
    Write-Host "  IIS installed — Version: $ver — Status: $($iis.Status)" -ForegroundColor Red
    try {
        Import-Module WebAdministration -ErrorAction SilentlyContinue
        Get-Website | ForEach-Object { Write-Host "    Site: $($_.Name) — State: $($_.State) — Bindings: $($_.Bindings.Collection.bindingInformation)" -ForegroundColor Yellow }
    } catch { Write-Host "    (Could not enumerate sites)" -ForegroundColor DarkGray }
} else {
    Write-Host "  IIS not installed" -ForegroundColor Green
}

Write-Host "`n========== SQL SERVER DETAILS ==========" -ForegroundColor Cyan
$sqlInstances = Get-Service -Name "MSSQL`$*","MSSQLSERVER" -ErrorAction SilentlyContinue
if ($sqlInstances) {
    foreach ($inst in $sqlInstances) {
        Write-Host "  Instance: $($inst.Name) — Status: $($inst.Status)" -ForegroundColor Red
    }
    $sqlKeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server" -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match "^\d+$" }
    foreach ($k in $sqlKeys) {
        $setup = Get-ItemProperty "$($k.PSPath)\MSSQLServer\CurrentVersion" -ErrorAction SilentlyContinue
        if ($setup) { Write-Host "  Version: $($setup.CurrentVersion)" -ForegroundColor Yellow }
    }
} else {
    Write-Host "  SQL Server not installed" -ForegroundColor Green
}

Write-Host "`n========== INSTALLED BROWSERS ==========" -ForegroundColor Cyan
$browsers = @(
    @{ Path = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"; Name = "Google Chrome" },
    @{ Path = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"; Name = "Google Chrome (x86)" },
    @{ Path = "${env:ProgramFiles}\Mozilla Firefox\firefox.exe"; Name = "Mozilla Firefox" },
    @{ Path = "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"; Name = "Mozilla Firefox (x86)" },
    @{ Path = "${env:ProgramFiles}\BraveSoftware\Brave-Browser\Application\brave.exe"; Name = "Brave" },
    @{ Path = "${env:LocalAppData}\Microsoft\Edge\Application\msedge.exe"; Name = "Microsoft Edge" }
)
foreach ($b in $browsers) {
    if (Test-Path $b.Path) {
        $ver = (Get-Item $b.Path).VersionInfo.FileVersion
        Write-Host "  [FOUND] $($b.Name) — v$ver" -ForegroundColor Yellow
    }
}

Write-Host "`n========== WSL CHECK ==========" -ForegroundColor Cyan
$wsl = Get-Service LxssManager -ErrorAction SilentlyContinue
if ($wsl -and $wsl.Status -eq "Running") {
    Write-Host "  WSL is running" -ForegroundColor Red
    try { $distros = wsl --list --quiet 2>$null; if ($distros) { $distros | ForEach-Object { Write-Host "    Distro: $_" -ForegroundColor Yellow } } } catch {}
} else {
    Write-Host "  WSL not running" -ForegroundColor Green
}

Write-Host "`n========== CHOCOLATEY CHECK ==========" -ForegroundColor Cyan
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "  Chocolatey is installed" -ForegroundColor Red
    choco list --local-only 2>$null | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
} else {
    Write-Host "  Chocolatey not installed" -ForegroundColor Green
}

Write-Host "`n========== LISTENING PORTS (non-standard) ==========" -ForegroundColor Cyan
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -notin @(135,139,389,445,636,3389,5985,88,53,464,9389) } |
    Sort-Object LocalPort -Unique |
    ForEach-Object {
        $proc = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        Write-Host "  :$($_.LocalPort) — $proc (PID $($_.OwningProcess))" -ForegroundColor Yellow
    }
```

</details>

<details>
<summary>Disable Unwanted Programs & Services</summary>

```powershell
# ============================================================
#  DISABLE: Stop and disable chosen services
#  Comment out any lines you want to KEEP running
# ============================================================

$toDisable = @(
    # Web servers
    "W3SVC",            # IIS Web Server
    "WAS",              # IIS Process Activation
    "IISADMIN",         # IIS Admin
    "FTPSVC",           # FTP Server
    # SQL Server — uncomment ONLY if SQL is not a scored service
    # "MSSQLSERVER",    # SQL Server (Default)
    # "SQLSERVERAGENT", # SQL Server Agent
    # "SQLBrowser",     # SQL Server Browser
    # Remote access
    "TlntSvr",          # Telnet
    "RemoteRegistry",   # Remote Registry
    "SNMP",             # SNMP
    "RasMan",           # Remote Access
    # WSL / containers
    "LxssManager",      # WSL
    # "Docker*",        # Docker
    # Misc
    "Spooler",          # Print Spooler
    "WMPNetworkSvc",    # Windows Media Sharing
    "XblGameSave"       # Xbox Live
)

Write-Host "`n========== DISABLING SERVICES ==========" -ForegroundColor Cyan
foreach ($name in $toDisable) {
    $services = Get-Service -Name $name -ErrorAction SilentlyContinue
    foreach ($svc in $services) {
        try {
            if ($svc.Status -eq "Running") { Stop-Service -Name $svc.Name -Force -ErrorAction Stop }
            Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop
            Write-Host "  [DISABLED] $($svc.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  [FAILED] $($svc.Name) — $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Uninstall Chocolatey if present
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "`n  Removing Chocolatey..." -ForegroundColor Yellow
    try {
        $chocoPath = "$env:ProgramData\chocolatey"
        Remove-Item -Path $chocoPath -Recurse -Force -ErrorAction Stop
        [System.Environment]::SetEnvironmentVariable("ChocolateyInstall", $null, "Machine")
        Write-Host "  [REMOVED] Chocolatey" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED] Chocolatey removal — $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Disable WSL feature
$wsl = Get-Service LxssManager -ErrorAction SilentlyContinue
if ($wsl) {
    Write-Host "`n  Disabling WSL feature..." -ForegroundColor Yellow
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -ErrorAction Stop
        Write-Host "  [DISABLED] WSL feature" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED] WSL disable — $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n[+] Done. Review output above for failures." -ForegroundColor Cyan
```

</details>

<details>
<summary>Ansible Setup — WinRM, install, inventory, playbooks</summary>

#### Enable WinRM on each Windows machine (required before Ansible can connect)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\Enable-WinRM.ps1
```

#### Manual WinRM enable methods (if script fails)

**Quick enable (HTTP, port 5985):**
```powershell
Enable-PSRemoting -Force -SkipNetworkProfileCheck
winrm quickconfig -q
```

**Enable with HTTPS (port 5986):**
```powershell
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:COMPUTERNAME`";CertificateThumbprint=`"$($cert.Thumbprint)`"}"
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
```

**Enable via service only (no listener config):**
```powershell
Set-Service WinRM -StartupType Automatic
Start-Service WinRM
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

**Allow unencrypted (use only if HTTPS isn't an option):**
```powershell
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
```

**Firewall rules:**
```powershell
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
```

#### Test WinRM from a remote machine

**From another Windows machine:**
```powershell
Test-WSMan -ComputerName TARGET_IP
Test-WSMan -ComputerName TARGET_IP -UseSSL -ErrorAction SilentlyContinue
$cred = Get-Credential
Test-WSMan -ComputerName TARGET_IP -Authentication Negotiate -Credential $cred
Enter-PSSession -ComputerName TARGET_IP -Credential $cred
Invoke-Command -ComputerName TARGET_IP -Credential $cred -ScriptBlock { hostname }
```

**From Linux (Ansible control node):**
```bash
nc -zv TARGET_IP 5985
nc -zv TARGET_IP 5986
ansible TARGET_IP -i "TARGET_IP," -m win_ping \
  -e "ansible_user=Administrator ansible_password=PASS ansible_connection=winrm ansible_port=5985 ansible_winrm_transport=ntlm ansible_winrm_server_cert_validation=ignore"
curl -s http://TARGET_IP:5985/wsman
```

**Bulk test all machines:**
```powershell
$machines = @("10.0.0.1","10.0.0.2","10.0.0.3")
foreach ($m in $machines) {
    $result = Test-WSMan -ComputerName $m -ErrorAction SilentlyContinue
    if ($result) {
        Write-Host "[OK] $m — WinRM reachable" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $m — WinRM not reachable" -ForegroundColor Red
    }
}
```

#### Install Ansible (On Ubuntu Control Node)
```bash
sudo apt update && sudo apt install python3-pip -y
python3 -m pip install --user ansible pywinrm
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

#### Configure inventory & run playbook

```bash
cd /path/to/ccdc2026/Platform-Windows/ansible
nano inventory/inventory.ini
```

Add your Windows machines:
```ini
[windows]
IP_ADDRESS ansible_user=Administrator ansible_password=PASSWORD

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

<details>
<summary>RDP Commands</summary>

```powershell
# Check if RDP is enabled on a remote machine (port test)
Test-NetConnection -ComputerName TARGET_IP -Port 3389

# Bulk check which machines have RDP enabled
$machines = @("10.0.0.1","10.0.0.2","10.0.0.3")
foreach ($m in $machines) {
    $r = Test-NetConnection -ComputerName $m -Port 3389 -WarningAction SilentlyContinue
    if ($r.TcpTestSucceeded) { Write-Host "[OK] $m — RDP open" -ForegroundColor Green }
    else                     { Write-Host "[FAIL] $m — RDP closed" -ForegroundColor Red }
}

# Check RDP settings on a remote machine via WinRM
Invoke-Command -ComputerName TARGET_IP -Credential $cred -ScriptBlock {
    $rdp = Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections
    if ($rdp.fDenyTSConnections -eq 0) { Write-Host "RDP: ENABLED" -ForegroundColor Green }
    else { Write-Host "RDP: DISABLED" -ForegroundColor Red }
}

# Enable RDP on a remote machine via WinRM
Invoke-Command -ComputerName TARGET_IP -Credential $cred -ScriptBlock {
    Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Write-Host "[+] RDP enabled" -ForegroundColor Green
}
```

</details>

<details>
<summary>Sysmon Commands</summary>

```powershell
# Check if Sysmon is running
Get-Service Sysmon64

# Check Sysmon config
& C:\Sysinternals\Sysmon64.exe -c

# Restart Sysmon if stopped
Start-Service Sysmon64

# Update Sysmon config
& C:\Sysinternals\Sysmon64.exe -c C:\path\to\new-config.xml
```

</details>

<details>
<summary>Enable Defender (Local, No GPO Needed)</summary>

```powershell
# ── Preflight checks ─────────────────────────────────────────────────────────
Write-Host "=== Preflight ===" -ForegroundColor Cyan

# Binaries exist?
# WinDefend service exists?
$defSvc = Get-Service WinDefend -ErrorAction SilentlyContinue
if (-not $defSvc) {
    Write-Host "  WinDefend service:       MISSING" -ForegroundColor Red
    Write-Host ""
    Write-Host "[!] Defender is not installed. Run these manually (slow, may impact services):" -ForegroundColor Red
    Write-Host "      Install-WindowsFeature -Name Windows-Defender -IncludeManagementTools  # Server only" -ForegroundColor Yellow
    Write-Host "      sfc /scannow" -ForegroundColor Yellow
    Write-Host "      DISM /Online /Cleanup-Image /RestoreHealth" -ForegroundColor Yellow
    Write-Host "    Then re-run this script." -ForegroundColor Red
    Write-Host ""
    return
}
Write-Host "  WinDefend service:       Present ($($defSvc.Status))" -ForegroundColor $(if($defSvc.Status -eq 'Running'){'Green'}else{'Yellow'})

# Engine binary exists? (check actual path from service, not hardcoded)
$imgPath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" -Name ImagePath -EA SilentlyContinue).ImagePath -replace '"',''
$engExists = $imgPath -and (Test-Path $imgPath)
Write-Host "  Engine binary:           $(if($engExists){'OK'}else{'MISSING'}) ($imgPath)" -ForegroundColor $(if($engExists){'Green'}else{'Red'})
if (-not $engExists) {
    Write-Host ""
    Write-Host "[!] Defender binary missing or corrupted. Run these manually (slow, may impact services):" -ForegroundColor Red
    Write-Host "      sfc /scannow" -ForegroundColor Yellow
    Write-Host "      DISM /Online /Cleanup-Image /RestoreHealth" -ForegroundColor Yellow
    Write-Host "    Then re-run this script." -ForegroundColor Red
    Write-Host ""
    return
}

# Feature installed? (Server only — silently skips on workstations)
$feat = Get-WindowsFeature -Name Windows-Defender* -ErrorAction SilentlyContinue
if ($feat -and $feat.InstallState -ne 'Installed') {
    Write-Host "  Windows-Defender feature: $($feat.InstallState)" -ForegroundColor Red
    Write-Host ""
    Write-Host "[!] Defender feature not installed. Run manually (may require reboot):" -ForegroundColor Red
    Write-Host "      Install-WindowsFeature -Name Windows-Defender -IncludeManagementTools" -ForegroundColor Yellow
    Write-Host "    Then re-run this script." -ForegroundColor Red
    Write-Host ""
    return
} elseif ($feat) {
    Write-Host "  Windows-Defender feature: $($feat.InstallState)" -ForegroundColor Green
}

# Services
foreach ($sn in @("WinDefend","WdNisSvc")) {
    $st = (sc.exe query $sn 2>&1 | Select-String "STATE").ToString().Trim()
    Write-Host "  ${sn}: $st" -ForegroundColor $(if($st -match 'RUNNING'){'Green'}else{'Yellow'})
}

# Drivers
foreach ($dn in @("WdFilter","WdBoot","WdNisDrv")) {
    $dv = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$dn" -Name Start -EA SilentlyContinue).Start
    $disabled = $dv -eq 4
    Write-Host "  Driver ${dn}: Start=$dv$(if($disabled){' (DISABLED)'})" -ForegroundColor $(if($disabled){'Red'}else{'Green'})
}

# Policy disable flags
$polDis = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -EA SilentlyContinue).DisableAntiSpyware
$locDis = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Defender" -EA SilentlyContinue).DisableAntiSpyware
if ($polDis -eq 1) { Write-Host "  [!] Policy DisableAntiSpyware = 1 (will fix)" -ForegroundColor Red }
if ($locDis -eq 1) { Write-Host "  [!] Local DisableAntiSpyware = 1 (will fix)" -ForegroundColor Red }

# Exclusions planted
$mp = Get-MpPreference -ErrorAction SilentlyContinue
$exTotal = (@($mp.ExclusionPath) + @($mp.ExclusionProcess) + @($mp.ExclusionExtension) + @($mp.ExclusionIpAddress) | Where-Object { $_ }).Count
Write-Host "  Exclusions planted:      $exTotal" -ForegroundColor $(if($exTotal -eq 0){'Green'}else{'Red'})

Write-Host ""

# ── Fix sabotage ─────────────────────────────────────────────────────────────

# Reset ACLs on Defender service keys (gentle-first, nuclear fallback)
$svcKeys = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WdFilter",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisDrv",
    "HKLM:\SYSTEM\CurrentControlSet\Services\WdBoot",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService",
    "HKLM:\SYSTEM\CurrentControlSet\Services\wscsvc"
)
function New-DefenderServiceAcl {
    $a = New-Object System.Security.AccessControl.RegistrySecurity
    $a.SetAccessRuleProtection($false, $true)
    $a.SetOwner([System.Security.Principal.NTAccount]"NT AUTHORITY\SYSTEM")
    @(
        @("NT AUTHORITY\SYSTEM",          "FullControl","ContainerInherit,ObjectInherit","None","Allow"),
        @("BUILTIN\Administrators",       "FullControl","ContainerInherit,ObjectInherit","None","Allow"),
        @("NT SERVICE\TrustedInstaller",  "FullControl","ContainerInherit,ObjectInherit","None","Allow"),
        @("CREATOR OWNER",                "FullControl","ContainerInherit,ObjectInherit","InheritOnly","Allow"),
        @("BUILTIN\Users",                "ReadKey",    "ContainerInherit,ObjectInherit","None","Allow"),
        @("APPLICATION PACKAGE AUTHORITY\ALL APPLICATION PACKAGES","ReadKey","ContainerInherit,ObjectInherit","None","Allow"),
        @("APPLICATION PACKAGE AUTHORITY\ALL RESTRICTED APPLICATION PACKAGES","ReadKey","ContainerInherit,ObjectInherit","None","Allow")
    ) | ForEach-Object {
        try { $a.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule($_[0],$_[1],$_[2],$_[3],$_[4]))) } catch {}
    }
    return $a
}
foreach ($key in $svcKeys) {
    if (-not (Test-Path $key)) { continue }
    $kn = ($key -split '\\')[-1]; $gentle = $false
    try {
        $acl = Get-Acl -Path $key -ErrorAction Stop
        if ($acl.AreAccessRulesProtected) { $acl.SetAccessRuleProtection($false, $true) }
        foreach ($id in @("NT AUTHORITY\SYSTEM","BUILTIN\Administrators")) {
            if (-not ($acl.Access | Where-Object { $_.IdentityReference -eq $id -and $_.RegistryRights -band [System.Security.AccessControl.RegistryRights]::FullControl })) {
                $acl.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule($id,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
            }
        }
        $acl.Access | Where-Object { $_.AccessControlType -eq 'Deny' } | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
        Set-Acl -Path $key -AclObject $acl -ErrorAction Stop; $gentle = $true
    } catch {}
    if (-not $gentle) {
        try {
            $rk = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(($key -replace '^HKLM:\\','').Replace('\','\'),
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::TakeOwnership)
            if ($rk) { $b = New-Object System.Security.AccessControl.RegistrySecurity; $b.SetOwner([System.Security.Principal.NTAccount]"BUILTIN\Administrators"); $rk.SetAccessControl($b); $rk.Close() }
            $rk = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(($key -replace '^HKLM:\\','').Replace('\','\'),
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
            if ($rk) { $rk.SetAccessControl((New-DefenderServiceAcl)); $rk.Close() }
        } catch {}
    }
}

# Re-enable Defender drivers (safe — verify binary + Microsoft signature first)
$drivers = @{ "WdFilter" = 0; "WdNisDrv" = 3; "WdBoot" = 0 }
foreach ($drv in $drivers.GetEnumerator()) {
    $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($drv.Key)"
    if (-not (Test-Path $svcPath)) { continue }
    $curStart = (Get-ItemProperty $svcPath -Name Start -ErrorAction SilentlyContinue).Start
    if ($curStart -ne 4) { continue }

    $rawImagePath = (Get-ItemProperty $svcPath -Name ImagePath -ErrorAction SilentlyContinue).ImagePath
    if (-not $rawImagePath) {
        Write-Host "  [X] $($drv.Key) has no ImagePath — SKIPPING" -ForegroundColor Red; continue
    }
    $bp = $rawImagePath -replace '(?i)^\\SystemRoot\\', "$env:SystemRoot\"
    $bp = $bp -replace '(?i)^system32\\', "$env:SystemRoot\System32\"
    $bp = $bp -replace '(?i)^\\\?\?\\', ''
    if ($bp -match '^"([^"]+)"') { $bp = $Matches[1] }

    if (-not (Test-Path $bp)) {
        Write-Host "  [X] $($drv.Key) BINARY MISSING: $bp — BSOD risk, skipping" -ForegroundColor Red; continue
    }
    $sig = Get-AuthenticodeSignature -FilePath $bp -ErrorAction SilentlyContinue
    if (-not $sig -or $sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        Write-Host "  [X] $($drv.Key) signature invalid — skipping (possible tampering)" -ForegroundColor Red; continue
    }
    if ((Get-Item $bp).Length -lt 1024) {
        Write-Host "  [X] $($drv.Key) binary suspiciously small — skipping" -ForegroundColor Red; continue
    }

    try {
        Set-ItemProperty $svcPath -Name Start -Value $drv.Value -ErrorAction Stop
        Write-Host "[+] Re-enabled $($drv.Key) (verified Microsoft-signed) — REBOOT NEEDED" -ForegroundColor Green
    } catch {
        Write-Host "[X] Failed to re-enable $($drv.Key): $_" -ForegroundColor Red
    }
}

# Set services to auto-start (with third-party AV guard)
$thirdPartyAV = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue |
    Where-Object { $_.displayName -notmatch 'Windows Defender|Microsoft Defender' }
$services = @("WinDefend", "WdNisSvc", "SecurityHealthService", "wscsvc")
if ($thirdPartyAV) {
    Write-Host "[!] Third-party AV detected — skipping Defender service auto-enable:" -ForegroundColor Yellow
    $thirdPartyAV | ForEach-Object { Write-Host "      $($_.displayName)" -ForegroundColor Yellow }
    Write-Host "    Enabling Defender alongside another AV causes driver conflicts and high CPU." -ForegroundColor Yellow
    Write-Host "    Remove the third-party AV first, then re-run this script." -ForegroundColor Yellow
} else {
    foreach ($svc in $services) {
        $svcObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if (-not $svcObj) {
            Write-Host "  [-] Service $svc does not exist on this machine — skipped" -ForegroundColor Gray
            continue
        }
        $scOut = sc.exe config $svc start= auto 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [+] $svc set to auto-start" -ForegroundColor Green
        } else {
            Write-Host "  [-] Failed to set $svc to auto-start: $scOut" -ForegroundColor Red
        }
    }
}

# Boot integrity check (advisory only — never auto-change, boot failure risk)
$bcdOut = bcdedit /enum "{current}" 2>&1 | Out-String
if ($bcdOut -match 'disableintegritychecks\s+Yes') {
    Write-Host "[!] Boot integrity checks DISABLED — may be attacker or required for unsigned drivers" -ForegroundColor Red
    Write-Host "    Check boot-start drivers before fixing. Manual commands if safe:" -ForegroundColor Yellow
    Write-Host '      bcdedit /deletevalue "{current}" disableintegritychecks' -ForegroundColor White
    Write-Host '      bcdedit /set "{current}" integrityservices enable' -ForegroundColor White
} else {
    Write-Host "[+] Boot integrity checks enabled (good)" -ForegroundColor Green
}
if ($bcdOut -match 'testsigning\s+Yes') {
    Write-Host "[!] Test signing enabled — unsigned drivers can load" -ForegroundColor Red
    Write-Host "    Manual fix: bcdedit /set testsigning off" -ForegroundColor Yellow
}

# ── Enable Defender locally (replaces what GPO would do) ─────────────────────

# Remove local disable keys (with Tamper Protection awareness and per-flag reporting)
$tamperStatus = (Get-MpComputerStatus -ErrorAction SilentlyContinue).IsTamperProtected
if ($tamperStatus) {
    Write-Host "  [i] Tamper Protection is ON — registry writes may be blocked (that's good, it means" -ForegroundColor Cyan
    Write-Host "      Defender is protecting itself). Flags set via policy/MpPreference will still work." -ForegroundColor Cyan
}
$disableKeys = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender"; Name = "DisableAntiSpyware" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender"; Name = "DisableAntiVirus" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableRealtimeMonitoring" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableBehaviorMonitoring" }
)
$flagsFound = 0; $flagsCleared = 0; $flagsFailed = 0
foreach ($entry in $disableKeys) {
    $val = Get-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
    if ($null -ne $val -and $val.($entry.Name) -ne $null) {
        $flagsFound++
        Write-Host "  [!] Found $($entry.Name) = $($val.($entry.Name)) at $($entry.Path)" -ForegroundColor Yellow
        try {
            Remove-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction Stop
            $check = Get-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
            if ($null -eq $check -or $check.($entry.Name) -eq $null) {
                $flagsCleared++
                Write-Host "      Removed successfully" -ForegroundColor Green
            } else {
                $flagsFailed++
                Write-Host "      Remove-ItemProperty returned success but value persists (Tamper Protection?)" -ForegroundColor Red
            }
        } catch {
            $flagsFailed++
            Write-Host "      Failed to remove: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
if ($flagsFound -eq 0) {
    Write-Host "[+] No local disable flags found (clean)" -ForegroundColor Green
} elseif ($flagsFailed -eq 0) {
    Write-Host "[+] Cleared $flagsCleared/$flagsFound local disable flags" -ForegroundColor Green
} else {
    Write-Host "[-] Cleared $flagsCleared/$flagsFound flags; $flagsFailed failed (Tamper Protection may be blocking)" -ForegroundColor Red
}

# Set policy-level registry keys to enable Defender (what GPO normally does)
$polKeys = @(
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"; Name = "DisableAntiSpyware"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"; Name = "DisableAntiVirus"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableRealtimeMonitoring"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableBehaviorMonitoring"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableOnAccessProtection"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableScanOnRealtimeEnable"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name = "DisableIOAVProtection"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"; Name = "SpynetReporting"; Value = 2 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine"; Name = "MpEnablePus"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Features"; Name = "TamperProtection"; Value = 5 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions"; Name = "DisableAutoExclusions"; Value = 1 }
)
foreach ($k in $polKeys) {
    New-Item -Path $k.Path -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $k.Path -Name $k.Name -Value $k.Value -Type DWord -Force
}

# ── Start services ───────────────────────────────────────────────────────────
foreach ($svc in $services) { net start $svc 2>&1 | Out-Null }
Start-Sleep -Seconds 3

# If service still won't start, try MpCmdRun -wdenable
if ((Get-Service WinDefend -ErrorAction SilentlyContinue).Status -ne 'Running') {
    Write-Host "[-] WinDefend not running — trying MpCmdRun -wdenable" -ForegroundColor Yellow
    & "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -wdenable 2>&1 | Out-Null
    Start-Service WinDefend -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

# Re-enable Defender scheduled tasks
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\*" -ErrorAction SilentlyContinue |
    Enable-ScheduledTask -ErrorAction SilentlyContinue

# Force-enable settings the service may not pick up from registry alone
Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue

# ── ASR: Block credential stealing from LSASS (immediate, no reboot) ─────────
try {
    Add-MpPreference -AttackSurfaceReductionRules_Ids 9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2 -AttackSurfaceReductionRules_Actions Enabled -ErrorAction Stop
    Write-Host "[+] ASR rule enabled: Block credential stealing from LSASS" -ForegroundColor Green
} catch {
    Write-Host "[!] ASR LSASS rule failed (Defender may not be fully functional yet): $_" -ForegroundColor Yellow
}

# ── Nuke exclusions (with forensic logging and accurate reporting) ───────────

# Log all existing exclusions for forensic evidence before removing
$evidenceFile = "$env:USERPROFILE\Desktop\defender-exclusions-evidence-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$evidenceLines = @("=== Defender Exclusion Evidence Log ===", "Captured: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "Hostname: $env:COMPUTERNAME", "")

$prefsSnap = Get-MpPreference -ErrorAction SilentlyContinue
if ($prefsSnap) {
    $evidenceLines += "--- MpPreference Exclusions ---"
    @("ExclusionPath","ExclusionProcess","ExclusionExtension","ExclusionIpAddress") | ForEach-Object {
        $vals = @($prefsSnap.$_) | Where-Object { $_ }
        if ($vals) { $vals | ForEach-Object { $evidenceLines += "  [MpPref] ${_}: $_" } }
    }
}

$exclusionRegKeys = @(
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths",
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes",
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Extensions",
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\TemporaryPaths",
    "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\IpAddresses",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Processes",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Extensions",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\TemporaryPaths"
)
$evidenceLines += ""
$evidenceLines += "--- Registry Exclusions ---"
foreach ($rk in $exclusionRegKeys) {
    $vals = reg.exe query $rk 2>&1
    if ($LASTEXITCODE -eq 0) {
        $evidenceLines += "  [$rk]"
        $vals | Where-Object { $_ -match 'REG_' } | ForEach-Object { $evidenceLines += "    $_" }
    }
}
$evidenceLines | Out-File -FilePath $evidenceFile -Encoding UTF8
Write-Host "[+] Exclusion evidence saved to $evidenceFile" -ForegroundColor Cyan

# reg.exe force-clear all exclusion keys (works even with locked ACLs / service down)
$regCleared = 0; $regFailed = 0; $regEmpty = 0
foreach ($rk in $exclusionRegKeys) {
    $queryOut = reg.exe query $rk 2>&1
    if ($LASTEXITCODE -ne 0) { $regEmpty++; continue }
    $hasValues = $queryOut | Where-Object { $_ -match 'REG_' }
    if (-not $hasValues) { $regEmpty++; continue }
    $delOut = reg.exe delete $rk /va /f 2>&1
    if ($LASTEXITCODE -eq 0) {
        $regCleared++
        $keyShort = ($rk -split '\\')[-1]
        $parentShort = ($rk -split '\\')[-2]
        Write-Host "  [+] Cleared $parentShort\$keyShort" -ForegroundColor Green
    } else {
        $regFailed++
        Write-Host "  [-] Failed to clear $rk : $delOut" -ForegroundColor Red
    }
}
if ($regCleared -eq 0 -and $regFailed -eq 0) {
    Write-Host "[+] No exclusion registry values found (already clean)" -ForegroundColor Green
} elseif ($regFailed -gt 0) {
    Write-Host "[-] Registry exclusions: $regCleared cleared, $regFailed failed (Tamper Protection or ACL issue)" -ForegroundColor Red
} else {
    Write-Host "[+] Cleared exclusion values from $regCleared registry keys" -ForegroundColor Green
}

# Also clean via MpPreference (clears WMI store the cmdlet reads from)
$prefs = Get-MpPreference -ErrorAction SilentlyContinue
$mpCleared = 0; $mpFailed = 0
if ($prefs) {
    $exclusionTypes = @(
        @{ Prop = "ExclusionPath";      Cmd = { param($v) Remove-MpPreference -ExclusionPath $v -ErrorAction Stop } },
        @{ Prop = "ExclusionProcess";   Cmd = { param($v) Remove-MpPreference -ExclusionProcess $v -ErrorAction Stop } },
        @{ Prop = "ExclusionExtension"; Cmd = { param($v) Remove-MpPreference -ExclusionExtension $v -ErrorAction Stop } },
        @{ Prop = "ExclusionIpAddress"; Cmd = { param($v) Remove-MpPreference -ExclusionIpAddress $v -ErrorAction Stop } }
    )
    foreach ($et in $exclusionTypes) {
        @($prefs.($et.Prop)) | Where-Object { $_ } | ForEach-Object {
            try {
                & $et.Cmd $_
                $mpCleared++
                Write-Host "  [+] Removed $($et.Prop): $_" -ForegroundColor Green
            } catch {
                $mpFailed++
                Write-Host "  [-] Failed to remove $($et.Prop) '$_': $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
if ($mpCleared -eq 0 -and $mpFailed -eq 0) {
    Write-Host "[+] No MpPreference exclusions found (already clean)" -ForegroundColor Green
} elseif ($mpFailed -gt 0) {
    Write-Host "[-] MpPreference exclusions: $mpCleared removed, $mpFailed failed" -ForegroundColor Red
} else {
    Write-Host "[+] Removed $mpCleared exclusions via MpPreference" -ForegroundColor Green
}

# ── Update and scan ──────────────────────────────────────────────────────────
Update-MpSignature -ErrorAction SilentlyContinue
Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue

# ── Verify ───────────────────────────────────────────────────────────────────
$s = Get-MpComputerStatus -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "=== Defender Status ===" -ForegroundColor Cyan
if ($s) {
    Write-Host "  AMServiceEnabled:        $($s.AMServiceEnabled)"          -ForegroundColor $(if($s.AMServiceEnabled){'Green'}else{'Red'})
    Write-Host "  RealTimeProtection:      $($s.RealTimeProtectionEnabled)" -ForegroundColor $(if($s.RealTimeProtectionEnabled){'Green'}else{'Red'})
    Write-Host "  BehaviorMonitor:         $($s.BehaviorMonitorEnabled)"    -ForegroundColor $(if($s.BehaviorMonitorEnabled){'Green'}else{'Red'})
    Write-Host "  OnAccessProtection:      $($s.OnAccessProtectionEnabled)" -ForegroundColor $(if($s.OnAccessProtectionEnabled){'Green'}else{'Red'})
    Write-Host "  IoavProtection:          $($s.IoavProtectionEnabled)"     -ForegroundColor $(if($s.IoavProtectionEnabled){'Green'}else{'Red'})
    Write-Host "  TamperProtection:        $($s.IsTamperProtected)"        -ForegroundColor $(if($s.IsTamperProtected){'Green'}else{'Red'})
    Write-Host "  AntivirusSignatureAge:   $($s.AntivirusSignatureAge) days" -ForegroundColor $(if($s.AntivirusSignatureAge -le 1){'Green'}else{'Yellow'})
} else {
    Write-Host "  [!] Get-MpComputerStatus failed — Defender may not be installed" -ForegroundColor Red
}

# Check ASR LSASS rule
$asrPrefs = Get-MpPreference -ErrorAction SilentlyContinue
$asrIds = $asrPrefs.AttackSurfaceReductionRules_Ids
$asrActions = $asrPrefs.AttackSurfaceReductionRules_Actions
$lsassRuleId = "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2"
$lsassEnabled = $false
if ($asrIds -and $asrActions) {
    $lsassIdx = [array]::IndexOf($asrIds, $lsassRuleId)
    if ($lsassIdx -ge 0) { $lsassEnabled = ($asrActions[$lsassIdx] -eq 1) }
}
Write-Host "  ASR LSASS Protection:    $lsassEnabled" -ForegroundColor $(if($lsassEnabled){'Green'}else{'Red'})
Write-Host ""

# Check remaining exclusions
$finalPrefs = Get-MpPreference -ErrorAction SilentlyContinue
$exCount = (@($finalPrefs.ExclusionPath) + @($finalPrefs.ExclusionProcess) + @($finalPrefs.ExclusionExtension) |
    Where-Object { $_ }).Count
if ($exCount -gt 0) {
    Write-Host "[WARN] $exCount exclusions still present:" -ForegroundColor Yellow
    @($finalPrefs.ExclusionPath)      | Where-Object { $_ } | ForEach-Object { Write-Host "  Path: $_" -ForegroundColor Yellow }
    @($finalPrefs.ExclusionProcess)   | Where-Object { $_ } | ForEach-Object { Write-Host "  Proc: $_" -ForegroundColor Yellow }
    @($finalPrefs.ExclusionExtension) | Where-Object { $_ } | ForEach-Object { Write-Host "  Ext:  $_" -ForegroundColor Yellow }
} else {
    Write-Host "[OK] No exclusions remain" -ForegroundColor Green
}

if ($s -and $s.AMServiceEnabled -and $s.RealTimeProtectionEnabled) {
    Write-Host "[OK] Defender is fully operational" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Defender is NOT fully operational — try reboot, then sfc /scannow" -ForegroundColor Red
}
```

</details>

<details>
<summary>Defender Quick Reference</summary>

```powershell
# ── Status ───────────────────────────────────────────────────────────────────
Get-MpComputerStatus                          # full status dashboard
Get-MpComputerStatus | Select-Object AMServiceEnabled, RealTimeProtectionEnabled, BehaviorMonitorEnabled, IoavProtectionEnabled, IsTamperProtected, AntivirusSignatureAge

# ── Scans ────────────────────────────────────────────────────────────────────
Start-MpScan -ScanType QuickScan             # active processes + startup locations

# Targeted scans — common red team drop zones (run these, not full scan)
Start-MpScan -ScanPath "C:\Windows\System32" -ScanType CustomScan
Start-MpScan -ScanPath "C:\Windows\Temp" -ScanType CustomScan
Start-MpScan -ScanPath "C:\Windows\Tasks" -ScanType CustomScan
Start-MpScan -ScanPath "C:\Users" -ScanType CustomScan
Start-MpScan -ScanPath "C:\ProgramData" -ScanType CustomScan
Start-MpScan -ScanPath "C:\Windows\SysWOW64" -ScanType CustomScan
Start-MpScan -ScanPath "C:\Perflogs" -ScanType CustomScan
Start-MpScan -ScanPath "$env:APPDATA" -ScanType CustomScan

# Scan all running processes (catches in-memory malware that's already loaded)
Get-Process | Where-Object { $_.Path } | Select-Object -ExpandProperty Path -Unique |
    ForEach-Object { Start-MpScan -ScanPath $_ -ScanType CustomScan -ErrorAction SilentlyContinue }

# Scan startup/persistence locations
Start-MpScan -ScanPath "C:\Windows\System32\Tasks" -ScanType CustomScan
Start-MpScan -ScanPath "C:\Windows\System32\GroupPolicy" -ScanType CustomScan

# Queue all scans in background (Defender only runs one at a time)
Start-Job -ScriptBlock {
    Start-MpScan -ScanType QuickScan
    Start-MpScan -ScanPath "C:\Windows\System32" -ScanType CustomScan
    Start-MpScan -ScanPath "C:\Windows\Temp" -ScanType CustomScan
    Start-MpScan -ScanPath "C:\Windows\Tasks" -ScanType CustomScan
    Start-MpScan -ScanPath "C:\Users" -ScanType CustomScan
    Start-MpScan -ScanPath "C:\ProgramData" -ScanType CustomScan
    Start-MpScan -ScanPath "C:\Perflogs" -ScanType CustomScan
    Start-MpScan -ScanPath "C:\Windows\SysWOW64" -ScanType CustomScan
    Start-MpScan -ScanPath "C:\Windows\System32\Tasks" -ScanType CustomScan
    Start-MpScan -ScanPath "C:\Windows\System32\GroupPolicy" -ScanType CustomScan
}
Get-Job                # check progress
Receive-Job -Id 1      # see output when done

# Full scan — avoid during competition, takes 30-60+ min and tanks performance
# Start-MpScan -ScanType FullScan

# ── Detections & Quarantine ──────────────────────────────────────────────────
Get-MpThreatDetection | Format-List *                    # recent scan results (detailed)
Get-MpThreatDetection | Select-Object ThreatID, Resources, InitialDetectionTime | Format-List  # summary
Get-MpThreat | Select-Object ThreatName, Resources, IsActive | Format-List   # quarantine + resolved
Remove-MpThreat                                          # remove all active threats

# ── Signatures ───────────────────────────────────────────────────────────────
Update-MpSignature                            # pull latest definitions
(Get-MpComputerStatus).AntivirusSignatureAge  # days since last update (0 = today)

# ── Exclusions (audit + nuke) ────────────────────────────────────────────────
# List current exclusions (red team loves planting these)
$p = Get-MpPreference
$p.ExclusionPath; $p.ExclusionProcess; $p.ExclusionExtension; $p.ExclusionIpAddress

# Remove specific exclusion
Remove-MpPreference -ExclusionProcess "powershell.exe"
Remove-MpPreference -ExclusionExtension ".exe"
Remove-MpPreference -ExclusionPath "C:\Tools"

# ── Settings ─────────────────────────────────────────────────────────────────
Set-MpPreference -DisableBehaviorMonitoring $false       # enable behavior monitoring
Set-MpPreference -DisableRealtimeMonitoring $false       # enable real-time protection
Set-MpPreference -PUAProtection 1                        # block potentially unwanted apps
Set-MpPreference -SubmitSamplesConsent 2                 # send samples to cloud (SendAllSamples)

# ── Service Control ──────────────────────────────────────────────────────────
sc.exe start WinDefend                        # start service
sc.exe stop WinDefend                         # stop (may fail if tamper protected)
sc.exe config WinDefend start= auto           # set to auto-start
& "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -wdenable   # nuclear re-enable

# ── Scheduled Tasks ──────────────────────────────────────────────────────────
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\*"   # list tasks + state
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\*" | Enable-ScheduledTask  # re-enable all
```

</details>

<details>
<summary>Block EXEs from Running</summary>

```powershell
# Add exe names to block — Windows will refuse to run these
$blocked = @("malware.exe", "beacon.exe", "nc.exe", "nc64.exe", "mimikatz.exe", "psexec.exe")

# Uses Software Restriction Policy (Disallowed = blocked from executing)
$basePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"
New-Item -Path $basePath -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $basePath -Name "DefaultLevel" -Value 262144 -Type DWord -Force  # default=Unrestricted
Set-ItemProperty -Path $basePath -Name "TransparentEnabled" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $basePath -Name "PolicyScope" -Value 0 -Type DWord -Force

$i = 0
foreach ($exe in $blocked) {
    $rulePath = "$basePath\0\Paths\{$(New-Guid)}"
    New-Item -Path $rulePath -Force | Out-Null
    Set-ItemProperty -Path $rulePath -Name "ItemData" -Value $exe -Type String -Force
    Set-ItemProperty -Path $rulePath -Name "SaferFlags" -Value 0 -Type DWord -Force
    Write-Host "[+] Blocked: $exe" -ForegroundColor Green
    $i++
}

Write-Host "`n[*] $i executables blocked via Software Restriction Policy" -ForegroundColor Cyan
```

</details>

<details>
<summary>Useful Commands Cheat Sheet</summary>

#### Disable WinRM (kill sessions, stop, block firewall, prevent startup)
```powershell
Get-WSManInstance -ResourceURI shell -Enumerate -ErrorAction SilentlyContinue | ForEach-Object { Remove-WSManInstance -ResourceURI shell -SelectorSet @{ShellId=$_.ShellId} }
Stop-Service WinRM -Force -ErrorAction SilentlyContinue
Set-Service WinRM -StartupType Disabled -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Block WinRM Inbound" -Direction Inbound -Protocol TCP -LocalPort 5985,5986 -Action Block -ErrorAction SilentlyContinue
Write-Host "[+] WinRM killed, disabled, and blocked" -ForegroundColor Green
```

#### Kick RDP Sessions
```powershell
# Kick all disconnected/active RDP sessions
qwinsta | ForEach-Object { if ($_ -match "\s+(\d+)\s+" -and ($_ -match "rdp-tcp|Disc")) { logoff $matches[1] } }
# Kick a specific session (get ID from qwinsta)
logoff SESSION_ID
```

#### Sigcheck (verify signed binaries)
```powershell
C:\Sysinternals\Sigcheck64.exe -u -e C:\Windows\System32
```

#### Manual Sysmon Management
```powershell
# Check status
sc query Sysmon64
# Update config
C:\Sysinternals\Sysmon64.exe -c "$env:TEMP\sc.xml"
# Uninstall
C:\Sysinternals\Sysmon64.exe -u
```

#### Legacy Full Sysinternals Install (all tools, no filtering)
```powershell
Invoke-WebRequest "https://download.sysinternals.com/files/SysinternalsSuite.zip" -OutFile "$env:TEMP\ss.zip"
Expand-Archive "$env:TEMP\ss.zip" -DestinationPath "C:\Sysinternals" -Force
Remove-Item "$env:TEMP\ss.zip"
reg add "HKCU\Software\Sysinternals" /v EulaAccepted /t REG_DWORD /d 1 /f
```

#### Manual Hardening (if Harden-GPO.ps1 fails or for non-DC machines)
```powershell
# Reset GPOs to default (DC only)
dcgpofix /target:both
gpupdate /force

# Disable SMB1
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# Disable unnecessary services
gsv RemoteRegistry,TlntSvr,SNMP -ea 0 | spsv -f -pas | Set-Service -st Disabled
```
- **Disable LLMNR:** `gpedit.msc -> Computer Config -> Admin Templates -> Network -> DNS Client -> Turn off multicast name resolution -> Enable`
- **Disable NBT-NS:** `Network adapter -> IPv4 Properties -> Advanced -> WINS -> Disable NetBIOS over TCP/IP`
- **SMB Signing:** `gpedit.msc -> Computer Config -> Policies -> Security Settings -> Local Policies -> Security Options -> Digitally sign communications (always) = Enabled` (both client and server)

#### Re-enable Local Accounts
```powershell
"Guest","Administrator" | ForEach-Object { Enable-LocalUser -Name $_; Write-Host "  Enabled: $_" -ForegroundColor Green }
```

#### Re-enable AD Accounts (DC only)
```powershell
"Guest" | ForEach-Object { Enable-ADAccount -Identity $_; Write-Host "  Enabled: $_" -ForegroundColor Green }
```

#### Enable SSH
```powershell
Remove-NetFirewallRule -DisplayName "Block SSH Inbound" -ErrorAction SilentlyContinue
Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service sshd -ErrorAction SilentlyContinue
Write-Host "[+] SSH enabled and started" -ForegroundColor Green
```

#### Enable WinRM
```powershell
Remove-NetFirewallRule -DisplayName "Block WinRM Inbound" -ErrorAction SilentlyContinue
Set-Service WinRM -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service WinRM -ErrorAction SilentlyContinue
Write-Host "[+] WinRM enabled and started" -ForegroundColor Green
```

</details>

<details>
<summary>GPO Import from GitHub (download GPOBackups.zip from private repo)</summary>

Use this if you don't have the GPOBackups.zip on a USB and need to pull it from the repo.

```powershell
# ── Config ──────────────────────────────────────────────────────────────
$token  = "ghp_YOUR_PAT_HERE"                    # GitHub Personal Access Token
$repo   = "UML-Cyber-Security/ccdc2026"
$branch = "main"
$file   = "Platform-Windows/GPOBackups.zip"

# ── Download & Extract ──────────────────────────────────────────────────
$headers = @{ Authorization = "token $token"; Accept = "application/vnd.github.v3.raw" }
$zipPath = "$env:TEMP\GPOBackups.zip"
$extractPath = "$env:TEMP\GPOBackups"

Invoke-WebRequest -Uri "https://api.github.com/repos/$repo/contents/$file?ref=$branch" `
    -Headers $headers -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# ── Import GPOs ─────────────────────────────────────────────────────────
Import-Module GroupPolicy, ActiveDirectory
$DomainDN = (Get-ADDomain).DistinguishedName

New-GPO -Name "Hardening" -ErrorAction SilentlyContinue
Import-GPO -BackupGpoName "Hardening" -Path $extractPath -TargetName "Hardening"
New-GPLink -Name "Hardening" -Target $DomainDN -LinkEnabled Yes -ErrorAction SilentlyContinue

Import-GPO -BackupGpoName "Default Domain Policy" -Path $extractPath -TargetName "Default Domain Policy"

# Local registry fix (GPO import doesn't do this)
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" `
    -Name "SCENoApplyLegacyAuditPolicy" -Value 0 -Type DWord -Force

gpupdate /force
Write-Host "[+] GPO import complete" -ForegroundColor Green
```

</details>

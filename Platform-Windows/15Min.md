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
$ProgressPreference = 'SilentlyContinue'
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

# Install Sysmon with hardened config
@'
<Sysmon schemaversion="4.50">
  <HashAlgorithms>SHA256</HashAlgorithms>
  <EventFiltering>
    <ProcessCreate onmatch="exclude">
      <Image condition="is">C:\Windows\System32\backgroundTaskHost.exe</Image>
      <Image condition="is">C:\Windows\System32\RuntimeBroker.exe</Image>
      <Image condition="is">C:\Windows\System32\sihost.exe</Image>
      <Image condition="is">C:\Windows\System32\SearchProtocolHost.exe</Image>
      <Image condition="is">C:\Windows\System32\SearchFilterHost.exe</Image>
      <Image condition="is">C:\Windows\System32\audiodg.exe</Image>
      <Image condition="is">C:\Windows\System32\ctfmon.exe</Image>
      <Image condition="is">C:\Windows\System32\MusNotifyIcon.exe</Image>
      <Image condition="is">C:\Windows\System32\musnotification.exe</Image>
    </ProcessCreate>
    <FileCreateTime onmatch="exclude" />
    <NetworkConnect onmatch="exclude">
      <DestinationPort condition="is">67</DestinationPort>
      <DestinationPort condition="is">68</DestinationPort>
    </NetworkConnect>
    <ImageLoad onmatch="include">
      <ImageLoaded condition="contains">\Temp\</ImageLoaded>
      <ImageLoaded condition="contains">\AppData\</ImageLoaded>
      <ImageLoaded condition="contains">\Downloads\</ImageLoaded>
      <ImageLoaded condition="contains">\ProgramData\</ImageLoaded>
      <ImageLoaded condition="contains">\Users\Public\</ImageLoaded>
      <ImageLoaded condition="contains">\Windows\Tasks\</ImageLoaded>
      <ImageLoaded condition="contains">\Recycle</ImageLoaded>
      <Signed condition="is">false</Signed>
    </ImageLoad>
    <CreateRemoteThread onmatch="exclude">
      <SourceImage condition="is">C:\Windows\System32\csrss.exe</SourceImage>
      <SourceImage condition="is">C:\Windows\System32\wininit.exe</SourceImage>
      <SourceImage condition="is">C:\Windows\System32\winlogon.exe</SourceImage>
    </CreateRemoteThread>
    <ProcessAccess onmatch="include">
      <TargetImage condition="is">C:\Windows\System32\lsass.exe</TargetImage>
    </ProcessAccess>
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
      <TargetFilename condition="end with">.aspx</TargetFilename>
      <TargetFilename condition="end with">.asp</TargetFilename>
      <TargetFilename condition="end with">.jsp</TargetFilename>
      <TargetFilename condition="end with">.php</TargetFilename>
      <TargetFilename condition="contains">\inetpub\</TargetFilename>
      <TargetFilename condition="contains">\wwwroot\</TargetFilename>
      <TargetFilename condition="contains">\Start Menu\Programs\Startup\</TargetFilename>
    </FileCreate>
    <RegistryEvent onmatch="include">
      <TargetObject condition="contains">\CurrentVersion\Run</TargetObject>
      <TargetObject condition="contains">\CurrentVersion\RunOnce</TargetObject>
      <TargetObject condition="contains">\Services\</TargetObject>
      <TargetObject condition="contains">\Schedule\TaskCache\</TargetObject>
      <TargetObject condition="contains">\AppInit_DLLs</TargetObject>
      <TargetObject condition="contains">\Image File Execution Options\</TargetObject>
      <TargetObject condition="contains">\Winlogon\</TargetObject>
      <TargetObject condition="contains">\SecurityProviders\</TargetObject>
      <TargetObject condition="contains">\InprocServer32\</TargetObject>
      <TargetObject condition="contains">\Explorer\Shell Folders</TargetObject>
      <TargetObject condition="contains">\Wow6432Node\</TargetObject>
      <TargetObject condition="contains">\Environment\</TargetObject>
      <TargetObject condition="contains">\Windows\CurrentVersion\Policies\</TargetObject>
      <TargetObject condition="contains">\Authentication\Credential Providers\</TargetObject>
      <TargetObject condition="contains">\LSA\</TargetObject>
    </RegistryEvent>
    <FileCreateStreamHash onmatch="exclude">
      <TargetFilename condition="end with">Zone.Identifier</TargetFilename>
    </FileCreateStreamHash>
    <PipeEvent onmatch="include">
      <PipeName condition="contains">msagent_</PipeName>
      <PipeName condition="contains">MSSE-</PipeName>
      <PipeName condition="contains">postex_</PipeName>
      <PipeName condition="contains">status_</PipeName>
      <PipeName condition="is">\psexecsvc</PipeName>
      <PipeName condition="is">\paexecsvc</PipeName>
      <PipeName condition="is">\remcom_comunicacion</PipeName>
      <PipeName condition="is">\isapi_http</PipeName>
      <PipeName condition="is">\isapi_dg</PipeName>
      <PipeName condition="is">\isapi_dg2</PipeName>
      <PipeName condition="contains">csexec</PipeName>
      <PipeName condition="contains">DserNamePipe</PipeName>
      <PipeName condition="contains">SearchTextHarvester</PipeName>
      <PipeName condition="contains">lsadump</PipeName>
      <PipeName condition="contains">cachedump</PipeName>
      <PipeName condition="contains">wceservice</PipeName>
    </PipeEvent>
    <DnsQuery onmatch="exclude">
      <QueryName condition="end with">.windowsupdate.com</QueryName>
      <QueryName condition="end with">.msftconnecttest.com</QueryName>
      <QueryName condition="end with">.msftncsi.com</QueryName>
    </DnsQuery>
    <FileDelete onmatch="include">
      <TargetFilename condition="end with">.exe</TargetFilename>
      <TargetFilename condition="end with">.dll</TargetFilename>
      <TargetFilename condition="end with">.ps1</TargetFilename>
      <TargetFilename condition="end with">.bat</TargetFilename>
      <TargetFilename condition="end with">.cmd</TargetFilename>
      <TargetFilename condition="end with">.vbs</TargetFilename>
      <TargetFilename condition="contains">\winevt\Logs\</TargetFilename>
    </FileDelete>
    <ProcessTampering onmatch="exclude" />
  </EventFiltering>
</Sysmon>
'@ | Out-File "$env:TEMP\sc.xml" -Encoding UTF8
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

#### Secure privileged groups & unlink suspicious GPOs (surgical)

> Nuclear version (strips ALL memberships from every user) is in `scripts/Strip-Groups-Nuclear.ps1`

```powershell
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  SURGICAL GROUP & GPO CLEANUP                                              ║
# ║  - Only touches privileged groups (Domain Admins, Enterprise Admins, etc.) ║
# ║  - Leaves custom/business groups alone (HR Admins, Finance, etc.)          ║
# ║  - Unlinks (does NOT delete) non-default GPOs for manual review            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Our team users — added to all privileged groups
$ourUsers = @(

)

# Users to NEVER remove from any group (e.g. scoring accounts, service accounts)
$excludeUsers = @(
    "blackteam"
    "black-team"
    "krbtgt"
)

# ── Privileged groups: who belongs and who doesn't ───────────────────────────

# Which users belong in which privileged groups
$defaultUsers = @{
    "Domain Admins"          = $ourUsers
    "Enterprise Admins"      = $ourUsers
    "Schema Admins"          = $ourUsers
    "Administrators"         = $ourUsers
    "Group Policy Creator Owners" = $ourUsers
    "Server Operators"       = @()
    "Account Operators"      = @()
    "Backup Operators"       = @()
    "Print Operators"        = @()
    "DnsAdmins"              = @()
    "Denied RODC Password Replication Group" = @("krbtgt")
}

# Which groups should be nested in which privileged groups
$defaultGroupNesting = @{
    "Administrators" = @()
    "Denied RODC Password Replication Group" = @(
        "Domain Admins", "Enterprise Admins", "Schema Admins",
        "Read-only Domain Controllers", "Domain Controllers",
        "Cert Publishers", "Group Policy Creator Owners"
    )
    "Group Policy Creator Owners" = @()
    "Schema Admins"          = @()
    "Domain Admins"          = @()
    "Enterprise Admins"      = @()
    "Server Operators"       = @()
    "Account Operators"      = @()
    "Backup Operators"       = @()
    "Print Operators"        = @()
}

# GPOs that should stay linked (everything else gets unlinked, not deleted)
$allowedGPOs = @(
    "Default Domain Policy"
    "Default Domain Controllers Policy"
    "Hardening"
)

$DomainDN = (Get-ADDomain).DistinguishedName
$skipUsers = @($excludeUsers) + @($ourUsers) + @("krbtgt")

# ── Step 0: Create our users if they don't exist ─────────────────────────────
foreach ($u in $ourUsers) {
    try {
        Get-ADUser -Identity $u -ErrorAction Stop | Out-Null
    } catch {
        $cred = Get-Credential -UserName $u -Message "Set password for new AD user: $u"
        New-ADUser -Name $u -SamAccountName $u -AccountPassword $cred.Password -Enabled $true -PasswordNeverExpires $false -ChangePasswordAtLogon $false
        Write-Host "  CREATED user $u" -ForegroundColor Green
    }
}

# ── Step 1: Backup ALL group memberships + GPO link state ────────────────────
$backupFile = "C:\ad-groups-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$backupRows = @()
foreach ($group in (Get-ADGroup -Filter *)) {
    try {
        $members = Get-ADGroupMember -Identity $group -ErrorAction Stop
        foreach ($m in $members) {
            $backupRows += [PSCustomObject]@{
                Group      = $group.Name
                Member     = $m.SamAccountName
                MemberType = $m.objectClass
                MemberDN   = $m.distinguishedName
            }
        }
    } catch {}
}
$backupRows | Export-Csv -Path $backupFile -NoTypeInformation
Write-Host "[+] Backed up group memberships to $backupFile" -ForegroundColor Green

$gpoBackupFile = "C:\gpo-links-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$gpoRows = @()
foreach ($ou in (Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName)) {
    try {
        $links = (Get-GPInheritance -Target $ou).GpoLinks
        foreach ($link in $links) {
            $gpoRows += [PSCustomObject]@{
                Target    = $ou
                GPOName   = $link.DisplayName
                Enabled   = $link.Enabled
                Enforced  = $link.Enforced
                Order     = $link.Order
            }
        }
    } catch {}
}
# Also capture domain-level links
$domainLinks = (Get-GPInheritance -Target $DomainDN).GpoLinks
foreach ($link in $domainLinks) {
    $gpoRows += [PSCustomObject]@{
        Target    = $DomainDN
        GPOName   = $link.DisplayName
        Enabled   = $link.Enabled
        Enforced  = $link.Enforced
        Order     = $link.Order
    }
}
$gpoRows | Export-Csv -Path $gpoBackupFile -NoTypeInformation
Write-Host "[+] Backed up GPO link state to $gpoBackupFile" -ForegroundColor Green

# ── Step 2: Audit privileged groups (ONLY these — custom groups untouched) ───
$toRemoveUsers  = @()
$toRemoveGroups = @()
$toAdd          = @()

foreach ($groupName in ($defaultUsers.Keys + $defaultGroupNesting.Keys | Sort-Object -Unique)) {
    try { $currentMembers = @(Get-ADGroupMember -Identity $groupName -ErrorAction Stop) } catch { continue }

    $allowedUsers  = if ($defaultUsers.ContainsKey($groupName))        { $defaultUsers[$groupName] }        else { @() }
    $allowedGroups = if ($defaultGroupNesting.ContainsKey($groupName)) { $defaultGroupNesting[$groupName] } else { @() }

    # Find unauthorized users in privileged groups
    foreach ($m in $currentMembers) {
        if ($m.objectClass -eq 'user' -and $m.SamAccountName -notin $allowedUsers -and $m.SamAccountName -notin $skipUsers) {
            $toRemoveUsers += [PSCustomObject]@{ Group=$groupName; Member=$m.SamAccountName; DN=$m.distinguishedName }
        }
        if ($m.objectClass -eq 'group' -and $m.SamAccountName -notin $allowedGroups -and $m.Name -notin $allowedGroups) {
            $toRemoveGroups += [PSCustomObject]@{ Group=$groupName; Member=$m.Name; DN=$m.distinguishedName }
        }
    }

    # Find missing members that should be added
    $currentGroupNames = $currentMembers | Where-Object { $_.objectClass -eq 'group' } | ForEach-Object { $_.Name }
    foreach ($g in $allowedGroups) {
        if ($g -notin $currentGroupNames) {
            $toAdd += [PSCustomObject]@{ Group=$groupName; Member=$g; Type='group' }
        }
    }
    $currentNames = $currentMembers | ForEach-Object { $_.SamAccountName }
    foreach ($u in $allowedUsers) {
        if ($u -notin $currentNames) {
            $toAdd += [PSCustomObject]@{ Group=$groupName; Member=$u; Type='user' }
        }
    }
}

# ── Step 3: Find GPOs to unlink ──────────────────────────────────────────────
$gpoTargets = @($DomainDN) + @(Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName)
$toUnlink = @()
foreach ($target in $gpoTargets) {
    try {
        $links = (Get-GPInheritance -Target $target).GpoLinks
        foreach ($link in $links) {
            if ($link.DisplayName -notin $allowedGPOs -and $link.Enabled -eq "Yes") {
                $toUnlink += [PSCustomObject]@{ Target=$target; GPOName=$link.DisplayName }
            }
        }
    } catch {}
}

# ── Step 4: Show dry run ─────────────────────────────────────────────────────
Write-Host "`n=== PRIVILEGED GROUP CHANGES ===" -ForegroundColor Cyan
if ($toRemoveUsers.Count -eq 0 -and $toRemoveGroups.Count -eq 0 -and $toAdd.Count -eq 0) {
    Write-Host "  Privileged groups already clean." -ForegroundColor Green
} else {
    foreach ($r in $toRemoveUsers)  { Write-Host "  REMOVE [user]  $($r.Member) from $($r.Group)" -ForegroundColor Yellow }
    foreach ($r in $toRemoveGroups) { Write-Host "  REMOVE [group] $($r.Member) from $($r.Group)" -ForegroundColor Yellow }
    foreach ($a in $toAdd)          { Write-Host "  ADD    [$($a.Type)] $($a.Member) to $($a.Group)" -ForegroundColor Cyan }
}

Write-Host "`n=== GPO UNLINK (not delete) ===" -ForegroundColor Cyan
if ($toUnlink.Count -eq 0) {
    Write-Host "  No non-default GPOs linked." -ForegroundColor Green
} else {
    foreach ($u in $toUnlink) { Write-Host "  UNLINK '$($u.GPOName)' from $($u.Target)" -ForegroundColor Yellow }
    Write-Host "  (GPOs will NOT be deleted — review in gpmc.msc)" -ForegroundColor Gray
}

$totalChanges = $toRemoveUsers.Count + $toRemoveGroups.Count + $toAdd.Count + $toUnlink.Count
if ($totalChanges -eq 0) {
    Write-Host "`n[OK] Everything already matches desired state." -ForegroundColor Green
    return
}

Write-Host ""
$confirm = Read-Host "Proceed? (y/n)"
if ($confirm -ne 'y') { Write-Host "  Aborted." -ForegroundColor Red; return }

# ── Step 5: Execute privileged group removals ────────────────────────────────
foreach ($r in ($toRemoveUsers + $toRemoveGroups)) {
    try {
        Remove-ADGroupMember -Identity $r.Group -Members $r.DN -Confirm:$false
        Write-Host "  REMOVED $($r.Member) from $($r.Group)" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED to remove $($r.Member) from $($r.Group): $_" -ForegroundColor Red
    }
}

# ── Step 6: Execute privileged group additions ───────────────────────────────
foreach ($a in $toAdd) {
    try {
        Add-ADGroupMember -Identity $a.Group -Members $a.Member -ErrorAction Stop
        Write-Host "  ADDED [$($a.Type)] $($a.Member) to $($a.Group)" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED to add $($a.Member) to $($a.Group): $_" -ForegroundColor Red
    }
}

# ── Step 7: Unlink non-default GPOs (disable link, do NOT delete) ────────────
foreach ($u in $toUnlink) {
    try {
        Set-GPLink -Name $u.GPOName -Target $u.Target -LinkEnabled No -ErrorAction Stop
        Write-Host "  UNLINKED '$($u.GPOName)' from $($u.Target)" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED to unlink '$($u.GPOName)': $_" -ForegroundColor Red
    }
}

# ── Step 8: Add de-privileged users to Remote Desktop Users ─────────────────
Write-Host "`n=== REMOTE DESKTOP ACCESS ===" -ForegroundColor Cyan
foreach ($r in $toRemoveUsers) {
    if ($r.Group -in @("Domain Admins","Administrators","Enterprise Admins")) {
        try {
            Add-ADGroupMember -Identity "Remote Desktop Users" -Members $r.Member -ErrorAction Stop
            Write-Host "  ADDED $($r.Member) to Remote Desktop Users (was in $($r.Group))" -ForegroundColor Green
        } catch {
            if ($_.Exception.Message -match "already a member") {
                Write-Host "  OK $($r.Member) already in Remote Desktop Users" -ForegroundColor Gray
            } else {
                Write-Host "  FAILED to add $($r.Member) to Remote Desktop Users: $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n  Done. Backups:" -ForegroundColor Cyan
Write-Host "    Groups: $backupFile" -ForegroundColor Gray
Write-Host "    GPOs:   $gpoBackupFile" -ForegroundColor Gray
Write-Host "    Review unlinked GPOs in gpmc.msc — delete manually if malicious" -ForegroundColor Gray
```

**Reset krbtgt twice (DC only)** — kills Golden Tickets. Reset twice because AD keeps current + previous hash. Do this manually through Active Directory Users and Computers: right-click `krbtgt` > Reset Password. Run it **twice** back-to-back. May briefly break Kerberos auth.

</details>

<details>
<summary><b>3. Review & Kick Active Sessions</b> — Show/kill RDP, disable SSH/WinRM, clean shares/mounts</summary>

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

#### Audit & remove non-default shares, disconnect mapped drives
```powershell
$isDC = (Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue).DomainRole -ge 4
$adShares = @("NETLOGON", "SYSVOL")

# ── Backup current shares ──────────────────────────────────────────────────
$backupFile = "C:\shares-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$shares = Get-SmbShare -ErrorAction SilentlyContinue
$shares | Select-Object Name, Path, Description, ScopeName | Export-Csv -Path $backupFile -NoTypeInformation
Write-Host "[+] Backed up share list to $backupFile" -ForegroundColor Green

# ── Show all shares ────────────────────────────────────────────────────────
Write-Host "`n=== SMB Shares ===" -ForegroundColor Cyan
$toRemove = @()
foreach ($s in $shares) {
    if ($s.Name -match '^\w\$$|^ADMIN\$$|^IPC\$$') {
        Write-Host "  [ADMIN] $($s.Name) -> $($s.Path)" -ForegroundColor DarkGray
        continue
    }
    if ($isDC -and $s.Name -in $adShares) {
        Write-Host "  [AD-OK] $($s.Name) -> $($s.Path)" -ForegroundColor DarkGray
        continue
    }
    $access = Get-SmbShareAccess -Name $s.Name -ErrorAction SilentlyContinue
    $perms = ($access | ForEach-Object { "$($_.AccountName):$($_.AccessRight)" }) -join ", "
    Write-Host "  [FOUND] $($s.Name) -> $($s.Path)  ($perms)" -ForegroundColor Yellow
    $toRemove += $s
}

# ── Show mapped drives ────────────────────────────────────────────────────
Write-Host "`n=== Mapped Drives ===" -ForegroundColor Cyan
$mapped = net use 2>&1 | Where-Object { $_ -match "^\s*(OK|Disconnected|Unavailable)" }
if ($mapped) {
    $mapped | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
} else {
    Write-Host "  No mapped drives" -ForegroundColor Green
}

# ── Confirm before deleting ────────────────────────────────────────────────
$totalChanges = $toRemove.Count + $(if ($mapped) { 1 } else { 0 })
if ($totalChanges -eq 0) {
    Write-Host "`n[OK] Nothing to clean up." -ForegroundColor Green
    return
}

Write-Host ""
$confirm = Read-Host "Remove $($toRemove.Count) share(s) and disconnect mapped drives? (y/n)"
if ($confirm -ne 'y') { Write-Host "  Aborted." -ForegroundColor Red; return }

foreach ($s in $toRemove) {
    try {
        Remove-SmbShare -Name $s.Name -Force -ErrorAction Stop
        Write-Host "  [REMOVED] $($s.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED] $($s.Name) — $_" -ForegroundColor Red
    }
}

if ($mapped) {
    net use * /delete /yes 2>&1 | Out-Null
    Write-Host "  [+] All mapped drives disconnected" -ForegroundColor Green
}

Write-Host "`n  Backup: $backupFile" -ForegroundColor Gray
```

</details>

<details>
<summary><b>4. Network & Tools</b> — Install Nmap, Wireshark, enable firewall</summary>

#### Install Nmap
```powershell
$ProgressPreference = 'SilentlyContinue'
$nmapUrl = "https://nmap.org/dist/nmap-7.98-setup.exe"
$installerPath = "$env:USERPROFILE\Downloads\nmap-setup.exe"
Invoke-WebRequest -Uri $nmapUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -ArgumentList '/forceinstall /NpcapInstallMode=1' -Wait
Remove-Item -Path $installerPath -Force
```

#### Install Wireshark
```powershell
$ProgressPreference = 'SilentlyContinue'
$installerUrl = "https://2.na.dl.wireshark.org/win64/Wireshark-4.6.4-x64.exe"
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
<summary><b>5. Harden GPO (DC only)</b> — Backup existing GPOs, reset, apply hardening (audit, password, encryption, Defender, network)</summary>

> [!NOTE]
> This builds GPOs from scratch on whatever domain you're on — no imports, no migration tables, no domain SID issues.
> Run with `-Safe` to skip settings that could break services (Kerberos AES-only, LDAP channel binding, script execution policy).
> Run with `-SuperSafe` for logging + password policy only (zero breakage risk).
> Also available as a standalone file: `scripts/Harden-GPO.ps1`

```powershell
param(
    [switch]$All,              # Run everything (default if no flags)
    [switch]$Reset,            # dcgpofix /target:both
    [switch]$AuditPolicy,      # Audit logging + PowerShell logging
    [switch]$PasswordPolicy,   # Password + lockout policy
    [switch]$ScriptPolicy,     # AllSigned execution policy
    [switch]$Encryption,       # SMB, Kerberos, NTLM, LDAP
    [switch]$CredProtection,   # WDigest, anonymous restriction
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

# Detect OS version for feature support
$osBuild = [int]$os.BuildNumber
# RelaxMinimumPasswordLengthLimits requires build 19041+ (Win10 2004 / Server 2022)
# Server 2019 = build 17763, Server 2022 = build 20348
$isLegacyPasswordPolicy = $osBuild -lt 19041
if ($isLegacyPasswordPolicy) {
    Write-Warn "Server 2019 or older detected (build $osBuild) — password length capped at 14"
} else {
    Write-Setting "Modern OS detected (build $osBuild) — full password policy support"
}

# Import required modules
foreach ($mod in @("GroupPolicy", "ActiveDirectory")) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Error "Required module '$mod' is not installed."
        exit 1
    }
    Import-Module $mod -ErrorAction Stop
    Write-Setting "Module loaded: $mod"
}

$adDomain = Get-ADDomain
$Domain = $adDomain.DNSRoot
$DomainDN = $adDomain.DistinguishedName
$DomainSID = $adDomain.DomainSID.Value
Write-Setting "Domain: $Domain ($DomainDN)"

# ── Backup existing GPOs ────────────────────────────────────────────────────

Write-Banner "Backing up existing GPOs"
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$exportPath = "C:\GPO-Export-$ts"
New-Item -Path $exportPath -ItemType Directory -Force | Out-Null
try {
    Get-GPO -All | ForEach-Object {
        Backup-GPO -Guid $_.Id -Path $exportPath -ErrorAction Stop | Out-Null
        Write-Host "  Backed up: $($_.DisplayName)" -ForegroundColor Gray
    }
    Compress-Archive -Path "$exportPath\*" -DestinationPath "$exportPath.zip" -ErrorAction Stop -Force
    Remove-Item -Path $exportPath -Recurse -Force
    Write-Setting "All GPOs exported to $exportPath.zip"
} catch {
    Write-Fail "GPO backup failed: $_"
    Write-Host "    Aborting — will NOT reset GPOs without a good backup." -ForegroundColor Red
    return
}

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
    Get-GPO -All | Where-Object { $_.DisplayName -notin "Default Domain Policy","Default Domain Controllers Policy" } | ForEach-Object {
    Write-Host "  Removing GPO: $($_.DisplayName)" -ForegroundColor Yellow
    Remove-GPO -Guid $_.Id -ErrorAction SilentlyContinue
}
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
[Privilege Rights]
SeRemoteInteractiveLogonRight = *S-1-5-32-544,*S-1-5-32-555,*$DomainSID-513
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
    # Server 2019 does not support RelaxMinimumPasswordLengthLimits — cap at 14
    if (-not $isLegacyPasswordPolicy) {
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\SAM" `
            -Name "RelaxMinimumPasswordLengthLimits" -Value 1 -Type DWord -Force
        Write-Setting "RelaxMinimumPasswordLengthLimits = 1 (allows MinPasswordLength > 14)"

        Set-GPRegistryValue -Name "Default Domain Policy" `
            -Key "HKLM\System\CurrentControlSet\Control\SAM" `
            -ValueName "RelaxMinimumPasswordLengthLimits" -Value 1 -Type DWord | Out-Null
        Write-Setting "RelaxMinimumPasswordLengthLimits pushed via Default Domain Policy GPO"
    } else {
        Write-Warn "Skipping RelaxMinimumPasswordLengthLimits (not supported on build $osBuild)"
    }

    $minPwdLen = if ($isLegacyPasswordPolicy) { 14 } else { 16 }

    # NIST SP 800-63B 2024: length-based policy, no composition rules
    $pwdSettings = [ordered]@{
        MinimumPasswordLength = $minPwdLen
        PasswordHistorySize   = 24
        MinimumPasswordAge    = 0
        MaximumPasswordAge    = -1
        PasswordComplexity    = 0
        ClearTextPassword     = 0
        LockoutBadCount       = 10
        ResetLockoutCount     = 15
        LockoutDuration       = 15
    }

    # AllowAdministratorLockout was added in Server 2022 (KB5020282) — doesn't exist on 2019
    if (-not $isLegacyPasswordPolicy) {
        $pwdSettings["AllowAdministratorLockout"] = 1
    } else {
        Write-Warn "Skipping AllowAdministratorLockout (not supported on build $osBuild)"
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
        -MinPasswordLength $minPwdLen `
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
    Test-Result "AD MinPasswordLength" "$minPwdLen" "$($adPwd.MinPasswordLength)"
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

    # ELAM: Block known bad drivers (default is 0x03 which allows known bad critical drivers)
    # 0x00 = known good only (can BSOD if a legit driver is unclassified)
    # 0x01 = known good + unknown (safe default — blocks known bad)
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\EarlyLaunch" `
        -ValueName "DriverLoadPolicy" -Value 1

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
            Test-Result "Effective MinPasswordLength" "$minPwdLen" $Matches[1]
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
<summary><b>6. Enable Windows Defender</b> — Fix sabotage, clean exclusions, verify running (run step 5 first!)</summary>

> [!CAUTION]
> **You must run step 5 (Harden-GPO.ps1) before this.** That script enables Defender via GPO. This step pulls that policy, does local cleanup GPO can't do, and confirms everything works.

```powershell
Set-StrictMode -Off

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
$exTotal = (@("ExclusionPath","ExclusionProcess","ExclusionExtension","ExclusionIpAddress") | ForEach-Object { $p = $mp.PSObject.Properties[$_]; if ($p) { $p.Value } } | Where-Object { $_ }).Count
Write-Host "  Exclusions planted:      $exTotal" -ForegroundColor $(if($exTotal -eq 0){'Green'}else{'Red'})

# Early exit if Defender is already fully operational
$preCheck = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($preCheck -and $preCheck.AMServiceEnabled -and $preCheck.RealTimeProtectionEnabled -and $preCheck.BehaviorMonitorEnabled -and $exTotal -eq 0) {
    Write-Host ""
    Write-Host "[OK] Defender is already fully operational — nothing to fix" -ForegroundColor Green
    return
}

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
        $startType = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -EA SilentlyContinue).Start
        if ($startType -eq 2) {
            Write-Host "  [+] $svc already set to auto-start" -ForegroundColor Green
        } else {
            $scOut = sc.exe config $svc start= auto 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [+] $svc set to auto-start" -ForegroundColor Green
            } else {
                Write-Host "  [-] Failed to set $svc to auto-start: $scOut" -ForegroundColor Red
            }
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
    if ($null -ne $val -and $val.($entry.Name) -eq 1) {
        $flagsFound++
        Write-Host "  [!] Found $($entry.Name) = 1 at $($entry.Path)" -ForegroundColor Yellow
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
foreach ($svc in $services) { try { Start-Service -Name $svc -ErrorAction Stop } catch {} }
Start-Sleep -Seconds 10

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
    }
}
if ($regCleared -eq 0 -and $regFailed -eq 0) {
    Write-Host "[+] No exclusion registry values found (already clean)" -ForegroundColor Green
} elseif ($regFailed -gt 0) {
    Write-Host "[i] Registry exclusions: $regCleared cleared, $regFailed skipped (will be cleaned via MpPreference)" -ForegroundColor Cyan
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
    Write-Host "  TamperProtection:        $($s.IsTamperProtected)$(if(-not $s.IsTamperProtected){' (requires Defender for Endpoint on Server)'})" -ForegroundColor $(if($s.IsTamperProtected){'Green'}else{'Cyan'})
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

$ProgressPreference = 'SilentlyContinue'
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
$excludedUsers = @("blackteam", "black-team", "svc_local")
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
$excludedUsers = @("blackteam", "black-team", "krbtgt")
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

Write-Host "`n========== SMB SHARES AUDIT ==========" -ForegroundColor Cyan
$shares = Get-SmbShare -ErrorAction SilentlyContinue
if ($shares) {
    # Dangerous paths that should never be shared
    $dangerousPaths = @(
        "C:\Windows", "C:\Windows\System32", "C:\Windows\SysWOW64",
        "C:\Program Files", "C:\Program Files (x86)", "C:\Users",
        "C:\ProgramData", "C:\", "D:\", "E:\"
    )
    # Required AD shares on Domain Controllers — don't flag these
    $adShares = @("NETLOGON", "SYSVOL")
    $isDC = (Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue).DomainRole -ge 4

    foreach ($s in $shares) {
        $path = $s.Path
        $name = $s.Name
        # Flag admin shares (C$, ADMIN$, IPC$) — expected but worth noting
        if ($name -match '^\w\$$|^ADMIN\$$|^IPC\$$') {
            Write-Host "  [ADMIN] $name -> $path" -ForegroundColor DarkGray
            continue
        }
        # NETLOGON and SYSVOL are required on DCs — just note them
        if ($isDC -and $name -in $adShares) {
            Write-Host "  [AD-OK] $name -> $path  (required DC share)" -ForegroundColor DarkGray
            continue
        }
        # Flag shares pointing to dangerous paths
        $isDangerous = $false
        foreach ($dp in $dangerousPaths) {
            if ($path -and ($path -eq $dp -or $path.StartsWith("$dp\"))) {
                Write-Host "  [DANGER] $name -> $path  (sharing system/sensitive directory!)" -ForegroundColor Red
                $isDangerous = $true
                break
            }
        }
        if (-not $isDangerous) {
            # Show permissions for non-admin, non-dangerous shares
            $access = Get-SmbShareAccess -Name $name -ErrorAction SilentlyContinue
            $perms = ($access | ForEach-Object { "$($_.AccountName):$($_.AccessRight)" }) -join ", "
            $color = if ($access | Where-Object { $_.AccountName -match "Everyone" }) { "Yellow" } else { "Cyan" }
            Write-Host "  [SHARE] $name -> $path  ($perms)" -ForegroundColor $color
        }
    }
} else {
    Write-Host "  No SMB shares found (or SMB not available)" -ForegroundColor Green
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

# Write-Host "`n========== REMOVE DANGEROUS SMB SHARES ==========" -ForegroundColor Cyan
# $isDC = (Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue).DomainRole -ge 4
# $skipNames = '^\w\$$|^ADMIN\$$|^IPC\$$'
# $shares = @(Get-SmbShare -ErrorAction SilentlyContinue |
#     Where-Object { $_.Name -notmatch $skipNames } |
#     Where-Object { -not ($isDC -and $_.Name -in @("NETLOGON","SYSVOL")) })
# if ($shares.Count -eq 0) {
#     Write-Host "  No non-default shares to remove" -ForegroundColor Green
# } else {
#     Write-Host "  Found $($shares.Count) share(s) to remove:" -ForegroundColor Yellow
#     foreach ($s in $shares) {
#         $access = Get-SmbShareAccess -Name $s.Name -ErrorAction SilentlyContinue
#         $perms = ($access | ForEach-Object { "$($_.AccountName):$($_.AccessRight)" }) -join ", "
#         Write-Host "    $($s.Name) -> $($s.Path)  ($perms)" -ForegroundColor Yellow
#     }
#     $confirm = Read-Host "`n  Remove all listed shares? (Y/N)"
#     if ($confirm -eq "Y") {
#         foreach ($s in $shares) {
#             try {
#                 Remove-SmbShare -Name $s.Name -Force -ErrorAction Stop
#                 Write-Host "  [REMOVED] $($s.Name)" -ForegroundColor Green
#             } catch {
#                 Write-Host "  [FAILED] $($s.Name) — $($_.Exception.Message)" -ForegroundColor Red
#             }
#         }
#     } else {
#         Write-Host "  Skipped share removal" -ForegroundColor DarkGray
#     }
# }

# # Disable admin shares (C$, ADMIN$) from auto-creating on reboot
# Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" `
#     -Name "AutoShareServer" -Value 0 -Type DWord -ErrorAction SilentlyContinue
# Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" `
#     -Name "AutoShareWks" -Value 0 -Type DWord -ErrorAction SilentlyContinue
# Write-Host "  [SET] Admin shares (C$, ADMIN$) won't recreate on reboot" -ForegroundColor Green

# # Restrict anonymous access to shares
# Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
#     -Name "RestrictAnonymous" -Value 1 -Type DWord -ErrorAction SilentlyContinue
# Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" `
#     -Name "RestrictNullSessAccess" -Value 1 -Type DWord -ErrorAction SilentlyContinue
# Write-Host "  [SET] Anonymous/null session access restricted" -ForegroundColor Green

Write-Host "`n[+] Done. Review output above for failures." -ForegroundColor Cyan
```

</details>

<details>
<summary>Secure File Transfer Between Machines</summary>

Use these to move files/scripts between your Windows and Linux machines during competition. All methods are encrypted and require no additional installs.

#### SCP (Windows 10+ built-in, encrypted via SSH)
```powershell
# Copy file FROM Linux to Windows
scp user@192.168.1.50:/home/user/file.txt C:\Users\You\Desktop\

# Copy folder FROM Linux to Windows
scp -r user@192.168.1.50:/home/user/folder C:\Users\You\Desktop\

# Copy file FROM Windows to Linux
scp C:\Users\You\Desktop\file.txt user@192.168.1.50:/home/user/

# Copy between two Windows machines (requires SSH enabled on target)
scp C:\path\to\file.txt user@192.168.1.100:C:\Users\You\Desktop\
```

#### WinRM (Windows to Windows, encrypted, no extra install)
```powershell
# Copy file to remote Windows machine (WinRM must be enabled on target)
$session = New-PSSession -ComputerName 192.168.1.100 -Credential (Get-Credential)
Copy-Item -Path "C:\local\file.txt" -Destination "C:\remote\path\" -ToSession $session

# Copy folder recursively
Copy-Item -Path "C:\local\folder" -Destination "C:\remote\path\" -ToSession $session -Recurse

# Copy FROM remote machine to local
Copy-Item -Path "C:\remote\file.txt" -Destination "C:\local\path\" -FromSession $session

Remove-PSSession $session
```

#### Quick SMB share (temporary, authenticated, remove when done)
```powershell
# On the SOURCE machine — create a temp share with a specific user
net share TempShare=C:\path\to\share /grant:Administrator,READ

# On the DESTINATION machine — copy from the share
robocopy \\192.168.1.100\TempShare C:\destination /E /Z /R:3

# On the SOURCE machine — remove the share immediately after
net share TempShare /delete
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
Set-StrictMode -Off

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
$exTotal = (@("ExclusionPath","ExclusionProcess","ExclusionExtension","ExclusionIpAddress") | ForEach-Object { $p = $mp.PSObject.Properties[$_]; if ($p) { $p.Value } } | Where-Object { $_ }).Count
Write-Host "  Exclusions planted:      $exTotal" -ForegroundColor $(if($exTotal -eq 0){'Green'}else{'Red'})

# Early exit if Defender is already fully operational
$preCheck = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($preCheck -and $preCheck.AMServiceEnabled -and $preCheck.RealTimeProtectionEnabled -and $preCheck.BehaviorMonitorEnabled -and $exTotal -eq 0) {
    Write-Host ""
    Write-Host "[OK] Defender is already fully operational — nothing to fix" -ForegroundColor Green
    return
}

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
        $startType = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -EA SilentlyContinue).Start
        if ($startType -eq 2) {
            Write-Host "  [+] $svc already set to auto-start" -ForegroundColor Green
        } else {
            $scOut = sc.exe config $svc start= auto 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [+] $svc set to auto-start" -ForegroundColor Green
            } else {
                Write-Host "  [-] Failed to set $svc to auto-start: $scOut" -ForegroundColor Red
            }
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
    if ($null -ne $val -and $val.($entry.Name) -eq 1) {
        $flagsFound++
        Write-Host "  [!] Found $($entry.Name) = 1 at $($entry.Path)" -ForegroundColor Yellow
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
foreach ($svc in $services) { try { Start-Service -Name $svc -ErrorAction Stop } catch {} }
Start-Sleep -Seconds 10

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
    }
}
if ($regCleared -eq 0 -and $regFailed -eq 0) {
    Write-Host "[+] No exclusion registry values found (already clean)" -ForegroundColor Green
} elseif ($regFailed -gt 0) {
    Write-Host "[i] Registry exclusions: $regCleared cleared, $regFailed skipped (will be cleaned via MpPreference)" -ForegroundColor Cyan
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
    Write-Host "  TamperProtection:        $($s.IsTamperProtected)$(if(-not $s.IsTamperProtected){' (requires Defender for Endpoint on Server)'})" -ForegroundColor $(if($s.IsTamperProtected){'Green'}else{'Cyan'})
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

#### Restore AD group memberships from backup (exact state)
```powershell
$backupFile = Read-Host "Full path to backup CSV (e.g. C:\ad-groups-backup-20260305-120000.csv)"
if (-not (Test-Path $backupFile)) { Write-Host "  File not found: $backupFile" -ForegroundColor Red; return }
$rows = Import-Csv -Path $backupFile

# Build desired state per group from CSV
$desiredState = @{}
foreach ($r in $rows) {
    if (-not $desiredState[$r.Group]) { $desiredState[$r.Group] = @() }
    $desiredState[$r.Group] += $r
}

# For each group in the backup, remove members not in CSV, add members missing from current
foreach ($groupName in @($desiredState.Keys)) {
    try { $currentMembers = @(Get-ADGroupMember -Identity $groupName -ErrorAction Stop) } catch { continue }
    $desiredDNs = $desiredState[$groupName] | ForEach-Object { $_.MemberDN }
    $desiredNames = $desiredState[$groupName] | ForEach-Object { $_.Member }

    # Remove members not in backup (skip special principals with no DN)
    foreach ($m in $currentMembers) {
        if (-not $m.distinguishedName) { continue }
        if ($m.distinguishedName -notin $desiredDNs) {
            if ($m.SamAccountName -eq 'Administrator' -and $groupName -eq 'Administrators') { continue }
            try {
                Remove-ADGroupMember -Identity $groupName -Members $m.distinguishedName -Confirm:$false
                Write-Host "  REMOVED $($m.SamAccountName) from $groupName" -ForegroundColor Yellow
            } catch {
                Write-Host "  FAILED to remove $($m.SamAccountName) from ${groupName}: $($_)" -ForegroundColor Red
            }
        }
    }

    # Add members from backup that are missing (skip entries with no DN)
    $currentDNs = $currentMembers | ForEach-Object { $_.distinguishedName }
    foreach ($r in $desiredState[$groupName]) {
        if (-not $r.MemberDN) { continue }
        if ($r.MemberDN -notin $currentDNs) {
            try {
                Add-ADGroupMember -Identity $groupName -Members $r.MemberDN -ErrorAction Stop
                Write-Host "  ADDED $($r.Member) to $groupName" -ForegroundColor Green
            } catch {
                Write-Host "  FAILED to add $($r.Member) to ${groupName}: $($_)" -ForegroundColor Red
            }
        }
    }
}
Write-Host "`nRestore complete." -ForegroundColor Cyan
```

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

#### Network Shares & Mounts
```powershell
# List all shares on this machine
net share
# Same via PowerShell (more detail — paths, permissions)
Get-SmbShare | Format-Table Name, Path, Description -AutoSize
# Show permissions on a specific share
Get-SmbShareAccess -Name "ShareName"

# List mapped network drives / remote mounts
net use
# Same via PowerShell
Get-SmbMapping

# Delete a share
net share ShareName /delete
# Delete via PowerShell
Remove-SmbShare -Name "ShareName" -Force

# Disconnect a mapped drive
net use Z: /delete
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
$ProgressPreference = 'SilentlyContinue'
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

# ELAM: Block known bad drivers (default 0x03 allows them if critical)
# 1 = known good + unknown (safe), 0 = known good only (strict, can BSOD)
reg add "HKLM\System\CurrentControlSet\Control\EarlyLaunch" /v DriverLoadPolicy /t REG_DWORD /d 1 /f
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

#### SSH Tunnel (port forward through a jump box)
Forward a port from a remote internal machine through an SSH jump box to your local machine. Useful for RDP-ing into machines you can't reach directly.
```
ssh -L LOCAL_PORT:TARGET_IP:TARGET_PORT USER@JUMP_HOST
```
- `LOCAL_PORT` — port on your machine to connect to (e.g. `23456`)
- `TARGET_IP` — internal machine you want to reach (e.g. `10.0.1.52`)
- `TARGET_PORT` — service port on the target (e.g. `3389` for RDP)
- `USER@JUMP_HOST` — SSH credentials for the jump box (e.g. `blueteam@192.168.4.171`)

Example — RDP to `10.0.1.52` through jump box `192.168.4.171`:
```
ssh -L 23456:10.0.1.52:3389 blueteam@192.168.4.171
```
Then open Remote Desktop and connect to `localhost:23456`.

</details>

<details>
<summary>Restore GPO from backup zip (local path)</summary>

Restore GPOs from a backup zip (e.g. the `GPO-Export-*.zip` created by step 5, or `GPOBackups.zip`).

```powershell
# ── Point this to the backup zip or extracted folder ────────────────────
$backupLocation = "C:\GPO-Export.zip"   # <-- CHANGE: .zip file or folder containing {GUID} dirs

Import-Module GroupPolicy, ActiveDirectory
if ($backupLocation -match '\.zip$' -and (Test-Path $backupLocation)) {
    $extractPath = "$env:TEMP\GPORestore"
    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $backupLocation -DestinationPath $extractPath -Force
} elseif (Test-Path "$backupLocation\{*}") {
    $extractPath = $backupLocation
} else {
    Write-Host "[X] '$backupLocation' not found or contains no GPO backups" -ForegroundColor Red
    return
}

$DomainDN = (Get-ADDomain).DistinguishedName
$targetDomain = (Get-ADDomain).DNSRoot

# Verify backup is from this domain
$firstBackup = Get-ChildItem "$extractPath\{*}\Backup.xml" | Select-Object -First 1
$sourceDomain = ([xml](Get-Content $firstBackup.FullName)).GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.Domain.InnerText
if ($sourceDomain -ne $targetDomain) {
    Write-Host "[X] Backup is from '$sourceDomain' but this domain is '$targetDomain'" -ForegroundColor Red
    Write-Host "    Cross-domain GPO restore is not supported. Use step 5 (Harden-GPO) instead." -ForegroundColor Red
    return
}

# Reset GPOs to defaults before restoring
Get-GPO -All | Where-Object { $_.DisplayName -notin "Default Domain Policy","Default Domain Controllers Policy" } | ForEach-Object {
    Write-Host "  Removing GPO: $($_.DisplayName)" -ForegroundColor Yellow
    Remove-GPO -Guid $_.Id -ErrorAction SilentlyContinue
}
"Y","Y" | dcgpofix /target:both 2>&1 | ForEach-Object { Write-Host "    $_" }
gpupdate /force

# Import all GPO backups
Get-ChildItem -Path $extractPath -Directory -Filter "{*}" | ForEach-Object {
    $xml = [xml](Get-Content "$($_.FullName)\Backup.xml")
    $name = $xml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
    $id   = $_.Name -replace '[{}]'
    New-GPO -Name $name -ErrorAction SilentlyContinue | Out-Null
    try {
        Import-GPO -BackupId $id -Path $extractPath -TargetName $name -ErrorAction Stop
        New-GPLink -Name $name -Target $DomainDN -LinkEnabled Yes -ErrorAction SilentlyContinue
        Write-Host "  [+] Imported & linked: $name" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Failed to import '$name': $_" -ForegroundColor Red
    }
}

gpupdate /force
Write-Host "[+] GPO restore complete" -ForegroundColor Green
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

$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri "https://api.github.com/repos/$repo/contents/$file?ref=$branch" `
    -Headers $headers -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# ── Import GPOs ─────────────────────────────────────────────────────────
Import-Module GroupPolicy, ActiveDirectory
$DomainDN = (Get-ADDomain).DistinguishedName
$targetDomain = (Get-ADDomain).DNSRoot

# Verify backup is from this domain
$sourceDomain = ([xml](Get-Content (Get-ChildItem "$extractPath\{*}\Backup.xml" | Select-Object -First 1).FullName)).GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.Domain.InnerText
if ($sourceDomain -ne $targetDomain) {
    Write-Host "[X] Backup is from '$sourceDomain' but this domain is '$targetDomain'" -ForegroundColor Red
    Write-Host "    Cross-domain GPO restore is not supported. Use step 5 (Harden-GPO) instead." -ForegroundColor Red
    return
}

# Reset GPOs to defaults before restoring
Get-GPO -All | Where-Object { $_.DisplayName -notin "Default Domain Policy","Default Domain Controllers Policy" } | ForEach-Object {
    Write-Host "  Removing GPO: $($_.DisplayName)" -ForegroundColor Yellow
    Remove-GPO -Guid $_.Id -ErrorAction SilentlyContinue
}
"Y","Y" | dcgpofix /target:both 2>&1 | ForEach-Object { Write-Host "    $_" }
gpupdate /force

# Import all GPO backups
Get-ChildItem -Path $extractPath -Directory -Filter "{*}" | ForEach-Object {
    $xml = [xml](Get-Content "$($_.FullName)\Backup.xml")
    $name = $xml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
    $id   = $_.Name -replace '[{}]'
    New-GPO -Name $name -ErrorAction SilentlyContinue | Out-Null
    try {
        Import-GPO -BackupId $id -Path $extractPath -TargetName $name -ErrorAction Stop
        New-GPLink -Name $name -Target $DomainDN -LinkEnabled Yes -ErrorAction SilentlyContinue
        Write-Host "  [+] Imported & linked: $name" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Failed to import '$name': $_" -ForegroundColor Red
    }
}

# Local registry fix (GPO import doesn't do this)
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" `
    -Name "SCENoApplyLegacyAuditPolicy" -Value 0 -Type DWord -Force

gpupdate /force
Write-Host "[+] GPO import complete" -ForegroundColor Green
```

</details>

<details>
<summary>WinStride Service Setup</summary>

### Server

From the existing WinStride folder:

```powershell
cd C:\WinStride
powershell -ExecutionPolicy Bypass -File .\scripts\setup-winstride.ps1 -Auto
powershell -ExecutionPolicy Bypass -File .\scripts\start-winstride.ps1
```

This:
- checks or installs `.NET 8` and Node.js
- installs `WinStrideApi` and `WinStrideAgent` Windows services
- starts the web UI on `http://localhost:5173`
- tries to create the WinStride API firewall rule from AD computer IPs if this box is the domain controller
- prints manual firewall commands if that discovery fails

Verify:

```powershell
Get-Service WinStrideApi,WinStrideAgent
Invoke-WebRequest http://localhost:5090/swagger
Start-Process http://localhost:5173
```

### Firewall allow-list update

HTTP:

```powershell
Get-NetFirewallRule -DisplayName "WinStride API TCP 5090" |
  Get-NetFirewallAddressFilter |
  Set-NetFirewallAddressFilter -RemoteAddress @("10.0.0.10","10.0.0.11","10.0.1.0/24")
```

HTTPS:

```powershell
Get-NetFirewallRule -DisplayName "WinStride API TCP 7097" |
  Get-NetFirewallAddressFilter |
  Set-NetFirewallAddressFilter -RemoteAddress @("10.0.0.10","10.0.0.11","10.0.1.0/24")
```

### Remote agent HTTP

On the other Windows machine, from the existing WinStride folder:

```powershell
cd C:\WinStride
powershell -ExecutionPolicy Bypass -File .\scripts\install-run-agent.ps1
```

That assumes the WinStride server is the domain controller. If not:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-run-agent.ps1 -ServerAddress "dc01.corp.local"
```

### HTTPS

On the server:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-certs.ps1 -CAName "YOUR-DOMAIN-CA"
```

On the agent:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-run-agent.ps1 -UseHttps -PfxPath ".\WinStride-Agent.pfx"
```

If the WinStride server is not the domain controller:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-run-agent.ps1 -UseHttps -PfxPath ".\WinStride-Agent.pfx" -ServerAddress "server.domain.local"
```

### Quick checks

```powershell
Restart-Service WinStrideApi,WinStrideAgent
Test-NetConnection SERVER-IP -Port 5090
```

</details>

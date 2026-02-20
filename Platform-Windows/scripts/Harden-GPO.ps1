<#
.SYNOPSIS
    Domain GPO hardening script. Run once on the DC; settings propagate domain-wide.

.DESCRIPTION
    Replaces the old enforce-gpo Ansible role. Creates a "Hardening" GPO (or custom name)
    linked to the domain root, then applies audit, password, encryption, credential-protection,
    and network-hardening settings through that GPO.

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
function Write-Warn { param([string]$Text); Write-Host "  [!] $Text" -ForegroundColor Yellow }

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
    # Guaranteed zero breakage: logging + passwords only
    Write-Banner "Mode: SUPER-SAFE (logging + passwords only)"
    $runReset            = $false
    $runAuditPolicy      = $true
    $runPasswordPolicy   = $true
    $runScriptPolicy     = $false
    $runEncryption       = $false
    $runCredProtection   = $false
    $runNetworkHardening = $false
} elseif ($Safe) {
    # Safe: adds hardening that won't break standard services
    Write-Banner "Mode: SAFE (skipping risky settings)"
    $runReset            = $false
    $runAuditPolicy      = $true
    $runPasswordPolicy   = $true
    $runScriptPolicy     = $false   # AllSigned can break scripts
    $runEncryption       = $true    # but individual risky settings skipped below
    $runCredProtection   = $true
    $runNetworkHardening = $true    # but service disabling skipped below
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
    & gpupdate /force 2>&1 | Out-Null
    $summary += "GPO Reset"
    Write-Setting "GPO reset complete"
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

    # Link to domain root (ignore if already linked)
    try {
        New-GPLink -Name $GPOName -Target $DomainDN -LinkEnabled Yes -ErrorAction Stop | Out-Null
        Write-Setting "Linked GPO to $DomainDN"
    } catch {
        if ($_.Exception.Message -match "already linked|already exists") {
            Write-Setting "GPO already linked to $DomainDN"
        } else { throw }
    }
}

# ── Audit Policy ─────────────────────────────────────────────────────────────

if ($runAuditPolicy) {
    Write-Banner "Audit Policy"

    # Write legacy audit policy via GptTmpl.inf (reliable GPO method)
    Write-Setting "Writing audit policy to GptTmpl.inf"
    $gpoId = "{$($gpo.Id.ToString().ToUpper())}"
    $secEditPath = "\\$Domain\SYSVOL\$Domain\Policies\$gpoId\Machine\Microsoft\Windows NT\SecEdit"

    if (-not (Test-Path $secEditPath)) {
        New-Item -Path $secEditPath -ItemType Directory -Force | Out-Null
    }

    # 3 = Success and Failure for all 9 audit categories
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
AuditPrivilegeUse = 3
AuditPolicyChange = 3
AuditAccountManage = 3
AuditProcessTracking = 3
AuditDSAccess = 3
AuditAccountLogon = 3
"@
    $gptTmpl | Out-File -FilePath "$secEditPath\GptTmpl.inf" -Encoding Unicode -Force
    Write-Setting "GptTmpl.inf written (all 9 categories: Success and Failure)"

    # Register Security CSE on the GPO AD object
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

    # Bump GPO version so clients pick up the change
    $gpoAD = Get-ADObject -Identity $gpoDN -Properties versionNumber
    $newVer = [int]$gpoAD.versionNumber + 65536
    Set-ADObject -Identity $gpoDN -Replace @{versionNumber = $newVer}
    # Sync GPT.INI version
    $gptIniPath = "\\$Domain\SYSVOL\$Domain\Policies\$gpoId\GPT.INI"
    $gptIniContent = Get-Content $gptIniPath -Raw -ErrorAction SilentlyContinue
    if ($gptIniContent) {
        $gptIniContent = $gptIniContent -replace "Version=\d+", "Version=$newVer"
        $gptIniContent | Out-File -FilePath $gptIniPath -Encoding ASCII -Force
    }
    Write-Setting "GPO version bumped to $newVer"

    # Ensure SCENoApplyLegacyAuditPolicy is OFF so legacy audit policy applies
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "SCENoApplyLegacyAuditPolicy" -Value 0
    # Also fix locally in case it was set by a previous run
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "SCENoApplyLegacyAuditPolicy" -Value 0 -Type DWord -Force
    Write-Setting "SCENoApplyLegacyAuditPolicy = 0 (legacy audit enabled)"

    # Registry-based logging settings (via GPO for domain-wide)
    Write-Setting "Configuring registry-based logging"

    # Command-line process auditing
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
        -ValueName "ProcessCreationIncludeCmdLine_Enabled" -Value 1

    # PowerShell Script Block Logging
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
        -ValueName "EnableScriptBlockLogging" -Value 1

    # PowerShell Module Logging
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging" `
        -ValueName "EnableModuleLogging" -Value 1
    Set-GPRegistryValue -Name $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" `
        -ValueName "*" -Value "*" -Type String | Out-Null
    Write-Setting "  ModuleNames\* = *"

    # PowerShell Transcription
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\Transcription" `
        -ValueName "EnableTranscripting" -Value 1
    Set-GPRegistryValue -Name $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\Transcription" `
        -ValueName "OutputDirectory" -Value "C:\PSTranscripts" -Type String | Out-Null
    Write-Setting "  Transcription OutputDirectory = C:\PSTranscripts"

    # Security log size: 1 GB
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\EventLog\Security" `
        -ValueName "MaxSize" -Value 1048576

    $summary += "Audit Policy"
}

# ── Password Policy ──────────────────────────────────────────────────────────

if ($runPasswordPolicy) {
    Write-Banner "Password & Lockout Policy"

    Set-ADDefaultDomainPasswordPolicy -Identity $Domain `
        -MinPasswordLength 16 `
        -PasswordHistoryCount 24 `
        -MinPasswordAge ([TimeSpan]::Zero) `
        -ComplexityEnabled $true `
        -LockoutThreshold 10 `
        -LockoutDuration (New-TimeSpan -Minutes 15) `
        -LockoutObservationWindow (New-TimeSpan -Minutes 15)

    Write-Setting "MinPasswordLength      = 16"
    Write-Setting "PasswordHistoryCount   = 24"
    Write-Setting "MinPasswordAge         = 0"
    Write-Setting "ComplexityEnabled      = True"
    Write-Setting "LockoutThreshold       = 10"
    Write-Setting "LockoutDuration        = 15 min"
    Write-Setting "LockoutObservationWindow = 15 min"

    $summary += "Password Policy"
}

# ── Script Execution Policy ──────────────────────────────────────────────────

if ($runScriptPolicy) {
    Write-Banner "Script Execution Policy"

    Set-GPRegistryValue -Name $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell" `
        -ValueName "ExecutionPolicy" -Value "AllSigned" -Type String | Out-Null
    Write-Setting "ExecutionPolicy = AllSigned"

    $summary += "Script Policy"
}

# ── Encryption Hardening ─────────────────────────────────────────────────────

if ($runEncryption) {
    Write-Banner "Encryption Hardening"

    # SMB signing - server
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\LanManServer\Parameters" `
        -ValueName "RequireSecuritySignature" -Value 1

    # SMB signing - client
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
        -ValueName "RequireSecuritySignature" -Value 1

    # Disable SMB1
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\LanManServer\Parameters" `
        -ValueName "SMB1" -Value 0

    if (-not $Safe) {
        # Kerberos AES-only (24 = AES128 + AES256) — can break RC4-dependent services
        Set-RegValue -GPOName $GPOName `
            -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" `
            -ValueName "SupportedEncryptionTypes" -Value 24

        # NTLMv2 only - refuse LM & NTLM — can break WinRM by IP
        Set-RegValue -GPOName $GPOName `
            -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
            -ValueName "LmCompatibilityLevel" -Value 5
    } else {
        # Safe: NTLMv2 preferred but don't refuse NTLM (level 3)
        Set-RegValue -GPOName $GPOName `
            -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
            -ValueName "LmCompatibilityLevel" -Value 3
        Write-Warn "Skipped Kerberos AES-only (Safe mode)"
        Write-Warn "Using LmCompatibilityLevel 3 instead of 5 (Safe mode)"
    }

    # LDAP server signing required
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\NTDS\Parameters" `
        -ValueName "LDAPServerIntegrity" -Value 2

    # LDAP client signing required
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\ldap" `
        -ValueName "LDAPClientIntegrity" -Value 2

    if (-not $Safe) {
        # LDAP channel binding — can break Linux LDAP clients
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

    # Disable WDigest
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\SecurityProviders\WDigest" `
        -ValueName "UseLogonCredential" -Value 0

    # LSA RunAsPPL
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "RunAsPPL" -Value 2

    # Restrict anonymous SAM enumeration
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "RestrictAnonymousSAM" -Value 1

    # Restrict anonymous access
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "RestrictAnonymous" -Value 1

    # Everyone does NOT include anonymous
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "EveryoneIncludesAnonymous" -Value 0

    # Restrict remote SAM calls
    Set-GPRegistryValue -Name $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "RestrictRemoteSAM" -Value "O:BAG:BAD:(A;;RC;;;BA)" -Type String | Out-Null
    Write-Setting "HKLM\System\CurrentControlSet\Control\Lsa\RestrictRemoteSAM = O:BAG:BAD:(A;;RC;;;BA)"

    $summary += "Credential Protection"
}

# ── Network Hardening ────────────────────────────────────────────────────────

if ($runNetworkHardening) {
    Write-Banner "Network Hardening"

    # Disable LLMNR
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Policies\Microsoft\Windows NT\DNSClient" `
        -ValueName "EnableMulticast" -Value 0

    # Disable NBT-NS (registry wildcard not possible via GPO, set on common interface key)
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Services\NetBT\Parameters" `
        -ValueName "NodeType" -Value 2

    # Disable WPAD
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" `
        -ValueName "DisableWpad" -Value 1

    # NLA for RDP
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -ValueName "UserAuthentication" -Value 1

    # RDP TLS
    Set-RegValue -GPOName $GPOName `
        -Key "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -ValueName "SecurityLayer" -Value 2

    if (-not $Safe) {
        # Disable unnecessary services (Start = 4 means Disabled)
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

# ── Summary ──────────────────────────────────────────────────────────────────

Write-Banner "Complete"
Write-Host ""
if ($summary.Count -eq 0) {
    Write-Host "  No sections were executed." -ForegroundColor Yellow
} else {
    Write-Host "  Sections applied:" -ForegroundColor Green
    foreach ($s in $summary) { Write-Host "    - $s" -ForegroundColor Green }
}
Write-Host ""
Write-Host "  Verify with:" -ForegroundColor White
Write-Host "    gpmc.msc            - '$GPOName' GPO linked to domain" -ForegroundColor Gray
Write-Host "    auditpol /get /category:* - audit categories on DC" -ForegroundColor Gray
Write-Host "    gpresult /r         - on remote machines after gpupdate" -ForegroundColor Gray
Write-Host "    net accounts        - password policy" -ForegroundColor Gray
Write-Host ""

param()

# 1. Elevate to Administrator if not already running as Admin
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Restarting script with administrator rights..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Clear-Host
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Running comprehensive security audit, please wait..." -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

# --- AUDIT CORE LOGIC ---

# 1. Antivirus & Microsoft Defender Status
try {
    $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if (-not $defender) {
        $results.Add([PSCustomObject]@{ Component = "Antivirus Protection"; Status = "FAIL"; Details = "Unable to query Microsoft Defender status"; Fix = "Verify Windows Security service is running." })
    } else {
        if ($defender.RealTimeProtectionEnabled -eq $true) {
            $age = $defender.AntivirusSignatureAge
            $details = "Defender Active | Signature Age: $age day(s)"
            if ($age -gt 3) {
                $results.Add([PSCustomObject]@{ Component = "Antivirus Protection"; Status = "WARN"; Details = "$details (Signatures Outdated)"; Fix = "Run Windows Update or trigger manual Defender signature update." })
            } else {
                $results.Add([PSCustomObject]@{ Component = "Antivirus Protection"; Status = "OK"; Details = $details; Fix = "" })
            }
        } else {
            $results.Add([PSCustomObject]@{ Component = "Antivirus Protection"; Status = "FAIL"; Details = "Real-Time Protection is DISABLED"; Fix = "Enable Real-Time Protection immediately in Windows Security settings." })
        }
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Antivirus Protection"; Status = "FAIL"; Details = "Critical error querying AV provider"; Fix = "Check for malicious modifications or broken WMI repository." })
}

# 2. Windows Firewall Profile Status
try {
    $fwProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    $disabledProfiles = $fwProfiles | Where-Object { $_.Enabled -eq "False" }
    
    if ($disabledProfiles) {
        $pNames = ($disabledProfiles | Select-Object -ExpandProperty Name) -join ", "
        $results.Add([PSCustomObject]@{ Component = "Windows Firewall"; Status = "FAIL"; Details = "Disabled profiles detected: [$pNames]"; Fix = "Run 'Set-NetFirewallProfile -All -Enabled True' to re-enable all profiles." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "Windows Firewall"; Status = "OK"; Details = "All Firewall profiles (Domain, Private, Public) are active"; Fix = "" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Windows Firewall"; Status = "FAIL"; Details = "Failed to query Firewall state"; Fix = "Restart Windows Firewall Service (MpsSvc)." })
}

# 3. BitLocker Drive Encryption (OS Drive C:)
try {
    $bitlocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
    if (-not $bitlocker) {
        $results.Add([PSCustomObject]@{ Component = "Drive Encryption (C:)"; Status = "WARN"; Details = "BitLocker is not configured or unsupported on C:"; Fix = "Enable BitLocker in Control Panel to protect data at rest." })
    } else {
        $pStatus = $bitlocker.ProtectionStatus
        $vStatus = $bitlocker.VolumeStatus
        
        if ($pStatus -eq "On" -and $vStatus -eq "FullyEncrypted") {
            $results.Add([PSCustomObject]@{ Component = "Drive Encryption (C:)"; Status = "OK"; Details = "BitLocker Active | Fully Encrypted ($($bitlocker.EncryptionMethod))"; Fix = "" })
        } else {
            $results.Add([PSCustomObject]@{ Component = "Drive Encryption (C:)"; Status = "FAIL"; Details = "Protection is $pStatus | Volume is $vStatus"; Fix = "Resume BitLocker protection or complete the encryption process." })
        }
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Drive Encryption (C:)"; Status = "FAIL"; Details = "Error querying BitLocker configuration"; Fix = "Ensure TPM is enabled in BIOS and BitLocker services are active." })
}

# 4. User Account Control (UAC) Level
try {
    $uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $consentPrompt = (Get-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue).ConsentPromptBehaviorAdmin
    $promptOnSecure = (Get-ItemProperty -Path $uacPath -Name "PromptOnSecureDesktop" -ErrorAction SilentlyContinue).PromptOnSecureDesktop
    
    if ($consentPrompt -eq 0) {
        $results.Add([PSCustomObject]@{ Component = "User Account Control"; Status = "FAIL"; Details = "UAC is completely DISABLED (Silent Elevate)"; Fix = "Restore UAC to default to prevent silent malicious execution." })
    } elseif ($promptOnSecure -eq 0) {
        $results.Add([PSCustomObject]@{ Component = "User Account Control"; Status = "WARN"; Details = "UAC active, but Secure Desktop is DISABLED"; Fix = "Enable Secure Desktop to prevent UAC credential interception." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "User Account Control"; Status = "OK"; Details = "UAC is active and enforced on Secure Desktop"; Fix = "" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "User Account Control"; Status = "FAIL"; Details = "Failed to read UAC registry settings"; Fix = "Check registry permissions on HKLM System Policies." })
}

# 5. Local Administrators Audit
try {
    $adminGroup = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
    $localAdmins = $adminGroup | Where-Object { $_.PrincipalSource -eq "Local" } | Select-Object -ExpandProperty Name
    $adminCount = $localAdmins.Count
    
    $adminList = $localAdmins -join ", "
    
    if ($adminCount -gt 2) {
        $results.Add([PSCustomObject]@{ Component = "Local Administrators"; Status = "WARN"; Details = "High number of Local Admins ($adminCount): [$adminList]"; Fix = "Review membership. Remove unnecessary accounts to minimize attack surface." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "Local Administrators"; Status = "OK"; Details = "Authorized Admins: [$adminList]"; Fix = "" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Local Administrators"; Status = "FAIL"; Details = "Unable to audit Local Administrators group"; Fix = "Verify SAM accounts database integrity." })
}

# 6. Unsecured Network Shares (SMB)
try {
    $shares = Get-SmbShare -ErrorAction SilentlyContinue
    $customShares = $shares | Where-Object { $_.Name -notmatch '^(C\$|ADMIN\$|IPC\$)$' }
    
    if ($customShares) {
        $shareNames = ($customShares | Select-Object -ExpandProperty Name) -join ", "
        $results.Add([PSCustomObject]@{ Component = "Network Shares"; Status = "WARN"; Details = "Custom network shares active: [$shareNames]"; Fix = "Ensure these shares are password-protected and not exposed to public profiles." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "Network Shares"; Status = "OK"; Details = "No custom/unsecured network shares exposed"; Fix = "" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Network Shares"; Status = "FAIL"; Details = "Failed to query SMB shares configuration"; Fix = "Check if Server service (LanmanServer) is running." })
}

# 7. Third-Party Security Agents & Traffic Filters
try {
    $securityAgents = @{
        "WSSAgent"      = "Symantec Web Security Service"
        "ZSAgent"       = "Zscaler Client Connector"
        "AnyConnect"    = "Cisco AnyConnect / Umbrella"
        "CSFalconService" = "CrowdStrike Falcon"
        "SentinelAgent" = "SentinelOne EDR"
        "CyborgService" = "Cortex XDR (Palo Alto)"
        "Mimecast.Services.Windows" = "Mimecast Web Security"
    }
    
    $detectedAgents = [System.Collections.Generic.List[string]]::new()
    
    foreach ($serviceName in $securityAgents.Keys) {
        $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            $detectedAgents.Add($securityAgents[$serviceName])
        }
    }
    
    $proxyReg = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    $proxyEnabled = $proxyReg.ProxyEnable
    $pacFile = $proxyReg.AutoConfigURL
    
    if ($detectedAgents.Count -gt 0) {
        $agentsStr = $detectedAgents -join ", "
        $results.Add([PSCustomObject]@{ Component = "Security Agents"; Status = "OK"; Details = "Detected Active Software: [$agentsStr]"; Fix = "" })
    } elseif ($proxyEnabled -eq 1 -or !([string]::IsNullOrEmpty($pacFile))) {
        $proxyDetails = if ($proxyEnabled -eq 1) { "Local Proxy Active ($($proxyReg.ProxyServer))" } else { "PAC File Enforced" }
        $results.Add([PSCustomObject]@{ Component = "Security Agents"; Status = "WARN"; Details = "No known agent found, but traffic filtering is active: $proxyDetails"; Fix = "If this is a personal machine without a VPN/Filter, disable proxy in Internet Settings." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "Security Agents"; Status = "OK"; Details = "No third-party EDR or Traffic Filters detected (Pure Local Routing)"; Fix = "" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Security Agents"; Status = "FAIL"; Details = "Error auditing third-party network filters"; Fix = "Check system event logs for Service Control Manager issues." })
}


# --- OUTPUT GENERATION (DASHBOARD) ---

Clear-Host
Write-Host "┌────────────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│                               SECURITY & COMPLIANCE AUDIT                              │" -ForegroundColor Cyan
Write-Host "└────────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host "  Host:      $($env:COMPUTERNAME.PadRight(15))  Audit Profile: Personal Security Baseline"
Write-Host "  Account:   $($env:USERNAME.PadRight(15))  Privileges:    SYSTEM_ADMINISTRATOR"
Write-Host " ────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""

foreach ($res in $results) {
    switch ($res.Status) {
        "OK"   { $color = "Green";  $tag = "  [✔]  " }
        "WARN" { $color = "Yellow"; $tag = "  [⚠]  " }
        "FAIL" { $color = "Red";    $tag = "  [✘]  " }
    }
    
    Write-Host $tag -ForegroundColor $color -NoNewline
    Write-Host "$($res.Component.PadRight(25)) $($res.Details)"
    
    if ($res.Fix) {
        Write-Host "       ↳ Fix: $($res.Fix)" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host " ────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""

$stopwatch.Stop()
$elapsedSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)

Read-Host "Security audit complete in $elapsedSeconds seconds. Press ENTER to close the window"
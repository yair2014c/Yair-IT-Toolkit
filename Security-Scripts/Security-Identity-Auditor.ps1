param(
    [int]$StaleDaysThreshold = 90
)

$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Restarting script with administrator rights..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Clear-Host
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Running Identity & Access Audit, please wait..." -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

try {
    $adminGroup = Get-LocalGroup | Where-Object { $_.SID -eq 'S-1-5-32-544' }
    if ($adminGroup) {
        $adminMembers = Get-LocalGroupMember -Group $adminGroup.Name -ErrorAction SilentlyContinue
        $memberNames = ($adminMembers | Select-Object -ExpandProperty Name) -join ", "
        if ($adminMembers.Count -gt 2) {
            $results.Add([PSCustomObject]@{Component = "Local Administrators"; Status = "WARN"; Details = "High member count ($($adminMembers.Count) users): [$memberNames]"; Fix = "Review members and remove unnecessary accounts from the Administrators group."})
        } else {
            $results.Add([PSCustomObject]@{Component = "Local Administrators"; Status = "OK"; Details = "Secure member count ($($adminMembers.Count) users): [$memberNames]"; Fix = $null})
        }
    } else {
        $results.Add([PSCustomObject]@{ Component = "Local Administrators"; Status = "FAIL"; Details = "Unable to resolve Local Administrators group SID"; Fix = "Verify SAM database integrity." })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Local Administrators"; Status = "FAIL"; Details = "Error querying group: $($_.Exception.Message)"; Fix = $null })
}

try {
    $staleCutoff = (Get-Date).AddDays(-$StaleDaysThreshold)
    $localUsers = Get-LocalUser -ErrorAction SilentlyContinue
    $staleUsers = $localUsers | Where-Object { $_.Enabled -eq $true -and (($_.LastLogon -lt $staleCutoff) -or ($_.LastLogon -eq $null)) -and $_.Name -notmatch "Administrator|Guest|DefaultAccount" }
    if ($staleUsers) {
        $staleNames = ($staleUsers | Select-Object -ExpandProperty Name) -join ", "
        $results.Add([PSCustomObject]@{Component = "Stale User Accounts"; Status = "WARN"; Details = "Found active accounts inactive for >$StaleDaysThreshold days: [$staleNames]"; Fix = "Disable or delete inactive accounts to reduce attack surface."})
    } else {
        $results.Add([PSCustomObject]@{Component = "Stale User Accounts"; Status = "OK"; Details = "All active local accounts have logged in recently."; Fix = $null})
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Stale User Accounts"; Status = "FAIL"; Details = "Error scanning local users: $($_.Exception.Message)"; Fix = $null })
}

try {
    $pneUsers = $localUsers | Where-Object { $_.Enabled -eq $true -and $_.PasswordNeverExpires -eq $true -and $_.Name -notmatch "Administrator|Guest|DefaultAccount" }
    if ($pneUsers) {
        $pneNames = ($pneUsers | Select-Object -ExpandProperty Name) -join ", "
        $results.Add([PSCustomObject]@{Component = "Password Expiry"; Status = "WARN"; Details = "Accounts set to 'Password Never Expires': [$pneNames]"; Fix = "Enforce periodic password changes via 'Set-LocalUser -Name <User> -PasswordNeverExpires `$false'."})
    } else {
        $results.Add([PSCustomObject]@{Component = "Password Expiry"; Status = "OK"; Details = "All personal active accounts comply with rotation baselines."; Fix = $null})
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Password Expiry"; Status = "FAIL"; Details = "Error checking password policies: $($_.Exception.Message)"; Fix = $null })
}

try {
    $noPassUsers = $localUsers | Where-Object { $_.Enabled -eq $true -and $_.PasswordRequired -eq $false -and $_.Name -notmatch "Guest|DefaultAccount" }
    if ($noPassUsers) {
        $noPassNames = ($noPassUsers | Select-Object -ExpandProperty Name) -join ", "
        $results.Add([PSCustomObject]@{Component = "Password Requirement"; Status = "FAIL"; Details = "Accounts that do not require a password: [$noPassNames]"; Fix = "Run 'Set-LocalUser -Name <User> -PasswordRequired `$true' immediately."})
    } else {
        $results.Add([PSCustomObject]@{Component = "Password Requirement"; Status = "OK"; Details = "All active accounts strictly require a password."; Fix = $null})
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Password Requirement"; Status = "FAIL"; Details = "Error checking password requirements: $($_.Exception.Message)"; Fix = $null })
}

Clear-Host
$Line = "────────────────────────────────────────────────────────────────────────────────────────"
Write-Host "`n┌$Line┐" -ForegroundColor Cyan
Write-Host "│                               IDENTITY & ACCESS AUDITOR                                │" -ForegroundColor Cyan
Write-Host "└$Line┘" -ForegroundColor Cyan
Write-Host "  Host:      $($env:COMPUTERNAME.PadRight(15))  Audit Scope: Local SAM Database"
Write-Host "  Account:   $($env:USERNAME.PadRight(15))  Threshold:   $StaleDaysThreshold Days Inactivity"
Write-Host " $Line" -ForegroundColor Cyan
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
Write-Host "Audit completed in $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) seconds.`n" -ForegroundColor Gray
Read-Host "Press Enter to return to main menu"
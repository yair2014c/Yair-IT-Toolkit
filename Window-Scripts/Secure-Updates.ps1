Clear-Host
$Line = "=========================================================="
Write-Host "`n$Line" -ForegroundColor Cyan
Write-Host "       WINDOWS SECURE UPDATE TOOLKIT (NATIVE)" -ForegroundColor Cyan
Write-Host "$Line`n" -ForegroundColor Cyan

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] ERROR: PLEASE RUN AS ADMINISTRATOR." -ForegroundColor Red
    pause; exit
}

Write-Host "[*] STEP 1: Creating System Restore Point..." -ForegroundColor Yellow
Checkpoint-Computer -Description "BeforeSecureUpdate" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue

Write-Host "`n[*] STEP 2: Scanning for Security Updates (Native Mode)..." -ForegroundColor Yellow

try {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
    
    $Criteria = "Security", "Critical"
    $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

    foreach ($Update in $SearchResult.Updates) {
        $IsCritical = $false
        foreach ($Category in $Update.Categories) {
            if ($Criteria -contains $Category.Name) { $IsCritical = $true }
        }
        
        if ($IsCritical) {
            Write-Host "[+] Found: $($Update.Title)" -ForegroundColor White
            $UpdatesToInstall.Add($Update) | Out-Null
        }
    }

    if ($UpdatesToInstall.Count -gt 0) {
        Write-Host "`n[*] Downloading and Installing $($UpdatesToInstall.Count) updates..." -ForegroundColor Green
        $UpdateDownloader = $UpdateSession.CreateUpdateDownloader()
        $UpdateDownloader.Updates = $UpdatesToInstall
        $UpdateDownloader.Download() | Out-Null
        
        $Installer = $UpdateSession.CreateUpdateInstaller()
        $Installer.Updates = $UpdatesToInstall
        $InstallationResult = $Installer.Install()
        Write-Host "[+] Installation Complete." -ForegroundColor Green
    } else {
        Write-Host "[+] No critical security updates found." -ForegroundColor Green
    }
}
catch {
    Write-Host "[-] Native scan failed. Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n$Line" -ForegroundColor Cyan
Write-Host "                   VERIFICATION REPORT" -ForegroundColor Cyan
Write-Host "$Line" -ForegroundColor Cyan
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 3 | Format-Table -AutoSize
Get-ComputerRestorePoint | Select-Object -Last 1 | Format-Table -AutoSize
Write-Host "`n$Line" -ForegroundColor Green
Write-Host " PROCESS COMPLETE." -ForegroundColor Green
pause
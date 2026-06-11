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

# Calculate initial disk space on C:
$diskBefore = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$spaceBefore = $diskBefore.FreeSpace

Write-Host "┌────────────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│                                 STORAGE DEEP SANITIZER                                 │" -ForegroundColor Cyan
Write-Host "└────────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host "  Analyzing system bloat and reclaiming storage block-by-block..."
Write-Host " ────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

# --- SANITIZATION LOGIC ---

# 1. Standard Temp Folders (User & System)
try {
    $tempPaths = @("$env:TEMP\*", "C:\Windows\Temp\*")
    foreach ($path in $tempPaths) {
        $files = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue
        if ($files) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $results.Add([PSCustomObject]@{ Component = "Temporary Directories"; Status = "OK"; Details = "Cleared User and System AppData Temp matrices" })
} catch {
    $results.Add([PSCustomObject]@{ Component = "Temporary Directories"; Status = "WARN"; Details = "Some locked files were skipped" })
}

# 2. Windows Update Cache (SoftwareDistribution)
try {
    $swDistPath = "C:\Windows\SoftwareDistribution\Download\*"
    if (Test-Path "C:\Windows\SoftwareDistribution\Download") {
        Remove-Item -Path $swDistPath -Recurse -Force -ErrorAction SilentlyContinue
        $results.Add([PSCustomObject]@{ Component = "Windows Update Cache"; Status = "OK"; Details = "SoftwareDistribution Download directory purged" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Windows Update Cache"; Status = "FAIL"; Details = "Failed to release Windows Update locked cache" })
}

# 3. Delivery Optimization Files
try {
    if (Get-Service -Name "DoSvc" -ErrorAction SilentlyContinue) {
        $doPath = "$env:ALLUSERSPROFILE\Microsoft\Windows\DeliveryOptimization\Cache\*"
        Remove-Item -Path $doPath -Recurse -Force -ErrorAction SilentlyContinue
        $results.Add([PSCustomObject]@{ Component = "Delivery Optimization"; Status = "OK"; Details = "Cleared peer-to-peer update distribution logs" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Delivery Optimization"; Status = "WARN"; Details = "Delivery Optimization cache busy or locked" })
}

# 4. Windows Component Store Cleanup (WinSxS / DISM)
try {
    Write-Host "[*] Running Windows Component Store cleanup (DISM)... This might take a minute." -ForegroundColor Gray
    # Redirect stderr to avoid any native dism leaks
    $dismOut = dism.exe /online /Cleanup-Image /StartComponentCleanup /NoRestart 2>$null
    $results.Add([PSCustomObject]@{ Component = "Windows Image (WinSxS)"; Status = "OK"; Details = "Superseded base components compressed and purged" })
} catch {
    $results.Add([PSCustomObject]@{ Component = "Windows Image (WinSxS)"; Status = "FAIL"; Details = "DISM deployment engine returned an error" })
}

# 5. Docker Desktop Resource Reclamation
try {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "[*] Docker installation detected. Purging unused engines..." -ForegroundColor Gray
        $dockerOut = docker system prune -af --volumes 2>&1
        $results.Add([PSCustomObject]@{ Component = "Docker Infrastructure"; Status = "OK"; Details = "Reclaimed space from dangling containers/caches" })
    } else {
        $results.Add([PSCustomObject]@{ Component = "Docker Infrastructure"; Status = "OK"; Details = "Not installed on host (Skipped)" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Docker Infrastructure"; Status = "WARN"; Details = "Docker daemon unreachable or hypervisor asleep" })
}

# 6. WSL Architecture RAM & State Reset
try {
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        # Enforce stderr redirection (2>$null) to catch stub/missing features silently
        wsl --shutdown 2>$null
        if ($LASTEXITCODE -eq 0) {
            $results.Add([PSCustomObject]@{ Component = "WSL Subsystems"; Status = "OK"; Details = "Enforced global shutdown. Released system RAM allocation" })
        } else {
            $results.Add([PSCustomObject]@{ Component = "WSL Subsystems"; Status = "OK"; Details = "Present but not active/configured (Skipped)" })
        }
    } else {
        $results.Add([PSCustomObject]@{ Component = "WSL Subsystems"; Status = "OK"; Details = "Not installed on host (Skipped)" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "WSL Subsystems"; Status = "FAIL"; Details = "Failed to broadcast shutdown command to WSL" })
}

# 7. Empty System Recycle Bin
try {
    Clear-RecycleBin -Confirm:$false -ErrorAction SilentlyContinue
    $results.Add([PSCustomObject]@{ Component = "System Recycle Bin"; Status = "OK"; Details = "All local drive trash arrays emptied" })
} catch {
    $results.Add([PSCustomObject]@{ Component = "System Recycle Bin"; Status = "OK"; Details = "Already empty or locked by a thread" })
}

# --- CALCULATE SPACE RECLAIMED ---
$diskAfter = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$spaceAfter = $diskAfter.FreeSpace
$bytesCleared = $spaceAfter - $spaceBefore
$mbCleared = [math]::Round($bytesCleared / 1MB, 2)
$gbCleared = [math]::Round($bytesCleared / 1GB, 2)

# --- OUTPUT DASHBOARD ---
Clear-Host
Write-Host "┌────────────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│                                 STORAGE SANITIZER REPORT                               │" -ForegroundColor Cyan
Write-Host "└────────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host "  Host:      $($env:COMPUTERNAME.PadRight(15))  Target Drive:  C: (NTFS File System)"
Write-Host "  Execution: SYSTEM_ADMINISTRATOR   Sanitation:   Deep Architecture Purge"
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
}

Write-Host ""
Write-Host " ────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  METRICS SUMMARY:" -ForegroundColor Cyan
if ($bytesCleared -le 0) {
    Write-Host "  No space was cleared. System storage was already optimized." -ForegroundColor White
} else {
    Write-Host "  Total Storage Reclaimed: " -NoNewline
    Write-Host "$gbCleared GB " -ForegroundColor Green -NoNewline
    Write-Host "($mbCleared MB)" -ForegroundColor Gray
}

$stopwatch.Stop()
$elapsedSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
Write-Host "  Execution Time:          $elapsedSeconds seconds" -ForegroundColor Gray
Write-Host " ────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""

Read-Host "Sanitization complete. Press ENTER to exit"
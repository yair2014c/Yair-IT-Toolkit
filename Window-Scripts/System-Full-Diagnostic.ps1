param(
    [switch]$RunIntegrityChecks
)

$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Restarting script with administrator rights..." -ForegroundColor Yellow
    $arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($RunIntegrityChecks) { $arguments += " -RunIntegrityChecks" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

Clear-Host
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Running diagnostics, please wait..." -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem

$chassisType = switch ($cs.PCSystemType) {
    1 { "Desktop" }
    2 { "Laptop" }
    3 { "Workstation" }
    4 { "Enterprise Server" }
    default { "Virtual Machine / Unknown" }
}

$cleanVendor = $cs.Manufacturer -replace " COMPUTER INC\.| Inc\.| Corporation| Ltd\.", ""
if ($cleanVendor -match "ASUSTeK") { $cleanVendor = "ASUS" }
$hardwareModel = "$cleanVendor $($cs.Model)"

$uptimeSpan = (Get-Date) - $os.LastBootUpTime
$uptimeString = "{0}d {1}h {2}m" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes

$cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$ramUsedPercent = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)

$rebootPending = $false
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) { $rebootPending = $true }
if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) { $rebootPending = $true }
if ($rebootPending) {
    $results.Add([PSCustomObject]@{ Component = "Pending Reboot"; Status = "WARN"; Details = "System requires a restart to finish updates"; Fix = "Reboot the PC to apply pending system changes." })
}

Get-Volume | Where-Object DriveLetter | ForEach-Object {
    $freePercent = [math]::Round(($_.SizeRemaining / $_.Size) * 100,2)
    if ($freePercent -lt 10) {
        $results.Add([PSCustomObject]@{ Component = "Storage ($($_.DriveLetter):)"; Status = "WARN"; Details = "Low space ($freePercent% free)"; Fix = "Clean temp files or move data to another drive." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "Storage ($($_.DriveLetter):)"; Status = "OK"; Details = "Healthy ($freePercent% free)"; Fix = "" })
    }
}

try {
    $smartData = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop
    foreach ($disk in $smartData) {
        if ($disk.PredictFailure) {
            $results.Add([PSCustomObject]@{ Component = "Disk SMART"; Status = "FAIL"; Details = "Hardware failure predicted!"; Fix = "Backup immediately and replace drive." })
        } else {
            $results.Add([PSCustomObject]@{ Component = "Disk SMART"; Status = "OK"; Details = "Drive health is normal"; Fix = "" })
        }
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Disk SMART"; Status = "WARN"; Details = "Could not collect SMART data"; Fix = "Check WMI service status." })
}

try {
    $defender = Get-MpComputerStatus -ErrorAction Stop
    if (-not $defender.RealTimeProtectionEnabled) {
        $results.Add([PSCustomObject]@{ Component = "Windows Defender"; Status = "FAIL"; Details = "Real-time protection is DISABLED"; Fix = "Enable it in Windows Security." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "Windows Defender"; Status = "OK"; Details = "Protection is active"; Fix = "" })
    }
} catch {
    $results.Add([PSCustomObject]@{ Component = "Windows Defender"; Status = "WARN"; Details = "Status unavailable"; Fix = "Verify Defender service is running." })
}

$services = @(Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'") | Where-Object {
    $_.Name -notmatch "^(gupdate|gupdatem|edgeupdate|edgeupdatem|AdobeARMservice|MozillaMaintenance|AppXSvc|AsusMultiAntennaSvc|brave|Intel.*TPM.*|Netlogon|sppsvc|StiSvc)$"
}

if ($services.Count -gt 0) {
    foreach ($svc in $services) {
        $fix = "Restart service manually or reboot PC."
        if ($svc.Name -eq "wuauserv") { $fix = "Restart Windows Update or reboot." }
        if ($svc.Name -eq "Spooler") { $fix = "Restart Print Spooler / clear print jobs." }
        $results.Add([PSCustomObject]@{ Component = "Service ($($svc.Name))"; Status = "FAIL"; Details = "Automatic service stopped"; Fix = $fix })
    }
} else {
    $results.Add([PSCustomObject]@{ Component = "System Services"; Status = "OK"; Details = "All critical automatic services running"; Fix = "" })
}

try {
    $rawEvents = @(Get-WinEvent -FilterHashtable @{ LogName = "System"; Level = 2; StartTime = (Get-Date).AddDays(-2) } -ErrorAction SilentlyContinue)
} catch { $rawEvents = @() }

if ($rawEvents.Count -gt 0) {
    $groupedEvents = $rawEvents | Group-Object Id | Select-Object -First 5
    foreach ($group in $groupedEvents) {
        $event = $group.Group[0]
        $eventCount = $group.Count
        
        switch ($event.Id) {
            41    { $fix = "Unexpected kernel shutdown. Check CPU temps, RAM stability, or power supply (PSU)." }
            6008  { $fix = "The previous system shutdown was unexpected. Check for sudden power loss or overheating." }
            7     { $fix = "Bad block detected on disk. Run chkdsk /f /r immediately and check drive lifetime." }
            11    { $fix = "Disk controller error. Check NVMe/SATA cables, interface drivers, or drive firmware." }
            19    { $fix = "WHEA-Logger: Processor hardware error. Check CPU voltage, temperatures, or unstable overclocking." }
            55    { $fix = "NTFS file system corruption detected. Run chkdsk /f and check drive health." }
            1000  { $fix = "Application crashed. Check Event Viewer Application log, update or reinstall the software." }
            1001  { $fix = "Blue Screen (BSOD) detected. Inspect memory minidumps and recent hardware/drivers changes." }
            1002  { $fix = "Application hung (frozen). Check system resource usage, memory leaks, or software compatibility." }
            1500  { $fix = "Group Policy processing failed. Check Domain Controller connectivity and run gpupdate /force." }
            5010  { $fix = "Intel Wi-Fi driver timeout/hang. Update Intel PROSet/Wireless driver and disable WLAN Power Saving." }
            5719  { $fix = "Netlogon error. Domain Controller is unreachable. Check network adapter, DNS, or VPN connection." }
            7031  { $fix = "A critical service crashed unexpectedly. Check application dependencies or recent Windows updates." }
            7034  { $fix = "A critical service terminated unexpectedly. Restart it manually or inspect custom app configurations." }
            10317 { $fix = "Wi-Fi Direct miniport power error. Uncheck 'Allow computer to turn off this device' in Device Manager." }
            default { $fix = "Search Event ID $($event.Id) online or inspect related system drivers and software." }
        }
        
        $msg = $event.Message
        if (-not $msg) { $msg = "Critical crash log registered" }
        elseif ($msg.Length -gt 45) { $msg = $msg.Substring(0,45) + "..." }
        
        $displayDetails = $msg
        if ($eventCount -gt 1) { $displayDetails = "[x$eventCount] $msg" }
        
        $results.Add([PSCustomObject]@{ Component = "Crash Log (ID $($event.Id))"; Status = "FAIL"; Details = $displayDetails; Fix = $fix })
    }
} else {
    $results.Add([PSCustomObject]@{ Component = "System Stability"; Status = "OK"; Details = "No critical crashes in last 48h"; Fix = "" })
}

$hasActiveAdapter = $false
Get-NetAdapter | ForEach-Object {
    if ($_.Status -ne "Up") {
        $results.Add([PSCustomObject]@{ Component = "Network ($($_.Name))"; Status = "WARN"; Details = "Adapter is disconnected"; Fix = "Check cable or restart adapter." })
    } else {
        $hasActiveAdapter = $true
        $ipAddress = (Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
        $details = "Connected ($($_.LinkSpeed))"
        if ($ipAddress) { $details += " | IP: $ipAddress" }
        
        if ($_.PhysicalMediaType -eq "802.3" -and $_.LinkSpeed -eq "100 Mbps") {
            $results.Add([PSCustomObject]@{ Component = "Network ($($_.Name))"; Status = "WARN"; Details = "Limited to 100 Mbps (Potential cable/port issue)"; Fix = "Replace LAN cable (Cat5e/6 required) or check switch port." })
        } else {
            $results.Add([PSCustomObject]@{ Component = "Network ($($_.Name))"; Status = "OK"; Details = $details; Fix = "" })
        }
    }
}

if ($hasActiveAdapter) {
    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue
    if ($ping) {
        $dnsTest = [System.Net.Dns]::GetHostAddresses("google.com") 2>$null
        if ($dnsTest) {
            $results.Add([PSCustomObject]@{ Component = "Internet Access"; Status = "OK"; Details = "Online (Ping: $($ping.ResponseTime)ms, DNS: OK)"; Fix = "" })
        } else {
            $results.Add([PSCustomObject]@{ Component = "Internet Access"; Status = "FAIL"; Details = "No Internet (Ping OK, DNS Resolution Failed)"; Fix = "Check DNS settings on the adapter or router." })
        }
    } else {
        $results.Add([PSCustomObject]@{ Component = "Internet Access"; Status = "FAIL"; Details = "No Internet (Ping to 8.8.8.8 failed)"; Fix = "Check router, gateway configuration, or ISP status." })
    }
} else {
    $results.Add([PSCustomObject]@{ Component = "Internet Access"; Status = "FAIL"; Details = "No active network adapters"; Fix = "Connect a LAN cable or enable Wi-Fi." })
}

if ($RunIntegrityChecks) {
    $dism = DISM /Online /Cleanup-Image /ScanHealth
    $sfc = sfc /scannow
    if ($LASTEXITCODE -ne 0) {
        $results.Add([PSCustomObject]@{ Component = "Integrity Checks"; Status = "FAIL"; Details = "Corrupted system files detected"; Fix = "Run repair tools." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "Integrity Checks"; Status = "OK"; Details = "System files are intact"; Fix = "" })
    }
}

Clear-Host
Write-Host "┌────────────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│                                PC DIAGNOSTICS DASHBOARD                                │" -ForegroundColor Cyan
Write-Host "└────────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host "  Host:  $($env:COMPUTERNAME.PadRight(15))  Type:   $($chassisType.PadRight(13))  RAM Total: $([math]::Round($cs.TotalPhysicalMemory / 1GB,2)) GB"
Write-Host "  Model: $($hardwareModel.PadRight(14))  Uptime: $($uptimeString.PadRight(11))  Live Load: CPU: $cpuLoad% | RAM: $ramUsedPercent%"
Write-Host "  OS:    $($os.Caption)"
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

Read-Host "Diagnostics complete in $elapsedSeconds seconds. Press ENTER to close the window"
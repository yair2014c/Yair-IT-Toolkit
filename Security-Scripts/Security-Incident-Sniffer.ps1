param(
    [int]$HoursFilter = 48
)

$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Restarting script with administrator rights..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Clear-Host
$Line = "────────────────────────────────────────────────────────────────────────────────────────"
Write-Host "`n┌$Line┐" -ForegroundColor Cyan
Write-Host "│                               CYBER INCIDENT & FORENSICS SNIFFER                       │" -ForegroundColor Cyan
Write-Host "└$Line┘" -ForegroundColor Cyan
Write-Host "  Host:      $($env:COMPUTERNAME.PadRight(15))  Timeframe: Last $HoursFilter Hours"
Write-Host "  Privileges: SYSTEM_ADMINISTRATOR       Scope:     Security & Hardware Auditing"
Write-Host " $Line" -ForegroundColor Cyan

$TimeFilter = (Get-Date).AddHours(-$HoursFilter)

Write-Host "`n[*] Analyzing Failed Logon Attempts (Brute-Force Detection)..." -ForegroundColor Yellow

try {
    $FailedLogons = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=$TimeFilter} -ErrorAction SilentlyContinue
    if ($FailedLogons) {
        Write-Host "  [✘] ALERT: Found $($FailedLogons.Count) failed logon attempts!" -ForegroundColor Red
        $IncidentReport = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($Event in $FailedLogons) {
            [xml]$xml = $Event.ToXml()
            $TargetUser = ($xml.Event.EventData.Data | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
            $IpAddress  = ($xml.Event.EventData.Data | Where-Object {$_.Name -eq "IpAddress"}).'#text'
            $IncidentReport.Add([PSCustomObject]@{
                Time     = $Event.TimeCreated
                User     = if ($TargetUser) { $TargetUser } else { "Unknown" }
                SourceIP = if ($IpAddress -and $IpAddress -ne "-") { $IpAddress } else { "Local/Physical" }
            })
        }
        $IncidentReport | Format-Table -AutoSize
    } else {
        Write-Host "  [✔] No failed logon attempts detected." -ForegroundColor Green
    }
} catch {
    Write-Host "  [-] Failed to query Security log for logons: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n[*] Checking for Malicious Log Clearing Events..." -ForegroundColor Yellow

try {
    $ClearEvents = Get-WinEvent -FilterHashtable @{LogName=@('Security', 'System'); Id=@(1102, 104); StartTime=$TimeFilter} -ErrorAction SilentlyContinue
    if ($ClearEvents) {
        foreach ($Event in $ClearEvents) {
            Write-Host "  [✘] CRITICAL: Audit log '$($Event.LogName)' was explicitly cleared!" -ForegroundColor Red
            Write-Host "      Timestamp: $($Event.TimeCreated)" -ForegroundColor White
            Write-Host "      User/Provider: $($Event.ProviderName)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [✔] No log clearing activities detected." -ForegroundColor Green
    }
} catch {
    Write-Host "  [-] Failed to query log clearance events: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n[*] Scanning for Removable USB Storage Insertions..." -ForegroundColor Yellow

try {
    $UsbEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-PnP'; Id=411; StartTime=$TimeFilter} -ErrorAction SilentlyContinue
    if ($UsbEvents) {
        Write-Host "  [⚠] WARNING: Found $($UsbEvents.Count) hardware device insertion events." -ForegroundColor Yellow
        foreach ($Event in $UsbEvents) {
            $DeviceLines = $Event.Message -split "`r`n"
            $DeviceDetails = ($DeviceLines | Where-Object { $_ -match "Device" }) -join ", "
            if (-not $DeviceDetails) { $DeviceDetails = $Event.Message.Trim() }
            Write-Host "      Time:   $($Event.TimeCreated)" -ForegroundColor White
            Write-Host "      Device: $($DeviceDetails)" -ForegroundColor Gray
            Write-Host "      --------------------------------------------------------" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [✔] No external USB storage insertion events detected." -ForegroundColor Green
    }
} catch {
    Write-Host "  [-] Failed to query PnP hardware events: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n$Line" -ForegroundColor Cyan
Read-Host "Forensic scan complete. Press Enter to return to main menu"
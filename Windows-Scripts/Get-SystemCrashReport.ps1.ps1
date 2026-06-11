if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -ArgumentList $Arguments -Verb RunAs
    exit
}

Clear-Host
$Line = "=========================================================="
Write-Host "`n$Line" -ForegroundColor Cyan
Write-Host "         ADVANCED SYSTEM & HARDWARE CRASH SNIFFER" -ForegroundColor Cyan
Write-Host "$Line`n" -ForegroundColor Cyan

Write-Host "[*] Analyzing Critical Errors & Hardware Failures (Last 48 Hours)..." -ForegroundColor Yellow
$TimeFilter = (Get-Date).AddDays(-2)

$SystemSources = @(
    "Microsoft-Windows-Kernel-Power", 
    "BugCheck",                       
    "Microsoft-Windows-WER-SystemErrorReporting", 
    "Disk",                           
    "Ntfs",                           
    "Application Popup"               
)

$AppSources = @(
    "Application Error",              
    "Application Hang"                
)

Write-Host "`n>>> SCANNING HARDWARE & SYSTEM CRASHES <<<" -ForegroundColor Cyan
try {
    $SysEvents = Get-WinEvent -FilterHashtable @{
        LogName='System'; 
        Level=@(1,2); 
        StartTime=$TimeFilter
    } -ErrorAction SilentlyContinue | Where-Object { $SystemSources -contains $_.ProviderName }

    if ($SysEvents) {
        foreach ($Event in $SysEvents) {
            Write-Host "[!] HARDWARE/SYS EVENT | Source: $($Event.ProviderName) | ID: $($Event.Id)" -ForegroundColor Red
            Write-Host "    Time: $($Event.TimeCreated)" -ForegroundColor White
            Write-Host "    Description: $($Event.Message.Trim())" -ForegroundColor Gray
            Write-Host "-"*40 -ForegroundColor Gray
        }
    } else {
        Write-Host "[+] No critical hardware or system crashes detected." -ForegroundColor Green
    }
} catch {
    Write-Host "[-] Failed to scan System logs: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n>>> SCANNING APPLICATION CRASHES & HANGS <<<" -ForegroundColor Cyan
try {
    $AppEvents = Get-WinEvent -FilterHashtable @{
        LogName='Application'; 
        Level=@(1,2); 
        StartTime=$TimeFilter
    } -ErrorAction SilentlyContinue | Where-Object { $AppSources -contains $_.ProviderName }

    if ($AppEvents) {
        foreach ($Event in $AppEvents) {
            $Type = if ($Event.ProviderName -eq "Application Hang") { "APPLICATION FREEZE (HANG)" } else { "APPLICATION CRASH" }
            Write-Host "[!] $Type | ID: $($Event.Id)" -ForegroundColor Yellow
            Write-Host "    Time: $($Event.TimeCreated)" -ForegroundColor White
            Write-Host "    Description: $($Event.Message.Trim())" -ForegroundColor Gray
            Write-Host "-"*40 -ForegroundColor Gray
        }
    } else {
        Write-Host "[+] No major application crashes or freezes detected." -ForegroundColor Green
    }
} catch {
    Write-Host "[-] Failed to scan Application logs: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n$Line" -ForegroundColor Cyan
Write-Host " ANALYSIS COMPLETE." -ForegroundColor Green
pause
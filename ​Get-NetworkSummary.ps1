Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       NETWORK DIAGNOSTIC REPORT" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Local Network Configuration
Write-Host "`n[STEP 1] Local Network Configuration:" -ForegroundColor White
$network = Get-NetIPConfiguration | Where-Object { $_.IPv4Address -ne $null }

$network | Select-Object `
    @{Name="Adapter"; Expression={$_.InterfaceAlias}}, 
    @{Name="Internal_IP"; Expression={$_.IPv4Address.IPAddress}}, 
    @{Name="Default_Gateway"; Expression={$_.IPv4DefaultGateway.NextHop}} | Format-Table -AutoSize

# 2. External Internet Discovery
Write-Host "[STEP 2] External Internet Discovery:" -ForegroundColor White
try {
    $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction Stop
    Write-Host "Status: Online" -ForegroundColor Green
    Write-Host "Public IP Address: $publicIP" -ForegroundColor Yellow
} catch {
    Write-Host "Status: Offline / No Internet Access" -ForegroundColor Red
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Press any key to close..."
pause > $null

# 1. Network Profile Information
Write-Host "[STEP 1] Network Connection Profile:" -ForegroundColor yellow
Get-NetConnectionProfile | Select-Object Name, InterfaceAlias, NetworkCategory, IPv4Connectivity | Format-Table -AutoSize | Out-Host
# 2. Live Traffic Statistics
Write-Host "`n[STEP 2] Live Traffic Statistics (MB):" -ForegroundColor Blue
Get-NetAdapterStatistics | Where-Object { $_.ReceivedBytes -gt 0 } | Select-Object `
    InterfaceAlias, 
    @{Name="Received_MB"; Expression={[Math]::Round($_.ReceivedBytes / 1MB, 2)}}, 
    @{Name="Sent_MB";     Expression={[Math]::Round($_.SentBytes / 1MB, 2)}} | Format-Table -AutoSize | Out-Host
Write-Host "`n==========================================" -ForegroundColor Cyan
pause > $null
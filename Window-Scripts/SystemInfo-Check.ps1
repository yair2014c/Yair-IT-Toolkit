Write-Host "Checking System Information..." -ForegroundColor Cyan
Get-ComputerInfo | Select-Object OsName, OsVersion, CsModel | Out-Host
Write-Host "`n==========================================" -ForegroundColor Cyan
pause > $null
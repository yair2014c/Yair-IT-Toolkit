Write-Host "Checking System Information..." -ForegroundColor Cyan
Get-ComputerInfo | Select-Object OsName, OsVersion, CsModel
pause
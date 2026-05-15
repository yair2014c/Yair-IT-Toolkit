$TempFolders = @("$env:TEMP\*", "C:\Windows\Temp\*")

Write-Host "--- Starting Deep Clean ---" -ForegroundColor Cyan

foreach ($Folder in $TempFolders) {
  Write-Host "Cleaning: $Folder" -ForegroundColor Yellow
    Remove-Item -Path $Folder -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "`nClean-up complete! (Used files were skipped)" -ForegroundColor Green
pause
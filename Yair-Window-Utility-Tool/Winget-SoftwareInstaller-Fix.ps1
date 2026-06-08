# Fail-safe Administrator check (if the script is ever run independently of the .bat)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requesting administrative privileges..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "Applying Winget fixes for Fresh VM..." -ForegroundColor Cyan

# 1. Force TLS 1.2/1.3 for secure downloads on fresh OS builds
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# 2. Install NuGet Provider & WinGet PowerShell Module globally
Write-Host "Configuring package providers..." -ForegroundColor Cyan
Install-PackageProvider -Name NuGet -Force | Out-Null
Install-Module -Name Microsoft.WinGet.Client -Force -AllowClobber -Repository PSGallery -Scope AllUsers | Out-Null

# 3. Handle Framework Dependencies (Resolves 0x80073CF3 on fresh Windows 10 builds)
$tempDir = "$env:TEMP\WingetFix"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

Write-Host "Downloading Windows App Runtime 1.8 Framework..." -ForegroundColor Yellow
$runtimeUrl = "https://aka.ms/windowsappsdk/1.8/stable/Microsoft.WindowsAppRuntime.1.8.msix"
$runtimePath = "$tempDir\Microsoft.WindowsAppRuntime.1.8.msix"
Invoke-WebRequest -Uri $runtimeUrl -OutFile $runtimePath -UseBasicParsing

Write-Host "Installing Windows App Runtime..." -ForegroundColor Yellow
Add-AppxPackage -Path $runtimePath -ErrorAction SilentlyContinue

# 4. Run the repair sequence now that dependencies exist
Write-Host "Executing WinGet Package Manager Repair..." -ForegroundColor Yellow
Repair-WinGetPackageManager -Force -Latest

# 5. Post-execution cleanup
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nFix complete! Verification:" -ForegroundColor Green
winget --version

Write-Host "`nPress any key to exit." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
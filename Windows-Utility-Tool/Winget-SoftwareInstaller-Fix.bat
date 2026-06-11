@echo off
setlocal EnableExtensions DisableDelayedExpansion

:: Check for Administrator privileges before launching PowerShell to prevent window flashing
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :RunPowerShell
) else (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:RunPowerShell
cd /d "%~dp0"
:: Launch the PowerShell script with strict execution policy bypass
powershell -NoProfile -ExecutionPolicy Bypass -File "Winget-SoftwareInstaller-Fix.ps1"
exit /b
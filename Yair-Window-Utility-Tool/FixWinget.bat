@echo off
:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :RunCommands
) else (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
    exit /b
)

:RunCommands
echo Applying Winget fixes...
echo.

WINGET SETTINGS --ENABLE BypassCertificatePinningForMicrosoftStore
WINGET UPGRADE Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements
WINGET SETTINGS --DISABLE BypassCertificatePinningForMicrosoftStore
WINGET UPGRADE --all --include-unknown --accept-source-agreements --accept-package-agreements

echo.
echo Fix complete! Press any key to exit.
pause >nul
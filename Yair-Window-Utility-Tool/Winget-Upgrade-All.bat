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
echo Initiating Global Software Upgrade...
echo.

WINGET UPGRADE --all --include-unknown --accept-source-agreements --accept-package-agreements

echo.
echo All software upgraded.
timeout /t 5 >nul
exit
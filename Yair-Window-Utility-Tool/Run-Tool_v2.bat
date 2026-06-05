@echo off
REM ============================================================================
REM Yair Windows Utility v2 - Enhanced Edition
REM Batch Runner (Execution Policy Bypass)
REM ============================================================================

setlocal enabledelayedexpansion

REM Get script directory
cd /d "%~dp0"

REM Check admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] This script requires Administrator privileges!
    echo.
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

REM Display banner
cls
echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║     YAIR WINDOWS UTILITY v2 - Enhanced Edition            ║
echo ║         Batch Runner - Policy Bypass Active              ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

REM Verify script exists
if not exist "YairUtility_v2_Enhanced.ps1" (
    echo [ERROR] YairUtility_v2_Enhanced.ps1 not found in current directory!
    echo.
    echo Expected location: "%cd%\YairUtility_v2_Enhanced.ps1"
    echo.
    pause
    exit /b 1
)

echo [OK] Administrator privileges confirmed
echo [OK] Script file found: YairUtility_v2_Enhanced.ps1
echo.
echo Launching PowerShell execution environment...
echo.

REM Execute with full bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "YairUtility_v2_Enhanced.ps1"

REM Capture exit code
set exitCode=%errorlevel%

if %exitCode% neq 0 (
    echo.
    echo [WARNING] Script exited with code: %exitCode%
    echo.
    pause
)

exit /b %exitCode%

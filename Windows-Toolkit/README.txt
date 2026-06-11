Yair Utility Tool Overview

YairUtility.ps1 — The Main Tool.
This is the heart of my project. An easy to use and access, a console-based Windows management utility that runs as Administrator and covers 9 operational modules through a numbered 
menu


Package Management.

[1] Install / [2] Uninstall Apps.

Opens, an Out-GridView GUI window populated from a curated catalog of ~60 apps across categories: Browsers, Security, Office, System Tools, Networks, Dev, AI, Communication, Gaming, and more. You pick what you want (CTRL for multi-select), and it spawns a separate PowerShell window that executes all winget installs/uninstalls in one batch. The payload is written to a temp file, executed, then deleted — keeping everything clean.


Debloat [3]

Sub-menu with 3 options: remove pre-installed bloatware (TikTok, Cortana, Xbox tools, etc.), disable Windows telemetry services (DiagTrack, dmwappushservice), and clear temp files + Recycle Bin.


Windows Update [4]

Opens the native Windows Update settings panel directly.



Diagnostics [5–8]

Health Check — CPU load, RAM, disk space, drive SMART health, stopped auto-services.
Security Audit — Checks Defender real-time protection, firewall status, BitLocker, and UAC level.
Identity Audit — Reviews local SAM accounts: admin count, stale accounts (90+ days inactive), passwords that never expire.
Incident Sniffer — Scans the last 48 hours of Security event logs for failed logon attempts (Event 4625) and any audit log clearing (Events 1102/104).


Maintenance [9]

Creates a System Restore Point, then searches for and installs critical/security Windows Updates using the COM-based Windows Update API.

Simulation Mode [S]

A dry-run toggle — every destructive or system-modifying action is skipped and marked SIMULATED. Safe for testing on production machines.


Winget Guard.

Before any install/uninstall operation, it runs a 3-step validation: checks if winget exists → tries to install it if missing (AppX path refresh or GitHub download) → updates it. If winget is broken, the software menu never opens, and the user gets a clear fix instruction.


Run-Tool.bat — The Launcher.
A minimal one-liner that launches YairUtility.ps1 from its own folder with ExecutionPolicy Bypass. This is what the end user double-clicks — no PowerShell knowledge needed.


Winget-SoftwareInstaller-Fix.ps1 + Winget-SoftwareInstaller-Fix.bat — The Deep Winget Repair.

For machines where winget is broken beyond what YairUtility built-in guard can fix, (typically fresh Windows 10 VMs or clean enterprise images).
Installs the NuGet package provider and the Microsoft.WinGet.Client PowerShell module,
Downloads and installs the Windows App Runtime 1.8 framework , its important so window can render packages and more (fixes the common 0x80073CF3 error).
Runs Repair-WinGetPackageManager -Force -Latest
Cleans up temp files and confirms the fix with winget --version.

.bat,  handles the UAC elevation request before handing off to the script.ps1 .

Certificate_Winget_Fix.bat — The Certificate Bypass Fix.
A targeted 3-command fix for environments where winget fails due to certificate pinning, (common in corporate networks or locked-down machines). It temporarily enables BypassCertificatePinningForMicrosoftStore, upgrades the App Installer package, then disables the bypass again. Fast and surgical.

Winget-Upgrade-All.bat — Bulk Updater.
A standalone utility that runs winget upgrade --all with --include-unknown and auto-accepts all agreements. Elevates to admin automatically, upgrades everything winget knows about, then closes after 5 seconds.

 Known Limitations.
 three important edge cases:

Tor Browser — Can't be uninstalled via winget, requires manual folder deletion.
Apple Music — Windows 11 only, won't install on Windows 10.
Docker Desktop — Only works on Windows Pro or Enterprise editions, won't install on Home.





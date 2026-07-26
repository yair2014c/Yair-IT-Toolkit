# Usage & Detailed Quick Start

This file contains the expanded quick-start instructions and examples. If you're new, follow the Quick Start on the main README and use Simulation Mode first.

Running the toolkit
1. Clone the repo:

```powershell
git clone https://github.com/yair2014c/Yair-IT-Toolkit.git
cd Yair-IT-Toolkit
```

2. Launch (recommended): double-click `Start-Toolkit-launcher.bat` — it runs the menu engine with ExecutionPolicy bypass.

3. From the main menu:
- [1] Network Scripts — run network diagnostics and connection triage
- [2] Security Scripts — run security audits and incident sniffer
- [3] Windows Scripts — quick utilities (Clean-Temp, Diagnostics)
- [4] Windows Utility Tool — main dashboard (install/uninstall apps, debloat, health checks, secure updates)

Simulation Mode
- Toggle simulation mode from the Windows Utility Tool main dashboard with `[S]`. When enabled, destructive operations are only simulated and no actual changes are made.

WinGet recovery
- If winget is missing or broken the toolkit runs `Assert-Winget` which attempts repair. If automated repair fails, see `Windows-Utility-Tool/Winget-SoftwareInstaller-Fix.ps1` and `Winget-SoftwareInstaller-Fix.bat`.

Restore points
- The Secure Updates and major debloat operations create a system restore point before making changes.

Safety checklist before running on a new machine
- Backup important data
- Ensure a stable network connection if performing installs
- Run in Simulation Mode if unsure


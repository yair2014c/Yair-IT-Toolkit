# Yair IT Toolkit

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A compact, menu-driven PowerShell toolkit for Windows system administration: package management (WinGet), diagnostics, security auditing, storage sanitization, and maintenance — intended for IT professionals.

Why this repo exists
- Fast, single-launch console UI for common Windows admin tasks.
- Focus on safe defaults (Simulation Mode) and automated WinGet repair helpers for problematic environments.

Quick start (the shortest path)
1. Download or clone the repository.
2. Double-click `Start-Toolkit-launcher.bat` (recommended). This runs the menu engine with a safe ExecutionPolicy bypass.
3. Use `[4]` → `Windows Utility Tool` for the main dashboard, or choose other categories for single-purpose scripts.

Important safety notes
- Administrator privileges are required for many operations. UAC prompts are normal.
- Use Simulation Mode (`[S]`) to dry-run destructive actions before actually applying them.
- The toolkit will create a restore point before major changes, but you should back up important data first.

Where to find detailed docs and the full catalog
- Detailed usage, full app catalog, and troubleshooting moved to docs/:
  - docs/USAGE.md — expanded usage & examples
  - docs/CATALOG.md — curated app catalog and installation notes

Files of interest
- `Start-Toolkit-launcher.bat` — Safe launcher (recommended)  
- `Menu-Engine.ps1` — Console menu driver  
- `Windows-Utility-Tool/YairUtility.ps1` — Main dashboard & software catalog  
- `Windows-Scripts/` — Standalone maintenance and diagnostics scripts

License
- MIT (see LICENSE)

If you want the previous full README text preserved, see: `docs/OLD_README.md` (a verbatim copy of the original README).

# Old README (verbatim)

This file is a preserved copy of the original README content. It contains the full long-form documentation, screenshots, and troubleshooting that were moved out of the trimmed repository for better UX.


# Yair IT Toolkit

A comprehensive Windows system administration tool that combines software management, security auditing, system diagnostics, and maintenance all in one easy-to-use utility. Built for IT professionals.

<img width="687" height="338" alt="image" src="https://github.com/user-attachments/assets/20077072-3053-4280-ad88-a79c7228f93f" />
<img width="807" height="486" alt="צילום מסך 2026-07-26 185939" src="https://github.com/user-attachments/assets/422e35e1-291e-4a0e-a1a5-784fb104342a" />

---

## 📑 Quick Navigation
- [What You Get](#-what-you-get)
- [Quick Start](#-quick-start)
- [System Requirements](#-system-requirements)
- [Main Menu](#--main-menu-structure)
- [How to Use](#-how-to-use-step-by-step-examples)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 What You Get

**Yair IT Toolkit** simplifies complex Windows management tasks through an intuitive menu-driven interface. No command line expertise needed.

### Core Capabilities

**📦 Software Management**
- Browse, install, and uninstall 60+ professional applications (across Browsers, Security, Development, Gaming, Productivity, and more)
- Multi-select apps using a visual grid interface
- Automated batch installation/removal with a single click
- Built-in WinGet recovery if installation tools fail

**🧹 System Cleanup & Optimization**
- Remove bloatware and pre-installed junk (TikTok, Cortana, Xbox apps, etc.)
- Deep storage sanitization: clears temp files, cache, update cache, and recycle bin in one operation
- Disable Windows telemetry and diagnostic tracking
- Reclaim gigabytes of disk space

**🔒 Security & Forensics**
- Real-time security audit: check Defender, Firewall, BitLocker, and UAC settings
- Cyber incident detection: scan for failed login attempts and suspicious activity (last 48 hours)
- Local account audit: identify weak passwords, stale accounts, and admin privilege risks
- One-click security compliance check

**🏥 System Diagnostics**
- Hardware health dashboard: CPU, RAM, disk space, drive SMART status
- Network diagnostics: active connections, IP configuration, internet connectivity
- Service health check: identify stopped critical services
- Battery wear tracking (for laptops)

**🛡️ Updates & Backup**
- Automatic system restore point creation
- Safe Windows Update scanning and installation
- Security-focused update prioritization

**🔧 Advanced Utilities**
- Network troubleshooting and connection mapping
- System crash log analysis
- Administrative identity and privilege auditing

---

## 🚀 Quick Start

### Installation

1. **Download the tool**
   ```
   Clone or download this repository to any folder on your PC
   ```

2. **Run it**
   - Simply **double-click** `Start-Toolkit-launcher.bat`
   - The menu will launch automatically
   - Admin prompts will appear when you run commands that need elevation

That's it. The tool will:
- Launch the main menu with all available categories
- Request Administrator privileges when needed
- Guide you through the rest

**Note**: Administrator access is required for all features. You'll see UAC prompts when running operations—this is normal and expected.

---

## 🎯 Which Tool Should I Use?

| Problem | Solution |
|---------|----------|
| **PC is running slow** | Menu `[4]` → `[5]` (Health Check) |
| **Suspicious activity/malware suspected** | Menu `[4]` → `[8]` (Incident Scan) |
| **Need to free up disk space** | Menu `[4]` → `[3]` (Debloat & Cleanup) |
| **Network problems** | Menu `[1]` (Network Scripts) |
| **Want to test before making changes** | Menu `[4]` → `[S]` (Simulation Mode) |

---

## ⚠️ Important: Use the Launcher

**Always use `Start-Toolkit-launcher.bat` to run the toolkit.** This batch file handles all PowerShell execution policies automatically.

If you try to run `.ps1` files directly without the launcher, you'll need to manually configure your computer's execution policy to "Unrestricted," which is **not recommended for security reasons**.

**The `.bat` launcher is the safe and easy way to use this toolkit.**

---

## 📋 System Requirements

| Requirement | Details |
|-------------|---------|
| **Operating System** | Windows 10 (Build 19041+) or Windows 11 |
| **PowerShell** | 5.1 or later (included with Windows) |
| **Administrator Rights** | Required (will be requested automatically when needed) |
| **Disk Space** | ~50 MB (for the toolkit + app cache) |
| **Internet Connection** | Required for app installation/updates |

---

## 🗂️ Main Menu Structure

Once launched, you'll see the **Menu-Engine** which organizes all tools by category:

```
==========================================
       YAIR AUTOMATION MENU              
==========================================
[1] Network Scripts
[2] Security Scripts
[3] Windows Scripts
[4] Windows Utility Tool
[Q] Exit Console
==========================================
```

### **Category 1: Network Scripts**
- Full network diagnostics
- Active connection mapping
- Network profile checker
- Summary of IP config
- Connection troubleshooting

### **Category 2: Security Scripts**
- Security baseline audit
- Identity & privilege auditing
- Cyber incident detection

### **Category 3: Windows Scripts**
- Clean temp files
- System diagnostics
- Storage deep cleaning
- Secure updates
- System info check

### **Category 4: Windows Utility Tool** (Main Application)
The comprehensive tool with:
- Install/Uninstall apps from 60+ catalog
- System debloat & cleanup
- Health diagnostics
- Security audits
- Update management

---

## 📊 Main Dashboard (Windows Utility Tool)

When you select `[4] Windows Utility Tool`, you get the full dashboard:

```
=================================================================
       YAIR WINDOWS UTILITY TOOL - MAIN CONSOLE             
=================================================================
                                                              
  PACKAGE MANAGEMENT & AUTOMATION                            
   [1] Install Apps (Select from Catalog)                    
   [2] Uninstall Apps (Remove from System)                   
   [3] Windows Safe Deep Clean & Debloat                     
   [4] Trigger Native Windows Update Panel                   
                                                              
  DIAGNOSTICS, FORENSICS & INFRASTRUCTURE                    
   [5] System Health Check (Hardware & Services)             
   [6] Security Audit (Antivirus & Firewall Check)           
   [7] User Account Audit (Admin & Guest Risk Check)         
   [8] Security Incident Scan (Failed Logins - Last 48h)     
                                                              
  MAINTENANCE                                                
   [9] Secure Update & Backup (Create Restore Point)         
                                                              
  SYSTEM                                                     
   [S] Toggle Simulation Mode (Test without changes)         
   [Q] Exit                                                  
                                                              
=================================================================
```

### Feature Breakdown

| Menu | What It Does | Time | Safety |
|------|-------------|------|--------|
| **[1] Install Apps** | Opens a searchable grid of 60+ apps. Multi-select and batch install. | 2-10 min | ✅ Safe |
| **[2] Uninstall Apps** | Select apps to remove completely. | 1-5 min | ✅ Safe |
| **[3] Debloat** | Remove bloatware, disable telemetry, clear temp files | 5-15 min | ⚠️ Destructive |
| **[4] Windows Update** | Opens native Windows Update settings | — | ✅ Safe |
| **[5] Health Check** | Dashboard of CPU, RAM, disk, drive health, services | 1-2 min | ✅ Safe |
| **[6] Security Audit** | Check Defender, Firewall, BitLocker, UAC status | 1 min | ✅ Safe |
| **[7] Account Audit** | Review admin accounts, stale users, password policies | 1 min | ✅ Safe |
| **[8] Incident Scan** | Find failed login attempts, audit log tampering | 1-2 min | ✅ Safe |
| **[9] Secure Updates** | Create restore point + install critical updates | 5-20 min | ⚠️ Requires Reboot |

---

## 🎮 How to Use (Step-by-Step Examples)

### Example 1: Install Development Tools
1. Double-click launcher → Press `[4]` for Windows Utility Tool
2. Press `[1]` for Install Apps
3. A grid window opens showing all available apps
4. Hold **CTRL** and click to select: VS Code, Python, Node.js, Git
5. Click **OK**
6. Apps install automatically in a new window
7. When done, press **Enter** to return to menu

### Example 2: Clean Up Your PC
1. Run launcher → Select Category `[4]` → Press `[3]` for Debloat
2. Choose:
   - `[1]` Remove bloatware (TikTok, Cortana, Xbox apps)
   - `[2]` Disable Windows telemetry
   - `[3]` Clear temp files & empty recycle bin
3. Each option runs and shows what was cleaned

### Example 3: Check System Health
1. Run launcher → Select Category `[4]` → Press `[5]` for Health Check
2. See a dashboard showing:
   - CPU/RAM usage
   - Disk space per drive
   - Drive health (SMART status)
   - Stopped services
   - Pending reboot status
3. Yellow/Red flags show problems with suggested fixes

### Example 4: Run Network Diagnostics
1. Run launcher → Select Category `[1]` for Network Scripts
2. Choose from available diagnostics:
   - Full network diagnostic
   - Active connection mapping
   - Network profile check
   - IP configuration summary
   - Troubleshooting tools

### Example 5: Test Without Making Changes (Simulation Mode)
1. Run launcher → Select Category `[4]` → Press `[S]` to toggle Simulation Mode (ON)
2. Now any destructive operation is simulated (no actual changes)
3. Try debloat, cleaning, or uninstall to see what would happen
4. Press `[S]` again to turn off Simulation Mode when confident

---

## 🛠️ Included Scripts & Utilities

Beyond the main tool, you also get standalone scripts for specific tasks:

### Windows Scripts
- **Clean-Temp.ps1** — Remove temp files and caches
- **System-Full-Diagnostic.ps1** — Comprehensive hardware health check
- **Storage-Full-Sanitizer.ps1** — Deep disk cleanup (update cache, temp data, WSL)
- **Secure-Updates.ps1** — Native Windows Update management
- **System-Info-Check.ps1** — Quick OS and hardware info

### Security Scripts
- **Security-Full-Diagnostic.ps1** — Defender, Firewall, BitLocker audit
- **Security-Incident-Sniffer.ps1** — Forensics scan (failed logins, log tampering)
- **Security-Identity-Auditor.ps1** — Local account and privilege review

### Network Scripts
- **Full-Network-Diagnostic.ps1** — Network adapter and connectivity check
- **Get-ActiveConnection.ps1** — Map processes to active connections
- **Get-NetworkProfile.ps1** — Check WiFi/Ethernet settings
- **Get-NetworkSummary.ps1** — Local IPs, gateway, external IP, bandwidth
- **Triage-Connection.ps1** — Diagnose connection failures

### WinGet Recovery Tools
- **Winget-Upgrade-All.bat** — Update all installed apps at once
- **Certificate-Winget-Fix.bat** — Fix certificate blocking issues
- **Winget-Software-Installer-Fix.ps1** — Deep WinGet repair

---

## 📸 Screenshots

<img width="1470" height="978" alt="main menu" src="https://github.com/user-attachments/assets/25ac87ed-5ffd-4ef4-a7fc-d860c959e02f" />
<img width="1448" height="733" alt="winget" src="https://github.com/user-attachments/assets/ad6d8f15-a012-4207-932e-7f4839ea9964" />
<img width="1405" height="506" alt="health" src="https://github.com/user-attachments/assets/96f83e3f-688f-44f7-80b3-29e36029ff25" />
<img width="1312" height="491" alt="deploat" src="https://github.com/user-attachments/assets/b612f70c-cc90-4619-917d-8433dcb5b927" />
<img width="1141" height="267" alt="security" src="https://github.com/user-attachments/assets/48705e8d-18c3-4397-8cc6-0428f8ae3bda" />

---

## ⚠️ Important Notes

### Before You Start
- ✅ **Backup important data** before running debloat or cleanup operations
- ✅ **Use the launcher**: Always double-click `Start-Toolkit-launcher.bat` to run the tool
- ✅ **Internet required** for app installation
- ✅ **Use Simulation Mode first** if you're unsure about a feature

### What Gets Deleted?
These are **permanent** and cannot be undone easily:
- Recycle Bin contents
- Temp folders (`%TEMP%`, `C:\Windows\Temp`)
- Windows Update cache
- Prefetch files
- Pre-installed apps (TikTok, Cortana, etc.)

**Mitigation**: A system restore point is created before major operations.

### WinGet Troubleshooting
If you see "WinGet not found" error:
1. The tool will try to install it automatically
2. If that fails, run: `Windows-Utility-Tool/Winget-Software-Installer-Fix.bat`
3. For certificate issues, run: `Windows-Utility-Tool/Certificate-Winget-Fix.bat`

---

## 🔐 Security & Privacy

- ✅ **No data collection**: Tool runs entirely local, no telemetry to third parties
- ✅ **Open source**: Audit the code yourself
- ✅ **Safe defaults**: Simulation mode available before any destructive operation
- ✅ **Restore points**: Automatic backup created before updates/debloat
- ✅ **Admin-only**: Operations require Administrator approval
- ✅ **Secure execution**: Uses `.bat` launcher to avoid risky PowerShell policy changes

---

## 📂 Folder Structure

```
Yair-IT-Toolkit/
├── Start-Toolkit-launcher.bat             (← Use this to launch)
├── Menu-Engine.ps1                        (Menu system - run via launcher)
├── Windows-Utility-Tool/
│   ├── YairUtility.ps1                    (Main application)
│   ├── Winget-*.bat                       (WinGet repair tools)
│   └── Certificate-*.bat
├── Windows-Scripts/                       (Standalone utilities)
│   ├── Clean-Temp.ps1
│   ├── System-Full-Diagnostic.ps1
│   └── ...
├── Security-Scripts/
│   ├── Security-Incident-Sniffer.ps1
│   └── ...
├── Network-Scripts/
│   ├── Full-Network-Diagnostic.ps1
│   └── ...
└── README.md                              (You are here)
```

---

## 🆘 Troubleshooting

### Launcher Won't Start
- **Problem**: Double-click doesn't launch anything
- **Fix**: Right-click `Start-Toolkit-launcher.bat` → **Run as Administrator**

### Tool Won't Start (PowerShell Error)
- **Problem**: "Cannot be loaded because running scripts is disabled"
- **Fix**: Use the `.bat` launcher instead of running `.ps1` files directly
- **Note**: Do NOT change PowerShell execution policy—use the launcher instead

### Apps Won't Install
- **Problem**: "WinGet not found" or certificate errors
- **Fix**: Run `Windows-Utility-Tool/Winget-Software-Installer-Fix.bat`
- **Corporate environments**: Run `Windows-Utility-Tool/Certificate-Winget-Fix.bat`

### Debloat Didn't Remove Apps
- **Problem**: Some apps still appear in Settings
- **Fix**: They may be "provisioned packages" that won't fully uninstall until OS rebuild
- **Workaround**: Manually remove from Settings → Apps → Installed Apps

### System Feels Slower After Cleanup
- **Problem**: Cleanup removed a service that should run
- **Fix**: Restore from the automatic restore point:
  - Settings → System → Recovery → Recovery Options → Previous Version
  - Or use: `rstrui.exe` from Run dialog

### Lost Administrator Access
- **Problem**: Account audit disabled all admin accounts
- **Fix**: Boot into Safe Mode with Command Prompt and restore
- **Prevention**: Always create a restore point first!

---

## 📝 License & Credits

- **Author**: Yair
- **Built with**: PowerShell 5.1+, Windows native APIs, Menu-Engine architecture
- **License**: [Add your license here if applicable]

---

## 🤝 Contributing

Found a bug or have a feature request?
- Open an issue on GitHub
- Describe the problem and steps to reproduce

---

## 🎓 Learn More

- [PowerShell Docs](https://learn.microsoft.com/en-us/powershell/)
- [WinGet Documentation](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [Windows Event Log Reference](https://learn.microsoft.com/en-us/windows/win32/eventlog/event-logging)

---

## Quick Links

| Task | Where to Find |
|------|---------------|
| Install apps | Menu `[4]` → `[1]` |
| Clean bloatware | Menu `[4]` → `[3]` → `[1]` |
| Check security | Menu `[4]` → `[6]` |
| Find malware indicators | Menu `[4]` → `[8]` |
| Test without changes | Menu `[4]` → `[S]` (Simulation Mode) |
| Advanced network diagnostics | Menu `[1]` → Select script |
| Check system health | Menu `[4]` → `[5]` |

---

**Last Updated**: 2026-07-26  
**Version**: 1.1 (Menu-Engine Integration)

---

## 💡 Pro Tips

1. **Test before deploying**: Use Simulation Mode `[S]` first
2. **Always use the launcher**: Double-click `Start-Toolkit-launcher.bat`—don't run scripts directly
3. **Regular maintenance**: Run Health Check `[5]` monthly
4. **Batch operations**: Multi-select apps with CTRL for faster installation
5. **Security first**: Run Security Audit `[6]` after major changes
6. **Backup before debloat**: The tool creates restore points, but always back up manually too
7. **Network issues?**: Start with Network Scripts menu `[1]`
8. **Performance problems?**: Run Menu `[4]` → Health Check `[5]` and Incident Scan `[8]`

---

**Questions or issues?** Check the [Troubleshooting](#-troubleshooting) section above or review the folder-specific READMEs for detailed documentation on individual scripts.

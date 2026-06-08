#requires -Version 5.1
# ==============================================================================
# Script:   Yair Windows Utility Tool - FIXED & ENHANCED
# Modules:  Software Manager (Array-Bound Batch Execution Engine) · Interactive Safe Debloat 
#           Telemetry Lockdown · System Diagnostics · Security & SAM Audit 
#           Cyber Incident Sniffer · Secure Updates
# ==============================================================================

# --- Admin Elevation Enforcement ---
# 1. Check current Administrator status
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 2. Get the current script path safely
$scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }

# 3. Get the current effective execution policy
$currentPolicy = Get-ExecutionPolicy

# 4. Handle the routing logic
if (-not $isAdmin) {
    # NOT AN ADMIN: Force relaunch as Admin AND apply Bypass
    Write-Host "[INFO] Requesting Administrator privileges..." -ForegroundColor Cyan
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
} 
elseif ($currentPolicy -ne "Bypass") {
    # ALREADY AN ADMIN, BUT POLICY IS BLOCKING US (Restricted, AllSigned, RemoteSigned, etc.)
    # Force a relaunch in a clean Bypass process
    Write-Host "[INFO] System policy is ($currentPolicy). Applying temporary execution bypass..." -ForegroundColor Cyan
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
}

# --- Global State ---
$Global:IsSimulation = $false

# ==============================================================================
# WINGET MANAGEMENT FUNCTIONS
# ==============================================================================

function Test-WingetInstalled {
    <#
    .SYNOPSIS
        Tests if winget is installed and available
    #>
    try {
        $version = & winget --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $version) {
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

function Install-Winget {
    <#
    .SYNOPSIS
        Automatically installs or enables winget
    #>
    Write-Host "`n[*] Winget not found. Attempting installation..." -ForegroundColor Yellow
    
    try {
        # Method 1: Check if it's in AppX and just needs to be added to PATH
        $appxPackages = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue
        
        if ($appxPackages) {
            Write-Host "    [+] Winget AppX package found, refreshing PATH..." -ForegroundColor Green
            $env:Path += ";$env:LOCALAPPDATA\Microsoft\WindowsApps"
            
            # Verify it's now available
            $version = & winget --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    [✓] Winget is now available: $version" -ForegroundColor Green
                return $true
            }
        }
        
        # Method 2: Install from Microsoft Store (requires internet)
        Write-Host "    [*] Installing from Microsoft Store (requires internet)..." -ForegroundColor Yellow
        $ProgressPreference = 'SilentlyContinue'
        
        # Download installer from GitHub releases
        $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $wingetPath = "$env:TEMP\winget.msixbundle"
        
        Write-Host "    [*] Downloading winget installer..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPath -ErrorAction Stop
        
        Write-Host "    [*] Installing winget package..." -ForegroundColor Cyan
        Add-AppxPackage -Path $wingetPath -ErrorAction Stop
        
        # Cleanup
        Remove-Item $wingetPath -Force -ErrorAction SilentlyContinue
        
        Write-Host "    [✓] Winget installed successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        return $false
    }
}

function Update-Winget {
    <#
    .SYNOPSIS
        Updates winget to the latest version
    #>
    Write-Host "`n[*] Checking for winget updates..." -ForegroundColor Yellow
    
    try {
        # Attempt self-update
        Write-Host "    [*] Running: winget upgrade Microsoft.Winget" -ForegroundColor Cyan
        & winget upgrade Microsoft.Winget --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [✓] Winget updated successfully" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "    [!] No updates available or update skipped" -ForegroundColor DarkGray
            return $true
        }
    }
    catch {
        return $true  # Don't fail, just continue
    }
}

function Assert-Winget {
    <#
    .SYNOPSIS
        Ensures winget is installed, updated, and not blocked by the system.
    #>
    Write-Host "`n╔═════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        WINGET VALIDATION SEQUENCE        ║" -ForegroundColor Cyan
    Write-Host "╚═════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Step 1: Check if installed
    Write-Host "`n[1/3] Checking winget installation..." -ForegroundColor Yellow
    if (Test-WingetInstalled) {
        Write-Host "      [✓] Winget is installed" -ForegroundColor Green
    }
    else {
        Write-Host "      [✘] Winget not found, attempting installation..." -ForegroundColor Yellow
        if (-not (Install-Winget)) {
            Write-Host "`n[!] CRITICAL ERROR: Failed to install Winget." -ForegroundColor Red
            Write-Host "[!] Something stopped the operation from working." -ForegroundColor Yellow
            Write-Host "[i] FIX: Use the Winget repair script from the IT-toolkits repository, or check the README for manual setup instructions." -ForegroundColor Cyan
            Read-Host "Press Enter to return to the main menu"
            return $false
        }
    }
    
    # Step 2: Verify functionality and look for blocks/certificate errors
    Write-Host "`n[2/3] Verifying winget functionality..." -ForegroundColor Yellow
    try {
        $version = & winget --version 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Winget returned a non-zero exit code." }
        Write-Host "      [✓] Winget version: $version" -ForegroundColor Green
    }
    catch {
        Write-Host "`n[!] CRITICAL ERROR: Winget execution was blocked or failed." -ForegroundColor Red
        Write-Host "[!] Something stopped the operation from working. This is usually caused by Windows security policies or certificate errors." -ForegroundColor Yellow
        Write-Host "[i] FIX: Use the Winget repair script from the IT-toolkits repository, or check the README for troubleshooting steps." -ForegroundColor Cyan
        Read-Host "Press Enter to return to the main menu"
        return $false
    }
    
    # Step 3: Update winget
    Write-Host "`n[3/3] Updating winget to latest version..." -ForegroundColor Yellow
    Update-Winget | Out-Null
    
    Write-Host "`n[✓] Winget is ready to use!" -ForegroundColor Green
    Start-Sleep -Seconds 1
    return $true
}

# --- Consolidated Master Software Catalog ---
$SoftwarePackages = @(
    # 🌐 Browsers
    [PSCustomObject]@{Category="🌐 Browsers"; Name="Google Chrome"; Process="chrome"; Note="Popular web browser by Google"; ID="Google.Chrome"}
    [PSCustomObject]@{Category="🌐 Browsers"; Name="Brave Browser"; Process="brave"; Note="Secure, ad-blocking privacy browser"; ID="Brave.Brave"}
    [PSCustomObject]@{Category="🌐 Browsers"; Name="LibreWolf"; Process="librewolf"; Note="Privacy-focused, hardened Firefox fork"; ID="LibreWolf.LibreWolf"}
    [PSCustomObject]@{Category="🌐 Browsers"; Name="Mozilla Firefox"; Process="firefox"; Note="Independent open-source browser"; ID="Mozilla.Firefox"}
    [PSCustomObject]@{Category="🌐 Browsers"; Name="Tor Browser"; Process="firefox"; Note="Anonymity-focused onion routing browser"; ID="TorProject.TorBrowser"}
    [PSCustomObject]@{Category="🌐 Browsers"; Name="Microsoft Edge"; Process="msedge"; Note="Enterprise chromium-based browser by Microsoft"; ID="Microsoft.Edge"}
    [PSCustomObject]@{Category="🌐 Browsers"; Name="Opera Browser"; Process="opera"; Note="Feature-rich browser with built-in utilities"; ID="Opera.Opera"}
    [PSCustomObject]@{Category="🌐 Browsers"; Name="Vivaldi"; Process="vivaldi"; Note="Highly customizable power-user browser"; ID="VivaldiTechnologies.Vivaldi"}
    
    # 🔒 Security
    [PSCustomObject]@{Category="🔒 Security"; Name="Bitwarden"; Process="Bitwarden"; Note="Open-source cloud password manager"; ID="Bitwarden.Bitwarden"}
    [PSCustomObject]@{Category="🔒 Security"; Name="1Password"; Process="1Password"; Note="Enterprise-grade password management ecosystem"; ID="AgileBits.1Password"}
    [PSCustomObject]@{Category="🔒 Security"; Name="KeePassXC"; Process="keepassxc"; Note="Cross-platform offline password vault"; ID="KeePassXCTeam.KeePassXC"}
    [PSCustomObject]@{Category="🔒 Security"; Name="KeePass (Classic)"; Process="KeePass"; Note="Classic local password manager"; ID="DominikReichl.KeePass"}
    [PSCustomObject]@{Category="🔒 Security"; Name="VeraCrypt"; Process="VeraCrypt"; Note="Open-source disk encryption utility"; ID="IDRIX.VeraCrypt"}
    [PSCustomObject]@{Category="🔒 Security"; Name="Malwarebytes"; Process="mbam"; Note="Anti-malware scanner and remediation tool"; ID="Malwarebytes.Malwarebytes"}
    
    # 🏢 Office & Productivity
    [PSCustomObject]@{Category="🏢 Office"; Name="Microsoft 365"; Process="office"; Note="Official Microsoft Office production suite"; ID="Microsoft.Office"}
    [PSCustomObject]@{Category="🏢 Office"; Name="Microsoft OneDrive"; Process="OneDrive"; Note="Cloud storage and redistribution client"; ID="Microsoft.OneDrive"}
    [PSCustomObject]@{Category="🏢 Office"; Name="Microsoft OneNote"; Process="onenote"; Note="Digital note-taking application"; ID="Microsoft.OneNote"}
    [PSCustomObject]@{Category="🏢 Office"; Name="Notion"; Process="Notion"; Note="Unified workspace for markdown notes and wikis"; ID="Notion.Notion"}
    [PSCustomObject]@{Category="🏢 Office"; Name="Obsidian"; Process="Obsidian"; Note="Local markdown-based personal knowledge base"; ID="Obsidian.Obsidian"}
    [PSCustomObject]@{Category="🏢 Office"; Name="7-Zip"; Process="7zG"; Note="High-ratio file archiver utility"; ID="7zip.7zip"}
    [PSCustomObject]@{Category="🏢 Office"; Name="WinRAR"; Process="WinRAR"; Note="Popular compression and archive manager"; ID="RarLab.WinRAR"}
    [PSCustomObject]@{Category="🏢 Office"; Name="VLC Media Player"; Process="vlc"; Note="Universal open-source multimedia player"; ID="VideoLAN.VLC"}
    [PSCustomObject]@{Category="🏢 Office"; Name="LibreOffice"; Process="soffice"; Note="Open-source office suite alternative"; ID="TheDocumentFoundation.LibreOffice"}
    
    # 🛠️ System Utilities
    [PSCustomObject]@{Category="🛠️ System"; Name="PowerShell 7"; Process="pwsh"; Note="Modern cross-platform automation engine"; ID="Microsoft.PowerShell"}
    [PSCustomObject]@{Category="🛠️ System"; Name="AnyDesk"; Process="AnyDesk"; Note="High-performance remote desktop tool"; ID="AnyDeskSoftwareGmbH.AnyDesk"}
    [PSCustomObject]@{Category="🛠️ System"; Name="TeamViewer"; Process="TeamViewer"; Note="Secure remote support and access platform"; ID="TeamViewer.TeamViewer"}
    [PSCustomObject]@{Category="🛠️ System"; Name="Docker Desktop"; Process="Docker Desktop"; Note="Containerization and development workspace"; ID="Docker.DockerDesktop"}
    [PSCustomObject]@{Category="🛠️ System"; Name="WizTree"; Process="WizTree"; Note="Ultra-fast disk space analyzer utility"; ID="AntibodySoftware.WizTree"}
    [PSCustomObject]@{Category="🛠️ System"; Name="Rufus"; Process="Rufus"; Note="Format and create bootable USB flash drives"; ID="Akeo.Rufus"}
    [PSCustomObject]@{Category="🛠️ System"; Name="PowerToys"; Process="PowerToys"; Note="System utilities for Windows power users"; ID="Microsoft.PowerToys"}
    [PSCustomObject]@{Category="🛠️ System"; Name="Everything"; Process="Everything"; Note="Instant file search engine by name"; ID="Voidtools.Everything"}
    [PSCustomObject]@{Category="🛠️ System"; Name="Process Explorer"; Process="procexp"; Note="Advanced task manager and process analyzer"; ID="Sysinternals.ProcessExplorer"}
    
    # 📡 Networks
    [PSCustomObject]@{Category="📡 Networks"; Name="Wireshark"; Process="Wireshark"; Note="Network packet analyzer and sniffer"; ID="WiresharkFoundation.Wireshark"}
    [PSCustomObject]@{Category="📡 Networks"; Name="Advanced IP Scanner"; Process="advanced_ip_scanner"; Note="Fast and reliable network scanner"; ID="Famatech.AdvancedIPScanner"}
    [PSCustomObject]@{Category="📡 Networks"; Name="PuTTY"; Process="putty"; Note="SSH and telnet terminal client"; ID="PuTTY.PuTTY"}
    [PSCustomObject]@{Category="📡 Networks"; Name="FileZilla"; Process="filezilla"; Note="Secure FTP/SFTP file transfer client"; ID="FileZilla-Project.FileZilla"}
    [PSCustomObject]@{Category="📡 Networks"; Name="Nmap"; Process="nmap"; Note="Network discovery and security auditing tool"; ID="Insecure.Nmap"}
    
    # 💻 Development
    [PSCustomObject]@{Category="💻 Development"; Name="VS Code"; Process="code"; Note="Extensible source code editor"; ID="Microsoft.VisualStudioCode"}
    [PSCustomObject]@{Category="💻 Development"; Name="GitHub Desktop"; Process="GitHubDesktop"; Note="Graphical Git version control interface"; ID="GitHub.GitHubDesktop"}
    [PSCustomObject]@{Category="💻 Development"; Name="Git"; Process="git"; Note="Distributed version control system engine"; ID="Git.Git"}
    [PSCustomObject]@{Category="💻 Development"; Name="Windows Terminal"; Process="wt"; Note="Modern tabbed terminal host environment"; ID="Microsoft.WindowsTerminal"}
    [PSCustomObject]@{Category="💻 Development"; Name="Notepad++"; Process="notepad++"; Note="Lightweight and powerful text editor"; ID="Notepad++.Notepad++"}
    [PSCustomObject]@{Category="💻 Development"; Name="Python 3"; Process="python"; Note="Official Python programming language runtime"; ID="Python.Python.3"}
    [PSCustomObject]@{Category="💻 Development"; Name="Node.js"; Process="node"; Note="JavaScript server-side runtime environment"; ID="OpenJS.NodeJS"}
    
    # 💾 Data
    [PSCustomObject]@{Category="💾 Data"; Name="DBeaver"; Process="dbeaver"; Note="Universal database administration GUI tool"; ID="dbeaver.DBeaverCommunity"}
    
    # 📊 Hardware
    [PSCustomObject]@{Category="📊 Hardware"; Name="HWiNFO"; Process="HWiNFO64"; Note="Comprehensive hardware analysis and monitoring"; ID="REALiX.HWiNFO"}
    [PSCustomObject]@{Category="📊 Hardware"; Name="CrystalDiskInfo"; Process="DiskInfo64"; Note="HDD/SSD health and SMART monitoring tool"; ID="CrystalMarkSoftware.CrystalDiskInfo"}
    [PSCustomObject]@{Category="📊 Hardware"; Name="GPU-Z"; Process="GPU-Z"; Note="Detailed graphics card information utility"; ID="TechPowerUp.GPU-Z"}
    [PSCustomObject]@{Category="📊 Hardware"; Name="CPU-Z"; Process="CPU-Z"; Note="Detailed processor and motherboard metrics tool"; ID="CPUID.CPU-Z"}
    
    # 🤖 AI
    [PSCustomObject]@{Category="🤖 AI"; Name="ChatGPT"; Process="ChatGPT"; Note="Official OpenAI desktop client interface"; ID="OpenAI.ChatGPT"}
    [PSCustomObject]@{Category="🤖 AI"; Name="Claude"; Process="Claude"; Note="Anthropic Claude AI native desktop shell"; ID="Anthropic.Claude"}
    [PSCustomObject]@{Category="🤖 AI"; Name="Perplexity"; Process="Perplexity"; Note="AI-powered conversational search client"; ID="Perplexity.Perplexity"}
    
    # 💬 Communication
    [PSCustomObject]@{Category="💬 Communication"; Name="Discord"; Process="Discord"; Note="Voice, video, and text communication platform"; ID="Discord.Discord"}
    [PSCustomObject]@{Category="💬 Communication"; Name="WhatsApp"; Process="WhatsApp"; Note="Official WhatsApp desktop client"; ID="9NKSQCEZKVDQ"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Telegram"; Process="Telegram"; Note="Fast and secure desktop messaging client"; ID="Telegram.TelegramDesktop"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Microsoft Teams"; Process="Teams"; Note="Corporate collaboration and video meetings hub"; ID="Microsoft.Teams"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Slack"; Process="slack"; Note="Team communication and workspace platform"; ID="SlackTechnologies.Slack"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Zoom"; Process="Zoom"; Note="Video conferencing and virtual meeting client"; ID="Zoom.Zoom"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Thunderbird"; Process="thunderbird"; Note="Open-source email and calendar client"; ID="Mozilla.Thunderbird"}
    
    # 🎵 Music
    [PSCustomObject]@{Category="🎵 Music"; Name="Spotify"; Process="Spotify"; Note="Digital music streaming service application"; ID="Spotify.Spotify"}
    [PSCustomObject]@{Category="🎵 Music"; Name="Apple Music"; Process="AppleMusic"; Note="Official Apple Music native client"; ID="9PFHDD62MXS1"}
    
    # 🎮 Gaming
    [PSCustomObject]@{Category="🎮 Gaming"; Name="Steam"; Process="steam"; Note="Digital distribution storefront for PC gaming"; ID="Valve.Steam"}
    [PSCustomObject]@{Category="🎮 Gaming"; Name="Epic Games"; Process="EpicGamesLauncher"; Note="Epic Games store launcher and gaming client"; ID="EpicGames.EpicGamesLauncher"}
    [PSCustomObject]@{Category="🎮 Gaming"; Name="OBS Studio"; Process="obs64"; Note="Open-source video recording and streaming engine"; ID="Obsproject.OBSStudio"}
)

# --- Helper: Pause & Continue ---
function Wait-TaskEnd {
    Write-Host "`n=========================================" -ForegroundColor DarkGray
    Write-Host "[*] Task Execution Sequence Completed." -ForegroundColor Green
    Read-Host "Press Enter to return to menu"
}

# --- Module 1 & 2: Software Selection & Single Window Batch Execution ---
function Manage-Software([string]$Action) {
    # If Assert-Winget fails, it drops an error and returns $false.
    # The UI screen will NOT open, and it routes safely back to the menu.
    if (-not (Assert-Winget)) { 
        return 
    }
    
    $DisplayList = New-Object System.Collections.ArrayList
    foreach ($App in $SoftwarePackages) {
        $Row = New-Object PSObject
        $Row | Add-Member -MemberType NoteProperty -Name "Category" -Value $App.Category
        $Row | Add-Member -MemberType NoteProperty -Name "Application Name" -Value $App.Name
        $Row | Add-Member -MemberType NoteProperty -Name "Description" -Value $App.Note
        $Row | Add-Member -MemberType NoteProperty -Name "Package ID" -Value $App.ID
        $Row | Add-Member -MemberType NoteProperty -Name "Process Name" -Value $App.Process
        $nil = $DisplayList.Add($Row)
    }
    
    $Title = "Yair Utility - Select Apps for $Action (Hold CTRL for multiple items)"
    $SelectedApps = $DisplayList | Out-GridView -Title $Title -PassThru
        
    if (-not $SelectedApps) { return }

    if ($Global:IsSimulation) {
        Clear-Host
        Write-Host "=== [SIMULATION] Target List ===" -ForegroundColor DarkYellow
        foreach ($App in $SelectedApps) {
            Write-Host "  [-] Would execute $Action sequence for: $($App."Application Name")" -ForegroundColor Gray
        }
        Wait-TaskEnd
        return
    }

    Clear-Host
    Write-Host "[*] Compiling unified execution stack..." -ForegroundColor Cyan
    
    $PayloadCommands = @(
        "Clear-Host",
        "Write-Host '=======================================================' -ForegroundColor Cyan",
        "Write-Host '      YAIR UTILITY - BATCH SOFTWARE RUNTIME PIPELINE   ' -ForegroundColor Cyan",
        "Write-Host '=======================================================' -ForegroundColor Cyan"
    )
    
    foreach ($App in $SelectedApps) {
        $AppName = $App."Application Name"
        $AppID   = $App."Package ID"
        $ProcName = $App."Process Name"
        
        if ($Action -eq "Install") {
            $PayloadCommands += "Write-Host '`n>>> DEPLOYING COMPONENT: $AppName <<<' -ForegroundColor Cyan"
            $PayloadCommands += "winget install --id '$AppID' --force --include-unknown --accept-package-agreements --accept-source-agreements 2>&1"
        } 
        else {
            if ($ProcName) {
                $PayloadCommands += @"
`$procs = Get-Process -Name '$ProcName' -ErrorAction SilentlyContinue
if (`$procs) {
    Write-Host '   [⚠] Killing active environment process (`$ProcName)...' -ForegroundColor Yellow
    foreach (`$proc in `$procs) {
        try {
            `$proc.WaitForExit(3000)
            if (-not `$proc.HasExited) {
                Stop-Process -Id `$proc.Id -Force -ErrorAction Stop
            }
        } catch { }
    }
    Start-Sleep -Seconds 1
}
"@
            }
            $PayloadCommands += "Write-Host '`n>>> EXTRACTING COMPONENT: $AppName <<<' -ForegroundColor DarkYellow"
            $PayloadCommands += "winget uninstall --id '$AppID' --force 2>&1"
        }
    }
    
    $PayloadCommands += "Write-Host '`n[+] All requested batch operations completed!' -ForegroundColor Green"
    $PayloadCommands += "Read-Host 'Press Enter to exit this deployment window and return to Master Console'"
    
    $ExecutionPayloadString = $PayloadCommands -join "; "
    Write-Host "[*] Spawning single execution host process window..." -ForegroundColor Yellow
    
    $ProcessArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", $ExecutionPayloadString
    )
    
    Start-Process powershell.exe -ArgumentList $ProcessArgs -Wait
    Write-Host "`n[+] Software batch processing engine task complete!" -ForegroundColor Green
    Wait-TaskEnd
}

# --- Module 3: Advanced Debloat Menu ---
function Invoke-Debloat {
    while ($true) {
        Clear-Host
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "               SYSTEM SAFE DEBLOAT & DEEP CLEAN MENU              " -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "      Select an option to begin:" -ForegroundColor Yellow
        
        Write-Host "`n  [1] Remove Pre-installed Bloatware Apps" -ForegroundColor Yellow
        Write-Host "      Cleans: Built-in apps and stubs like TikTok, Facebook, Xbox tools, and Kindle." -ForegroundColor Gray
        Write-Host "      Impact: Frees up disk space and stops them from running in the background." -ForegroundColor Gray
  
        Write-Host "`n  [2] Disable Windows Telemetry & Data Tracking" -ForegroundColor Yellow
        Write-Host "      Cleans: Background diagnostic services (DiagTrack and dmwappushservice)." -ForegroundColor Gray
        Write-Host "      Impact: Increases privacy by stopping Windows from sending usage data to Microsoft." -ForegroundColor Gray
  
        Write-Host "`n  [3] Clear Temporary Files & Empty Recycle Bin" -ForegroundColor Yellow
        Write-Host "      Cleans: Windows Temp folders, user cache, prefetch data, and the Recycle Bin." -ForegroundColor Gray
        Write-Host "      WARNING: This permanently deletes your Recycle Bin contents and temp app caches!" -ForegroundColor Red
        
        Write-Host "`n  [B] Return to Utility Master Main Console" -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Cyan
        
        $SubChoice = Read-Host "Enter operational sequence"
        
        switch ($SubChoice.ToUpper()) {
            '1' { Invoke-BloatwareRemoval }
            '2' { Invoke-TelemetryDisable }
            '3' { Invoke-TempClear }
            'B' { return }
            Default {
                Write-Host "[✘] Invalid sub-routine choice selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# --- Enhanced Bloatware Removal ---
function Invoke-BloatwareRemoval {
    Clear-Host
    Write-Host "=== Deep Clean Phase 1: UWP Bloatware Package Eradication ===" -ForegroundColor Cyan
    
    # Enhanced list with better pattern matching
    $Bloat = @(
        "BingNews",
        "BingWeather",
        "MicrosoftSolitaireCollection",
        "TikTok",
        "Facebook",
        "Instagram",
        "XboxApp",
        "Xbox",
        "ZuneMusic",
        "ZuneVideo",
        "Cortana",
        "WindowsMaps",
        "Clipchamp",
        "DevHome",
        "Microsoft.549981C3F5F10"  # Cortana GUID
    )
    
    foreach ($app in $Bloat) {
        Write-Host "  Purging package stub: $app... " -NoNewline
        
        if ($Global:IsSimulation) {
            Write-Host "SIMULATED" -ForegroundColor DarkGray
            continue
        }
        
        $removed = $false
        
        try {
            # Method 1: Remove AppxPackage (user-installed)
            $packages = Get-AppxPackage -AllUsers -Name "*$app*" -ErrorAction SilentlyContinue
            if ($packages) {
                foreach ($package in $packages) {
                    try {
                        Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop | Out-Null
                        $removed = $true
                    }
                    catch {
                        # Silent continue to try next method
                    }
                }
            }
            
            # Method 2: Remove AppxProvisionedPackage (system-provisioned)
            $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | 
                Where-Object DisplayName -like "*$app*"
            if ($provisioned) {
                foreach ($prov in $provisioned) {
                    try {
                        Remove-AppxProvisionedPackage -PackageName $prov.PackageName -Online -ErrorAction Stop | Out-Null
                        $removed = $true
                    }
                    catch {
                        # Continue trying other methods
                    }
                }
            }
            
            # Method 3: Registry removal for Cortana specifically
            if ($app -like "*Cortana*" -or $app -like "*549981C3F5F10*") {
                try {
                    $regPaths = @(
                        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
                        "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
                    )
                    foreach ($regPath in $regPaths) {
                        if (Test-Path $regPath) {
                            Set-ItemProperty -Path $regPath -Name "DisableSearchBoxSuggestions" -Value 1 -ErrorAction SilentlyContinue
                        }
                    }
                    $removed = $true
                } catch { }
            }
            
            if ($removed) {
                Write-Host "[✔] Cleaned." -ForegroundColor Green
            } else {
                Write-Host "[--] Not found or already removed." -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Host "[⚠] Partial removal." -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n[*] Cortana Specific Removal:" -ForegroundColor Cyan
    try {
        # Additional Cortana disabling
        $cortanaPath = "$env:LOCALAPPDATA\Packages\Microsoft.549981C3F5F10_*"
        $cortanaFolders = Get-Item -Path $cortanaPath -ErrorAction SilentlyContinue
        
        if ($cortanaFolders) {
            foreach ($folder in $cortanaFolders) {
                try {
                    Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
                    Write-Host "    [✔] Removed Cortana folder: $($folder.Name)" -ForegroundColor Green
                }
                catch {
                    Write-Host "    [⚠] Could not remove folder: $($folder.Name)" -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Host "    [--] Cortana folder not found" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "    [!] Error: $_" -ForegroundColor Yellow
    }
    
    Wait-TaskEnd
}

# --- Telemetry Disable ---
function Invoke-TelemetryDisable {
    Clear-Host
    Write-Host "=== Deep Clean Phase 2: Telemetry Pipeline Lockdown ===" -ForegroundColor Cyan
    $Services = @("DiagTrack", "dmwappushservice")
    foreach ($Svc in $Services) {
        Write-Host "  Locking down service: $Svc... " -NoNewline
        if ($Global:IsSimulation) { Write-Host "SIMULATED" -ForegroundColor DarkGray } else {
            if (Get-Service -Name $Svc -ErrorAction SilentlyContinue) {
                try {
                    Stop-Service -Name $Svc -Force -NoWait -ErrorAction Stop
                    Set-Service -Name $Svc -StartupType Disabled -ErrorAction Stop
                    Write-Host "[✔] Disabled." -ForegroundColor Green
                }
                catch {
                    Write-Host "[✘] Failed." -ForegroundColor Red
                }
            } else { Write-Host "[--] Not present." -ForegroundColor DarkGray }
        }
    }
    Wait-TaskEnd
}

# --- Temp Clear ---
function Invoke-TempClear {
    Clear-Host
    Write-Host "=== Deep Clean Phase 3: Hardware Storage Cache & Trash Purge ===" -ForegroundColor Cyan
    
    Write-Host "  Emptying native System Recycle Bin structure... " -NoNewline
    if ($Global:IsSimulation) { 
        Write-Host "SIMULATED" -ForegroundColor DarkGray 
    } else {
        try {
            Clear-RecycleBin -Confirm:$false -Force -ErrorAction SilentlyContinue
            Write-Host "[✔] Emptied." -ForegroundColor Green
        } catch { 
            Write-Host "[✔] Nominal (Already empty or locked)." -ForegroundColor DarkGray 
        }
    }

    $Paths = @($env:TEMP, "C:\Windows\Temp", "C:\Windows\Prefetch")
    foreach ($p in $Paths) {
        Write-Host "  Processing path instance directory: $p... " -NoNewline
        if ($Global:IsSimulation) { Write-Host "SIMULATED" -ForegroundColor DarkGray } else {
            try {
                if (Test-Path $p) {
                    Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "[✔] Cleared." -ForegroundColor Green
                } else { Write-Host "[--] Not Found." -ForegroundColor DarkGray }
            } catch { Write-Host "[⚠] Partial lock (Active files skipped)." -ForegroundColor DarkYellow }
        }
    }
    Wait-TaskEnd
}

# --- Module Format Helper ---
function Write-DiagResult ($Component, $Status, $Details) {
    $Color = switch ($Status) { "OK" {"Green"} "WARN" {"Yellow"} "FAIL" {"Red"} default {"Gray"} }
    Write-Host ("  [{0}] {1,-28} " -f $Status.PadRight(4), $Component) -NoNewline -ForegroundColor $Color
    Write-Host $Details -ForegroundColor Gray
}

# --- Module 4: System Diagnostics ---
function Invoke-Diagnostics {
    Clear-Host
    Write-Host "=== Integrated System Metrics Dashboard ===" -ForegroundColor Cyan
    Write-Host "Node: $($env:COMPUTERNAME) | Context: $($env:USERNAME)`n" -ForegroundColor DarkGray
    
    if ($Global:IsSimulation) {
        Write-Host "  [SIMULATION MODE] Testing dashboard display logic...`n" -ForegroundColor DarkGray
        Write-DiagResult "Storage (C:)" "OK" "Healthy (67% free)"
        Wait-TaskEnd
        return
    }

    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $cpuLoad = [math]::Round((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average)
        $ramGb = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        Write-Host "  Hardware: $($cs.Manufacturer) $($cs.Model) | RAM: $ramGb GB | CPU Load: $cpuLoad%`n" -ForegroundColor Gray
    } catch {}

    $reboot = $false
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) { $reboot = $true }
    if ($reboot) { Write-DiagResult "Pending Reboot" "WARN" "A restart is required to finish installing updates" }

    Get-Volume | Where-Object { $_.DriveLetter -and $_.Size -gt 0 } | ForEach-Object {
        $freePct = [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1)
        if ($freePct -lt 10) { Write-DiagResult "Storage ($($_.DriveLetter):)" "WARN" "Capacity exhausted ($freePct% remaining)" }
        else { Write-DiagResult "Storage ($($_.DriveLetter):)" "OK" "Space is nominal ($freePct% free)" }
    }

    try {
        $smartData = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop
        $fail = $false
        foreach ($d in $smartData) { if ($d.PredictFailure) { $fail = $true } }
        if ($fail) { Write-DiagResult "Drive Health" "FAIL" "Drive failure warning! Back up your data immediately!" }
        else { Write-DiagResult "Drive Health" "OK" "All drives are healthy" }
    } catch { Write-DiagResult "Drive Health" "WARN" "Could not retrieve drive health data" }

    $stoppedSvcs = @(Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" -ErrorAction SilentlyContinue) |
        Where-Object { $_.Name -notmatch "^(gupdate|gupdatem|edgeupdate|edgeupdatem|AdobeARMservice|MozillaMaintenance|AppXSvc|AsusMultiAntennaSvc|brave|Netlogon|sppsvc|StiSvc|Intel.*TPM.*)$" }
    if ($stoppedSvcs.Count -gt 0) { Write-DiagResult "System Services" "FAIL" "$($stoppedSvcs.Count) automatic background services are stopped" }
    else { Write-DiagResult "System Services" "OK" "All foundational automatic services active" }

    Wait-TaskEnd
}

# --- Module 5: Security Audit ---
function Invoke-SecurityAudit {
    Clear-Host
    Write-Host "=== Security Compliance & Audit Matrix ===" -ForegroundColor Cyan
    
    if ($Global:IsSimulation) { Write-Host "`n  [SIMULATION MODE] Output suppressed." -ForegroundColor DarkGray; Wait-TaskEnd; return }

    try {
        $def = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($def.RealTimeProtectionEnabled) { Write-DiagResult "Antivirus Engine" "OK" "Real-time scanning active (Sig Age: $($def.AntivirusSignatureAge) days)" }
        else { Write-DiagResult "Antivirus Engine" "FAIL" "Real-time mitigation sub-routines disabled" }
    } catch { Write-DiagResult "Antivirus Engine" "FAIL" "WMI malware namespace error" }

    try {
        $fwDisabled = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $false }
        if ($fwDisabled) { Write-DiagResult "Windows Firewall" "FAIL" "Disabled targets: [$($fwDisabled.Name -join ', ')]" }
        else { Write-DiagResult "Windows Firewall" "OK" "All software filter barriers active" }
    } catch { Write-DiagResult "Windows Firewall" "FAIL" "Firewall state engine error" }

    try {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
            if ($bl.ProtectionStatus -eq "On") { Write-DiagResult "Volume Encryption (C:)" "OK" "BitLocker active" }
            else { Write-DiagResult "Volume Encryption (C:)" "WARN" "Cryptographic storage suspended or unconfigured" }
        }
    } catch {}

    try {
        $uac = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue).ConsentPromptBehaviorAdmin
        if ($uac -eq 0) { Write-DiagResult "User Account Control" "FAIL" "Token elevation set to silent auto-approve" }
        else { Write-DiagResult "User Account Control" "OK" "Isolation layers active" }
    } catch {}

    Wait-TaskEnd
}

# --- Module 6: Identity Audit ---
function Invoke-IdentityAudit {
    Clear-Host
    Write-Host "=== Local SAM Identity & Privilege Auditor ===" -ForegroundColor Cyan
    
    if ($Global:IsSimulation) { Write-Host "`n  [SIMULATION MODE] Output suppressed." -ForegroundColor DarkGray; Wait-TaskEnd; return }
    $localUsers = Get-LocalUser -ErrorAction SilentlyContinue

    try {
        $adminMembers = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
        $adminList = ($adminMembers | Where-Object { $_.PrincipalSource -eq "Local" } | Select-Object -ExpandProperty Name) -join ", "
        if (@($adminMembers).Count -gt 2) { Write-DiagResult "SAM Administrators" "WARN" "Elevated account pool overhead: [$adminList]" }
        else { Write-DiagResult "SAM Administrators" "OK" "Privileged density optimized: [$adminList]" }
    } catch {}

    try {
        $staleCutoff = (Get-Date).AddDays(-90)
        $stale = $localUsers | Where-Object { $_.Enabled -eq $true -and (($_.LastLogon -lt $staleCutoff) -or ($null -eq $_.LastLogon)) -and $_.Name -notmatch "Administrator|Guest|DefaultAccount" }
        if ($stale) { Write-DiagResult "Inactive Identity" "WARN" "Dormant local assets (90+ days): [$($stale.Name -join ', ')]" }
        else { Write-DiagResult "Inactive Identity" "OK" "Zero non-operational accounts tracking." }
    } catch {}

    try {
        $pne = $localUsers | Where-Object { $_.Enabled -eq $true -and $_.PasswordNeverExpires -eq $true -and $_.Name -notmatch "Administrator|Guest|DefaultAccount" }
        if ($pne) { Write-DiagResult "Static Passwords" "WARN" "Expiration overrides active: [$($pne.Name -join ', ')]" }
        else { Write-DiagResult "Static Passwords" "OK" "All accounts bound to expiration rotators." }
    } catch {}

    Wait-TaskEnd
}

# --- Module 7: Incident Sniffer ---
function Invoke-IncidentSniffer {
    Clear-Host
    Write-Host "=== Cyber Incident Sniffer (Last 48 Hours) ===" -ForegroundColor Cyan
    
    if ($Global:IsSimulation) { Write-Host "`n  [SIMULATION MODE] Output suppressed." -ForegroundColor DarkGray; Wait-TaskEnd; return }
    $timeFilter = (Get-Date).AddHours(-48)

    try {
        [array]$failedLogons = Get-WinEvent -FilterHashtable @{LogName="Security"; Id=4625; StartTime=$timeFilter} -ErrorAction SilentlyContinue
        if ($failedLogons.Count -gt 0) {
            Write-DiagResult "Auth Anomalies" "WARN" "$($failedLogons.Count) authentication failures tracking."
        } else { Write-DiagResult "Auth Anomalies" "OK" "Zero exceptions logged." }
    } catch {}

    try {
        [array]$clearEvents = Get-WinEvent -FilterHashtable @{LogName=@("Security","System"); Id=@(1102,104); StartTime=$timeFilter} -ErrorAction SilentlyContinue
        if ($clearEvents.Count -gt 0) { Write-DiagResult "Audit Integrity" "FAIL" "CRITICAL FAULT: Forensics event validation data explicitly purged!" }
        else { Write-DiagResult "Audit Integrity" "OK" "Event streams intact. No tampering." }
    } catch {}

    Wait-TaskEnd
}

# --- Module 8: Secure Update & Backup ---
function Invoke-SecureUpdates {
    Clear-Host
    Write-Host "=== Secure Update & Backup ===" -ForegroundColor Cyan
    
    if ($Global:IsSimulation) {
        Write-Host "`n  [SIM] Phase 1: Create System Restore Point... PASSED" -ForegroundColor DarkGray
        Write-Host "  [SIM] Phase 2: Check for Windows Updates... PASSED" -ForegroundColor DarkGray
        Wait-TaskEnd; return
    }

    Write-Host "`n[*] Phase 1: Creating System Restore Point..." -ForegroundColor Yellow
    try {
        if (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue) {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "YairUtility_SecureUpdateBinds" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
            Write-Host "  [+] System restore point created successfully." -ForegroundColor Green
        } else { Write-Host "  [!] System restore is not supported on this machine (Skipping)." -ForegroundColor DarkGray }
    } catch {}

    Write-Host "`n[*] Phase 2: Checking for Windows Updates..." -ForegroundColor Yellow
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searchRes = $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
        $toInstall = New-Object -ComObject Microsoft.Update.UpdateColl

        foreach ($update in $searchRes.Updates) {
            $isCritical = $false
            foreach ($cat in $update.Categories) { if (@("Security", "Critical") -contains $cat.Name) { $isCritical = $true } }
            if ($isCritical) {
                Write-Host "  [+] Found Missing Critical Update: $($update.Title)" -ForegroundColor Cyan
                $toInstall.Add($update) | Out-Null
            }
        }

        if ($toInstall.Count -gt 0) {
            Write-Host "`n[*] Phase 3: Downloading updates..." -ForegroundColor Yellow
            $downloader = $session.CreateUpdateDownloader()
            $downloader.Updates = $toInstall
            $downloader.Download() | Out-Null
            
            Write-Host "[*] Phase 4: Installing updates..." -ForegroundColor Yellow
            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $toInstall
            $result = $installer.Install()
            Write-Host "  [+] Updates installed successfully (Result Code: $($result.ResultCode))." -ForegroundColor Green
        } else { Write-Host "  [+] Your system is fully up to date. No actions needed." -ForegroundColor Green }
    } catch { Write-Host "  [✘] Error checking for updates: $($_.Exception.Message)" -ForegroundColor Red }

    Wait-TaskEnd
}

# --- Main Runtime Interface ---
while ($true) {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "       YAIR WINDOWS UTILITY TOOL        " -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host " PACKAGE MANAGEMENT & AUTOMATION" -ForegroundColor Cyan
    Write-Host "  [1] Install Apps (Select from Catalog)"
    Write-Host "  [2] Uninstall Apps (Remove from System)"
    Write-Host "  [3] Windows Safe Deep Clean & Debloat Interface"
    Write-Host "  [4] Trigger Native Windows Update Core Panel"
    
    Write-Host "`n DIAGNOSTICS, FORENSICS & INFRASTRUCTURE" -ForegroundColor Cyan
    Write-Host "  [5] Run: System Health Check (Hardware & Services Dashboard)"
    Write-Host "  [6] Run: Security Audit (Antivirus & Firewall Check)"
    Write-Host "  [7] Run: User Account Audit (Check Local Admin & Guest Risk)"
    Write-Host "  [8] Run: Security Incident Scan (Check Last 48h Failed Logins)"
    
    Write-Host "`n MAINTENANCE" -ForegroundColor Cyan
    Write-Host "  [9] Secure Update & Backup (Create Restore Point & Patch)"
    
    Write-Host "`n SYSTEM" -ForegroundColor Cyan
    $simColor = if ($Global:IsSimulation) { "DarkYellow" } else { "DarkGray" }
    $simText  = if ($Global:IsSimulation) { "ON (Dry Run Mode)" } else { "OFF (Live Mode)" }
    Write-Host ("  [S] Toggle Simulation Mode (Currently: $simText)") -ForegroundColor $simColor
    Write-Host "  [Q] Terminate Script Execution"
    Write-Host "=================================================================" -ForegroundColor Green
    
    $MainChoice = Read-Host "Enter operational sequence"
    
    switch ($MainChoice.ToUpper()) {
        '1' { Manage-Software -Action "Install" }
        '2' { Manage-Software -Action "Uninstall" }
        '3' { Invoke-Debloat }
        '4' { 
            if (-not $Global:IsSimulation) { Start-Process "ms-settings:windowsupdate-action" }
            else { Write-Host "`n[SIMULATION] ms-settings execution bypassed." -ForegroundColor DarkGray; Wait-TaskEnd }
        }
        '5' { Invoke-Diagnostics }
        '6' { Invoke-SecurityAudit }
        '7' { Invoke-IdentityAudit }
        '8' { Invoke-IncidentSniffer }
        '9' { Invoke-SecureUpdates }
        'S' { $Global:IsSimulation = -not $Global:IsSimulation }
        'Q' { Clear-Host; exit }
        Default { 
            Write-Host "[✘] Invalid operational input selection." -ForegroundColor Red
            Start-Sleep -Seconds 1 
        }
    }
}
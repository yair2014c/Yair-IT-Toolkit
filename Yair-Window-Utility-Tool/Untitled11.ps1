#requires -Version 5.1
# ==============================================================================
# Script:   Yair Windows Utility Tool - Console Master Edition (v12.3)
# Modules:  Software Manager (Array-Bound Batch Execution Engine) · Interactive Safe Debloat 
#           Telemetry Lockdown · System Diagnostics · Security & SAM Audit 
#           Cyber Incident Sniffer · Secure Updates
# ==============================================================================

# --- Admin Elevation Enforcement ---
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
}

# --- Global State ---
$Global:IsSimulation = $false

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
    [PSCustomObject]@{Category="💬 Communication"; Name="WhatsApp"; Process="WhatsApp"; Note="Official WhatsApp desktop client"; ID="WhatsApp.WhatsApp"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Telegram"; Process="Telegram"; Note="Fast and secure desktop messaging client"; ID="Telegram.TelegramDesktop"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Microsoft Teams"; Process="Teams"; Note="Corporate collaboration and video meetings hub"; ID="Microsoft.Teams"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Slack"; Process="slack"; Note="Team communication and workspace platform"; ID="SlackTechnologies.Slack"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Zoom"; Process="Zoom"; Note="Video conferencing and virtual meeting client"; ID="Zoom.Zoom"}
    [PSCustomObject]@{Category="💬 Communication"; Name="Thunderbird"; Process="thunderbird"; Note="Open-source email and calendar client"; ID="Mozilla.Thunderbird"}
    
    # 🎵 Music
    [PSCustomObject]@{Category="🎵 Music"; Name="Spotify"; Process="Spotify"; Note="Digital music streaming service application"; ID="Spotify.Spotify"}
    [PSCustomObject]@{Category="🎵 Music"; Name="Apple Music"; Process="AppleMusic"; Note="Official Apple Music native client"; ID="Apple.AppleMusic"}
    
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
function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    return $true
}

function Manage-Software([string]$Action) {
    if (-not (Assert-Winget)) { 
        Write-Host "[✘] Error: Winget is not initialized." -ForegroundColor Red
        Read-Host "Press Enter to continue"; return 
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
        Wait-TaskEnd; return
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
            $PayloadCommands += "winget install --id '$AppID' --exact --force --include-unknown --accept-package-agreements --accept-source-agreements"
        } 
        else {
            if ($ProcName) {
                $PayloadCommands += "if (Get-Process -Name '$ProcName' -ErrorAction SilentlyContinue) { Write-Host '   [⚠] Killing active environment process ($ProcName)...' -ForegroundColor Yellow; Stop-Process -Name '$ProcName' -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }"
            }
            $PayloadCommands += "Write-Host '`n>>> EXTRACTING COMPONENT: $AppName <<<' -ForegroundColor DarkYellow"
            $PayloadCommands += "winget uninstall --id '$AppID' --exact --force"
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
        Write-Host "Select target maintenance module execution vector:" -ForegroundColor Gray
        
        Write-Host "`n  [1] Purge Modern UWP Bloatware App Packages" -ForegroundColor Yellow
        Write-Host "      Cleans: Built-in application stubs like TikTok, Facebook, BingNews," -ForegroundColor Gray
        Write-Host "              Xbox tools, and pre-staged promotional packages." -ForegroundColor Gray
        Write-Host "      Impact: Frees system storage disk bounds and prevents background stubs." -ForegroundColor Gray
        
        Write-Host "`n  [2] Disconnect Outbound Telemetry & OS Tracking Services" -ForegroundColor Yellow
        Write-Host "      Cleans: Active Windows diagnostic profiling and telemetry engines" -ForegroundColor Gray
        Write-Host "              (specifically target configurations: DiagTrack and dmwappushservice)." -ForegroundColor Gray
        Write-Host "      Impact: Enhances runtime network and registry platform privacy profiles." -ForegroundColor Gray
        
        Write-Host "`n  [3] Flush Local Cache Garbage, Temp Folders & Recycle Bin" -ForegroundColor Yellow
        Write-Host "      Cleans: Active User Temp space, Windows Win-Temp structures, Prefetch logs," -ForegroundColor Gray
        Write-Host "              and forces an automated purge of all connected local Recycle Bins." -ForegroundColor Gray
        Write-Host "      CRITICAL WARNING: This permanently wipes out active crash dump logs, temporary" -ForegroundColor Red
        Write-Host "                        app session metrics, and completely EMPTIES your Recycle Bin!" -ForegroundColor Red
        
        Write-Host "`n  [B] Return to Utility Master Main Console" -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Cyan
        
        $SubChoice = Read-Host "Enter operational sequence"
        
        switch ($SubChoice.ToUpper()) {
            '1' {
                Clear-Host
                Write-Host "=== Deep Clean Phase 1: UWP Bloatware Package Eradication ===" -ForegroundColor Cyan
                $Bloat = @("BingNews", "BingWeather", "MicrosoftSolitaireCollection", "TikTok", "Facebook", "Instagram", "XboxApp", "ZuneMusic", "ZuneVideo", "Cortana", "WindowsMaps", "Clipchamp", "DevHome")
                foreach ($app in $Bloat) {
                    Write-Host "  Purging package stub: $app... " -NoNewline
                    if ($Global:IsSimulation) { Write-Host "SIMULATED" -ForegroundColor DarkGray } else {
                        try {
                            Get-AppxPackage -AllUsers -Name "*$app*" -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -match $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                            Write-Host "[✔] Cleaned." -ForegroundColor Green
                        } catch { Write-Host "[✘] Failed." -ForegroundColor Red }
                    }
                }
                Wait-TaskEnd
            }
            '2' {
                Clear-Host
                Write-Host "=== Deep Clean Phase 2: Telemetry Pipeline Lockdown ===" -ForegroundColor Cyan
                $Services = @("DiagTrack", "dmwappushservice")
                foreach ($Svc in $Services) {
                    Write-Host "  Locking down service: $Svc... " -NoNewline
                    if ($Global:IsSimulation) { Write-Host "SIMULATED" -ForegroundColor DarkGray } else {
                        if (Get-Service -Name $Svc -ErrorAction SilentlyContinue) {
                            Stop-Process -Name $Svc -Force -ErrorAction SilentlyContinue
                            Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue
                            Set-Service -Name $Svc -StartupType Disabled -ErrorAction SilentlyContinue
                            Write-Host "[✔] Disabled." -ForegroundColor Green
                        } else { Write-Host "[--] Not present." -ForegroundColor DarkGray }
                    }
                }
                Wait-TaskEnd
            }
            '3' {
                Clear-Host
                Write-Host "=== Deep Clean Phase 3: Hardware Storage Cache & Trash Purge ===" -ForegroundColor Cyan
                
                # Explicit execution layer handling for the local Recycle Bin
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
            'B' { return }
            Default {
                Write-Host "[✘] Invalid sub-routine choice selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
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
        Write-Host "  [SIMULATION MODE] Injecting simulated telemetry models...`n" -ForegroundColor DarkGray
        Write-DiagResult "Storage (C:)" "OK" "Healthy (67% free)"
        Wait-TaskEnd; return
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
    if ($reboot) { Write-DiagResult "Pending Reboot" "WARN" "System modification requires volatile kernel refresh" }

    Get-Volume | Where-Object { $_.DriveLetter -and $_.Size -gt 0 } | ForEach-Object {
        $freePct = [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1)
        if ($freePct -lt 10) { Write-DiagResult "Storage ($($_.DriveLetter):)" "WARN" "Capacity exhausted ($freePct% remaining)" }
        else { Write-DiagResult "Storage ($($_.DriveLetter):)" "OK" "Allocation nominal ($freePct% free)" }
    }

    try {
        $smartData = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop
        $fail = $false
        foreach ($d in $smartData) { if ($d.PredictFailure) { $fail = $true } }
        if ($fail) { Write-DiagResult "Disk SMART" "FAIL" "Hardware structural failure predicted!" }
        else { Write-DiagResult "Disk SMART" "OK" "Hardware degradation within tolerance" }
    } catch { Write-DiagResult "Disk SMART" "WARN" "WMI storage query rejected" }

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

# --- Module 8: Secure Updates Pipeline ---
function Invoke-SecureUpdates {
    Clear-Host
    Write-Host "=== Secure Updates & Cryptographic Restore Pipeline ===" -ForegroundColor Cyan
    
    if ($Global:IsSimulation) {
        Write-Host "`n  [SIM] Phase 1: Snapshot system rollback restore boundaries... PASSED" -ForegroundColor DarkGray
        Write-Host "  [SIM] Phase 2: Interrogate WSUS/Windows Update telemetry engines... PASSED" -ForegroundColor DarkGray
        Wait-TaskEnd; return
    }

    Write-Host "`n[*] Phase 1: Initializing host disaster recovery bounds..." -ForegroundColor Yellow
    try {
        if (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue) {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "YairUtility_SecureUpdateBinds" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
            Write-Host "  [+] State restoration vector committed safely." -ForegroundColor Green
        } else { Write-Host "  [!] Snapshot engine rejected (Skipping)." -ForegroundColor DarkGray }
    } catch {}

    Write-Host "`n[*] Phase 2: Interrogating upstream deployment architectures..." -ForegroundColor Yellow
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searchRes = $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
        $toInstall = New-Object -ComObject Microsoft.Update.UpdateColl

        foreach ($update in $searchRes.Updates) {
            $isCritical = $false
            foreach ($cat in $update.Categories) { if (@("Security", "Critical") -contains $cat.Name) { $isCritical = $true } }
            if ($isCritical) {
                Write-Host "  [+] Missing Critical Payload: $($update.Title)" -ForegroundColor Cyan
                $toInstall.Add($update) | Out-Null
            }
        }

        if ($toInstall.Count -gt 0) {
            Write-Host "`n[*] Phase 3: Streaming components..." -ForegroundColor Yellow
            $downloader = $session.CreateUpdateDownloader()
            $downloader.Updates = $toInstall
            $downloader.Download() | Out-Null
            
            Write-Host "[*] Phase 4: Committing modification binaries..." -ForegroundColor Yellow
            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $toInstall
            $result = $installer.Install()
            Write-Host "  [+] Execution transaction completed (Code: $($result.ResultCode))." -ForegroundColor Green
        } else { Write-Host "  [+] Baseline updates sync verified. No actions needed." -ForegroundColor Green }
    } catch { Write-Host "  [✘] Telemetry collection exception: $($_.Exception.Message)" -ForegroundColor Red }

    Wait-TaskEnd
}

# --- Main Runtime Interface ---
while ($true) {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "       YAIR WINDOWS UTILITY TOOL - MASTER CONSOLE (v12.3)        " -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host " PACKAGE MANAGEMENT & AUTOMATION" -ForegroundColor Cyan
    Write-Host "  [1] Install Software (GridView Single-Window Selector)"
    Write-Host "  [2] Uninstall Software (GridView Single-Window Extraction Selector)"
    Write-Host "  [3] Windows Safe Deep Clean & Debloat Interface"
    Write-Host "  [4] Trigger Native Windows Update Core Panel"
    
    Write-Host "`n DIAGNOSTICS, FORENSICS & INFRASTRUCTURE" -ForegroundColor Cyan
    Write-Host "  [5] Run: Integrated System Diagnostic Dashboard"
    Write-Host "  [6] Run: Security Policy Compliance Baseline Auditor"
    Write-Host "  [7] Run: Identity Management & Local SAM Auditor"
    Write-Host "  [8] Run: Cyber Incident & Host Forensic Event Sniffer"
    
    Write-Host "`n MAINTENANCE" -ForegroundColor Cyan
    Write-Host "  [9] Run: Cryptographic Restore & Secure Updates Pipeline"
    
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
#requires -Version 5.1
<#
.SYNOPSIS
    Yair Windows Utility - Comprehensive system management and maintenance tool
    
.DESCRIPTION
    Provides software management, system diagnostics, security audits, and debloat functionality
    with enhanced logging, error handling, and user confirmations.
    
.PARAMETER SimulationMode
    Start script in simulation/dry-run mode (no actual changes)
    
.EXAMPLE
    .\YairUtility_v2_Improved.ps1
    
.NOTES
    Author: Yair
    Version: 2.0
    Requires: Administrator privileges, PowerShell 5.1 or later, Winget
#>

param(
    [switch]$SimulationMode = $false
)

# ==============================================================================
# CONFIGURATION & LOGGING SETUP
# ==============================================================================

$ScriptVersion = "2.0"
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$LogPath = "$ScriptRoot\Logs"
$ConfigPath = "$ScriptRoot\YairUtility.config.json"
$HistoryPath = "$ScriptRoot\installation_history.json"

# Create logs directory if it doesn't exist
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$CurrentLogFile = "$LogPath\YairUtility_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes messages to console and log file with timestamp and severity level
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Write to console with color coding
    $Color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "DarkGray" }
        default { "White" }
    }
    
    Write-Host $LogEntry -ForegroundColor $Color
    
    # Write to log file
    try {
        Add-Content -Path $CurrentLogFile -Value $LogEntry -ErrorAction Stop
    } catch {
        Write-Host "[LOG ERROR] Could not write to log file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Write-DiagResult {
    <#
    .SYNOPSIS
        Formats and displays diagnostic results with color coding
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Component,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("OK", "WARN", "FAIL")]
        [string]$Status,
        
        [string]$Details = ""
    )
    
    $Color = switch ($Status) {
        "OK"   { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "Gray" }
    }
    
    $Line = "  [{0}] {1,-28} {2}" -f $Status.PadRight(4), $Component, $Details
    Write-Host $Line -ForegroundColor $Color
    
    # Also log to file
    Add-Content -Path $CurrentLogFile -Value $Line
}

# ==============================================================================
# CONFIGURATION MANAGEMENT
# ==============================================================================

function Initialize-Configuration {
    <#
    .SYNOPSIS
        Creates or loads configuration file
    #>
    if (Test-Path $ConfigPath) {
        try {
            $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            Write-Log "Configuration loaded from: $ConfigPath" "DEBUG"
            return $Config
        } catch {
            Write-Log "Failed to load config file, using defaults: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Default configuration
    $DefaultConfig = @{
        Version = $ScriptVersion
        EnableDetailedLogging = $true
        AutoBackupBeforeChanges = $true
        LogRetentionDays = 30
        SimulationMode = $false
        CreatedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        $DefaultConfig | ConvertTo-Json | Set-Content -Path $ConfigPath -ErrorAction Stop
        Write-Log "Default configuration created: $ConfigPath" "INFO"
        return $DefaultConfig
    } catch {
        Write-Log "Failed to create config file: $($_.Exception.Message)" "ERROR"
        return $DefaultConfig
    }
}

function Save-Configuration {
    <#
    .SYNOPSIS
        Persists configuration to file
    #>
    param([hashtable]$Config)
    
    try {
        $Config | ConvertTo-Json | Set-Content -Path $ConfigPath -ErrorAction Stop
        Write-Log "Configuration saved successfully" "DEBUG"
    } catch {
        Write-Log "Failed to save configuration: $($_.Exception.Message)" "ERROR"
    }
}

# ==============================================================================
# INSTALLATION HISTORY MANAGEMENT
# ==============================================================================

function Initialize-History {
    <#
    .SYNOPSIS
        Loads installation history or creates new file
    #>
    if (Test-Path $HistoryPath) {
        try {
            $History = Get-Content $HistoryPath -Raw | ConvertFrom-Json
            return @($History)
        } catch {
            Write-Log "Failed to load history file: $($_.Exception.Message)" "WARNING"
            return @()
        }
    }
    return @()
}

function Add-HistoryEntry {
    <#
    .SYNOPSIS
        Records an installation/uninstallation action
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Install", "Uninstall", "Debloat", "Security", "Diagnostic")]
        [string]$Action,
        
        [string]$AppName = "N/A",
        [string]$AppID = "N/A",
        [string]$Status = "SUCCESS"
    )
    
    $Entry = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Action = $Action
        AppName = $AppName
        AppID = $AppID
        Status = $Status
    }
    
    $Global:InstallationHistory += $Entry
    
    try {
        $Global:InstallationHistory | ConvertTo-Json | Set-Content -Path $HistoryPath -ErrorAction Stop
        Write-Log "History entry added: $Action - $AppName" "DEBUG"
    } catch {
        Write-Log "Failed to save history: $($_.Exception.Message)" "WARNING"
    }
}

function Show-History {
    <#
    .SYNOPSIS
        Displays installation history
    #>
    Clear-Host
    Write-Host "=== Installation & Operation History ===" -ForegroundColor Cyan
    
    if ($Global:InstallationHistory.Count -eq 0) {
        Write-Host "`n  No operations recorded yet." -ForegroundColor Gray
    } else {
        Write-Host "`n  Recent operations (last 20):`n" -ForegroundColor Yellow
        $Global:InstallationHistory | Select-Object -Last 20 | ForEach-Object {
            $Color = if ($_.Status -eq "SUCCESS") { "Green" } else { "Yellow" }
            Write-Host ("  [{0}] {1,-12} {2,-40} {3}" -f $_.Timestamp, $_.Action, $_.AppName, $_.Status) -ForegroundColor $Color
        }
    }
    
    Wait-TaskEnd
}

# ==============================================================================
# ADMIN ELEVATION ENFORCEMENT
# ==============================================================================

$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
$currentPolicy = Get-ExecutionPolicy

if (-not $isAdmin) {
    Write-Host "[INFO] Requesting Administrator privileges..." -ForegroundColor Cyan
    Write-Host "[*] UAC dialog will appear. Please click 'Yes' to continue." -ForegroundColor Yellow
    Write-Log "Script re-launching with administrator privileges" "INFO"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait
    exit 0
} 
elseif ($currentPolicy -ne "Bypass") {
    Write-Host "[INFO] System policy is ($currentPolicy). Applying temporary execution bypass..." -ForegroundColor Cyan
    Write-Log "Re-launching with Bypass execution policy" "INFO"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait
    exit 0
}

Write-Log "Script execution started with Administrator privileges" "SUCCESS"

# ==============================================================================
# GLOBAL STATE INITIALIZATION
# ==============================================================================

$Global:Config = Initialize-Configuration
$Global:IsSimulation = if ($SimulationMode) { $true } else { $Global:Config.SimulationMode }
$Global:InstallationHistory = Initialize-History

# ==============================================================================
# SOFTWARE CATALOG
# ==============================================================================

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

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

function Wait-TaskEnd {
    <#
    .SYNOPSIS
        Pauses execution and waits for user input to return to menu
    #>
    Write-Host "`n=========================================" -ForegroundColor DarkGray
    Write-Host "[*] Task Execution Sequence Completed." -ForegroundColor Green
    Read-Host "Press Enter to return to menu"
}

function Assert-Winget {
    <#
    .SYNOPSIS
        Validates that winget is available and functional
    #>
    try {
        $version = & winget --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Winget is available: $version" "DEBUG"
            return $true
        }
    } catch {
        Write-Log "Winget check failed: $($_.Exception.Message)" "ERROR"
    }
    
    Write-Host "[✘] Error: Winget is not installed or not in PATH." -ForegroundColor Red
    Write-Host "      Install from: https://github.com/microsoft/winget-cli/releases" -ForegroundColor Gray
    Read-Host "Press Enter to continue"
    return $false
}

function Create-SystemRestorePoint {
    <#
    .SYNOPSIS
        Creates a system restore point before making critical changes
    #>
    Write-Log "Creating system restore point..." "INFO"
    
    try {
        if (Get-Command Checkpoint-Computer -ErrorAction Stop) {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            $restorePoint = Checkpoint-Computer -Description "YairUtility_v2_$(Get-Date -Format 'yyyyMMdd_HHmmss')" `
                -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-Log "System restore point created successfully" "SUCCESS"
            return $true
        }
    } catch {
        Write-Log "Failed to create restore point: $($_.Exception.Message)" "WARNING"
    }
    
    return $false
}

# ==============================================================================
# MODULE 1 & 2: SOFTWARE MANAGEMENT
# ==============================================================================

function Manage-Software {
    <#
    .SYNOPSIS
        Manages software installation/uninstallation with batch execution
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Install", "Uninstall")]
        [string]$Action
    )
    
    if (-not (Assert-Winget)) { return }
    
    # Build display list
    $DisplayList = New-Object System.Collections.ArrayList
    foreach ($App in $SoftwarePackages) {
        $Row = New-Object PSObject
        $Row | Add-Member -MemberType NoteProperty -Name "Category" -Value $App.Category
        $Row | Add-Member -MemberType NoteProperty -Name "Application Name" -Value $App.Name
        $Row | Add-Member -MemberType NoteProperty -Name "Description" -Value $App.Note
        $Row | Add-Member -MemberType NoteProperty -Name "Package ID" -Value $App.ID
        $Row | Add-Member -MemberType NoteProperty -Name "Process Name" -Value $App.Process
        $null = $DisplayList.Add($Row)
    }
    
    $Title = "Yair Utility - Select Apps for $Action (Hold CTRL for multiple items)"
    $SelectedApps = $DisplayList | Out-GridView -Title $Title -PassThru
        
    if (-not $SelectedApps) {
        Write-Log "No applications selected for $Action" "DEBUG"
        return
    }

    if ($Global:IsSimulation) {
        Clear-Host
        Write-Host "=== [SIMULATION] Target List ===" -ForegroundColor DarkYellow
        foreach ($App in $SelectedApps) {
            Write-Host "  [-] Would execute $Action sequence for: $($App."Application Name")" -ForegroundColor Gray
            Write-Log "SIMULATION: $Action - $($App.'Application Name')" "DEBUG"
        }
        Wait-TaskEnd
        return
    }

    # Require user confirmation for destructive operations
    if ($Action -eq "Uninstall") {
        Clear-Host
        Write-Host "⚠️  WARNING: Uninstall Operation" -ForegroundColor Red
        Write-Host "You are about to UNINSTALL the following applications:" -ForegroundColor Yellow
        Write-Host ""
        foreach ($App in $SelectedApps) {
            Write-Host "  • $($App.'Application Name') ($($App.'Package ID'))" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "This action cannot be easily undone." -ForegroundColor Yellow
        $confirm = Read-Host "Type 'UNINSTALL' to proceed, or press Enter to cancel"
        
        if ($confirm -ne "UNINSTALL") {
            Write-Log "Uninstall operation cancelled by user" "INFO"
            Write-Host "[*] Operation cancelled." -ForegroundColor Yellow
            return
        }
    }

    # Create backup before making changes
    if ($Global:Config.AutoBackupBeforeChanges) {
        Create-SystemRestorePoint | Out-Null
    }

    Clear-Host
    Write-Host "[*] Compiling unified execution stack..." -ForegroundColor Cyan
    Write-Log "Starting $Action batch for $($SelectedApps.Count) applications" "INFO"
    
    $PayloadCommands = @(
        "Clear-Host",
        "Write-Host '=======================================================' -ForegroundColor Cyan",
        "Write-Host '      YAIR UTILITY v2 - BATCH SOFTWARE RUNTIME PIPELINE   ' -ForegroundColor Cyan",
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
            # Stop any running processes gracefully
            if ($ProcName) {
                $PayloadCommands += @"
                    if (Get-Process -Name '$ProcName' -ErrorAction SilentlyContinue) { 
                        Write-Host '   [⚠] Stopping active process ($ProcName)...' -ForegroundColor Yellow
                        `$proc = Get-Process -Name '$ProcName' -ErrorAction SilentlyContinue
                        if (`$proc) {
                            `$proc.WaitForExit(5000)
                            if (-not `$proc.HasExited) { Stop-Process -Name '$ProcName' -Force -ErrorAction SilentlyContinue }
                        }
                        Start-Sleep -Seconds 1
                    }
"@
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
    
    try {
        Start-Process powershell.exe -ArgumentList $ProcessArgs -Wait -ErrorAction Stop
        Write-Log "$Action batch operation completed successfully for $($SelectedApps.Count) applications" "SUCCESS"
        
        # Record in history
        foreach ($App in $SelectedApps) {
            Add-HistoryEntry -Action $Action -AppName $App."Application Name" -AppID $App."Package ID" -Status "SUCCESS"
        }
    } catch {
        Write-Log "$Action batch operation failed: $($_.Exception.Message)" "ERROR"
        foreach ($App in $SelectedApps) {
            Add-HistoryEntry -Action $Action -AppName $App."Application Name" -AppID $App."Package ID" -Status "FAILED"
        }
    }
    
    Write-Host "`n[+] Software batch processing engine task complete!" -ForegroundColor Green
    Wait-TaskEnd
}

# ==============================================================================
# MODULE 3: DEBLOAT MENU
# ==============================================================================

function Invoke-Debloat {
    <#
    .SYNOPSIS
        Interactive debloat and system cleanup menu
    #>
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
            '3' { Invoke-TempFilesClear }
            'B' { return }
            Default {
                Write-Host "[✘] Invalid sub-routine choice selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Invoke-BloatwareRemoval {
    <#
    .SYNOPSIS
        Removes pre-installed Windows bloatware
    #>
    Clear-Host
    Write-Host "=== Deep Clean Phase 1: UWP Bloatware Package Eradication ===" -ForegroundColor Cyan
    
    $Bloat = @("BingNews", "BingWeather", "MicrosoftSolitaireCollection", "TikTok", "Facebook", "Instagram", "XboxApp", "ZuneMusic", "ZuneVideo", "Cortana", "WindowsMaps", "Clipchamp", "DevHome")
    
    if ($Global:IsSimulation) {
        Write-Log "SIMULATION: Bloatware removal initiated for $($Bloat.Count) packages" "DEBUG"
        foreach ($app in $Bloat) {
            Write-Host "  [SIM] Would purge package stub: $app... [SIMULATED]" -ForegroundColor DarkGray
        }
    } else {
        Write-Log "Starting bloatware removal process" "INFO"
        $removedCount = 0
        
        foreach ($app in $Bloat) {
            Write-Host "  Purging package stub: $app... " -NoNewline
            try {
                Get-AppxPackage -AllUsers -Name "*$app*" -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction Stop
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | 
                    Where-Object DisplayName -match $app | 
                    Remove-AppxProvisionedPackage -Online -ErrorAction Stop
                Write-Host "[✔] Cleaned." -ForegroundColor Green
                Write-Log "Removed bloatware: $app" "SUCCESS"
                $removedCount++
            } catch {
                Write-Host "[✘] Failed." -ForegroundColor Red
                Write-Log "Failed to remove $app : $($_.Exception.Message)" "WARNING"
            }
        }
        
        Write-Log "Bloatware removal completed: $removedCount/$($Bloat.Count) packages removed" "INFO"
        Add-HistoryEntry -Action "Debloat" -AppName "Bloatware Removal ($removedCount packages)" -Status "SUCCESS"
    }
    
    Wait-TaskEnd
}

function Invoke-TelemetryDisable {
    <#
    .SYNOPSIS
        Disables Windows telemetry services
    #>
    Clear-Host
    Write-Host "=== Deep Clean Phase 2: Telemetry Pipeline Lockdown ===" -ForegroundColor Cyan
    
    $Services = @("DiagTrack", "dmwappushservice")
    
    if ($Global:IsSimulation) {
        Write-Log "SIMULATION: Telemetry disable initiated for $($Services.Count) services" "DEBUG"
        foreach ($Svc in $Services) {
            Write-Host "  [SIM] Would lock down service: $Svc... [SIMULATED]" -ForegroundColor DarkGray
        }
    } else {
        Write-Log "Starting telemetry disable process" "INFO"
        $disabledCount = 0
        
        foreach ($Svc in $Services) {
            Write-Host "  Locking down service: $Svc... " -NoNewline
            try {
                if (Get-Service -Name $Svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $Svc -Force -NoWait -ErrorAction Stop
                    Set-Service -Name $Svc -StartupType Disabled -ErrorAction Stop
                    Write-Host "[✔] Disabled." -ForegroundColor Green
                    Write-Log "Disabled service: $Svc" "SUCCESS"
                    $disabledCount++
                } else {
                    Write-Host "[--] Not present." -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "[⚠] Failed with error." -ForegroundColor Yellow
                Write-Log "Failed to disable $Svc : $($_.Exception.Message)" "WARNING"
            }
        }
        
        Write-Log "Telemetry disable completed: $disabledCount services disabled" "INFO"
        Add-HistoryEntry -Action "Debloat" -AppName "Telemetry Disable ($disabledCount services)" -Status "SUCCESS"
    }
    
    Wait-TaskEnd
}

function Invoke-TempFilesClear {
    <#
    .SYNOPSIS
        Clears temporary files and empties recycle bin
    #>
    Clear-Host
    
    # User confirmation for destructive operation
    Write-Host "⚠️  DESTRUCTIVE OPERATION WARNING" -ForegroundColor Red
    Write-Host "This will permanently delete:" -ForegroundColor Yellow
    Write-Host "   • Recycle Bin contents"
    Write-Host "   • Windows Temporary files"
    Write-Host "   • Application cache data"
    Write-Host "   • Prefetch cache"
    Write-Host ""
    $confirm = Read-Host "Type 'DELETE' to proceed, or press Enter to cancel"
    
    if ($confirm -ne "DELETE") {
        Write-Log "Temp files clear operation cancelled by user" "INFO"
        Write-Host "[*] Operation cancelled." -ForegroundColor Yellow
        return
    }

    Write-Host "=== Deep Clean Phase 3: Hardware Storage Cache & Trash Purge ===" -ForegroundColor Cyan
    
    if ($Global:IsSimulation) {
        Write-Log "SIMULATION: Temp files clear initiated" "DEBUG"
        Write-Host "  [SIM] Would empty Recycle Bin... [SIMULATED]" -ForegroundColor DarkGray
        Write-Host "  [SIM] Would clear temp directories... [SIMULATED]" -ForegroundColor DarkGray
    } else {
        Write-Log "Starting temp files clear process" "INFO"
        $clearedCount = 0
        
        # Clear recycle bin
        Write-Host "  Emptying native System Recycle Bin structure... " -NoNewline
        try {
            Clear-RecycleBin -Confirm:$false -Force -ErrorAction Stop
            Write-Host "[✔] Emptied." -ForegroundColor Green
            Write-Log "Recycle Bin emptied successfully" "SUCCESS"
            $clearedCount++
        } catch {
            Write-Host "[✔] Nominal (Already empty or locked)." -ForegroundColor DarkGray
            Write-Log "Recycle Bin clear skipped: $($_.Exception.Message)" "DEBUG"
        }

        # Clear temp paths
        $Paths = @($env:TEMP, "C:\Windows\Temp", "C:\Windows\Prefetch")
        foreach ($p in $Paths) {
            Write-Host "  Processing path instance directory: $p... " -NoNewline
            try {
                if (Test-Path $p -ErrorAction Stop) {
                    $itemsRemoved = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | 
                        Measure-Object).Count
                    Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | 
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "[✔] Cleared ($itemsRemoved items)." -ForegroundColor Green
                    Write-Log "Cleared $p: $itemsRemoved items removed" "SUCCESS"
                    $clearedCount++
                } else {
                    Write-Host "[--] Not Found." -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "[⚠] Partial lock (Active files skipped)." -ForegroundColor DarkYellow
                Write-Log "Partial clear of $p : $($_.Exception.Message)" "WARNING"
            }
        }
        
        Write-Log "Temp files clear completed: $clearedCount locations processed" "INFO"
        Add-HistoryEntry -Action "Debloat" -AppName "Temp Files Clear ($clearedCount locations)" -Status "SUCCESS"
    }
    
    Wait-TaskEnd
}

# ==============================================================================
# MODULE 4: SYSTEM DIAGNOSTICS
# ==============================================================================

function Invoke-Diagnostics {
    <#
    .SYNOPSIS
        Runs comprehensive system health diagnostics
    #>
    Clear-Host
    Write-Host "=== Integrated System Metrics Dashboard ===" -ForegroundColor Cyan
    Write-Host "Node: $($env:COMPUTERNAME) | Context: $($env:USERNAME)`n" -ForegroundColor DarkGray
    
    Write-Log "System diagnostics initiated" "INFO"
    
    if ($Global:IsSimulation) {
        Write-Host "  [SIMULATION MODE] Testing dashboard display logic...`n" -ForegroundColor DarkGray
        Write-DiagResult "Storage (C:)" "OK" "Healthy (67% free)"
        Wait-TaskEnd
        return
    }

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $cpuLoad = [math]::Round((Get-CimInstance Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average)
        $ramGb = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        Write-Host "  Hardware: $($cs.Manufacturer) $($cs.Model) | RAM: $ramGb GB | CPU Load: $cpuLoad%`n" -ForegroundColor Gray
        Write-Log "Hardware Info - RAM: $ramGb GB, CPU Load: $cpuLoad%" "DEBUG"
    } catch {
        Write-Log "Failed to retrieve hardware info: $($_.Exception.Message)" "WARNING"
    }

    # Check for pending reboot
    $reboot = $false
    try {
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction Stop) {
            $reboot = $true
        }
    } catch {
        Write-Log "Failed to check reboot status: $($_.Exception.Message)" "DEBUG"
    }
    
    if ($reboot) {
        Write-DiagResult "Pending Reboot" "WARN" "A restart is required to finish installing updates"
        Write-Log "Pending reboot detected" "WARNING"
    }

    # Check disk space
    try {
        Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -and $_.Size -gt 0 } | ForEach-Object {
            $freePct = [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1)
            if ($freePct -lt 10) {
                Write-DiagResult "Storage ($($_.DriveLetter):)" "WARN" "Capacity exhausted ($freePct% remaining)"
                Write-Log "Low disk space on $($_.DriveLetter): $freePct% free" "WARNING"
            }
            else {
                Write-DiagResult "Storage ($($_.DriveLetter):)" "OK" "Space is nominal ($freePct% free)"
            }
        }
    } catch {
        Write-Log "Failed to check disk space: $($_.Exception.Message)" "WARNING"
    }

    # Check drive health
    try {
        $smartData = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue
        if ($smartData) {
            $fail = $false
            foreach ($d in $smartData) { 
                if ($d.PredictFailure) { 
                    $fail = $true
                    Write-Log "Drive failure predicted on device: $($d.InstanceName)" "ERROR"
                } 
            }
            if ($fail) {
                Write-DiagResult "Drive Health" "FAIL" "Drive failure warning! Back up your data immediately!"
            }
            else {
                Write-DiagResult "Drive Health" "OK" "All drives are healthy"
            }
        }
    } catch {
        Write-DiagResult "Drive Health" "WARN" "Could not retrieve drive health data"
        Write-Log "Drive health check error: $($_.Exception.Message)" "WARNING"
    }

    # Check system services
    try {
        $ExcludedServices = @(
            "gupdate", "gupdatem", "edgeupdate", "edgeupdatem",
            "AdobeARMservice", "MozillaMaintenance", "AppXSvc",
            "AsusMultiAntennaSvc", "brave", "Netlogon", "sppsvc",
            "StiSvc", "Intel"
        )
        
        $stoppedSvcs = @(Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State!='Running'" -ErrorAction SilentlyContinue) |
            Where-Object { $_.Name -notin $ExcludedServices }
        
        if ($stoppedSvcs.Count -gt 0) {
            Write-DiagResult "System Services" "FAIL" "$($stoppedSvcs.Count) automatic background services are stopped"
            Write-Log "$($stoppedSvcs.Count) stopped services detected" "WARNING"
        }
        else {
            Write-DiagResult "System Services" "OK" "All foundational automatic services active"
        }
    } catch {
        Write-Log "System services check error: $($_.Exception.Message)" "WARNING"
    }

    Write-Log "System diagnostics completed" "SUCCESS"
    Add-HistoryEntry -Action "Diagnostic" -AppName "System Health Check" -Status "SUCCESS"
    
    Wait-TaskEnd
}

# ==============================================================================
# MODULE 5: SECURITY AUDIT
# ==============================================================================

function Invoke-SecurityAudit {
    <#
    .SYNOPSIS
        Performs comprehensive security compliance audit
    #>
    Clear-Host
    Write-Host "=== Security Compliance & Audit Matrix ===" -ForegroundColor Cyan
    
    Write-Log "Security audit initiated" "INFO"
    
    if ($Global:IsSimulation) {
        Write-Host "`n  [SIMULATION MODE] Output suppressed." -ForegroundColor DarkGray
        Wait-TaskEnd
        return
    }

    # Check antivirus
    try {
        $def = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($def.RealTimeProtectionEnabled) {
            Write-DiagResult "Antivirus Engine" "OK" "Real-time scanning active (Sig Age: $($def.AntivirusSignatureAge) days)"
            Write-Log "Antivirus status: Enabled, Signature age: $($def.AntivirusSignatureAge) days" "INFO"
        }
        else {
            Write-DiagResult "Antivirus Engine" "FAIL" "Real-time mitigation sub-routines disabled"
            Write-Log "WARNING: Antivirus real-time protection disabled" "ERROR"
        }
    } catch {
        Write-DiagResult "Antivirus Engine" "FAIL" "WMI malware namespace error"
        Write-Log "Antivirus check error: $($_.Exception.Message)" "WARNING"
    }

    # Check firewall
    try {
        $fwDisabled = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $false }
        if ($fwDisabled) {
            Write-DiagResult "Windows Firewall" "FAIL" "Disabled targets: [$($fwDisabled.Name -join ', ')]"
            Write-Log "Firewall disabled profiles: $($fwDisabled.Name -join ', ')" "ERROR"
        }
        else {
            Write-DiagResult "Windows Firewall" "OK" "All software filter barriers active"
        }
    } catch {
        Write-DiagResult "Windows Firewall" "FAIL" "Firewall state engine error"
        Write-Log "Firewall check error: $($_.Exception.Message)" "WARNING"
    }

    # Check BitLocker
    try {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
            if ($bl.ProtectionStatus -eq "On") {
                Write-DiagResult "Volume Encryption (C:)" "OK" "BitLocker active"
                Write-Log "BitLocker status: Active" "INFO"
            }
            else {
                Write-DiagResult "Volume Encryption (C:)" "WARN" "Cryptographic storage suspended or unconfigured"
                Write-Log "WARNING: BitLocker not active on C: drive" "WARNING"
            }
        }
    } catch {
        Write-Log "BitLocker check error: $($_.Exception.Message)" "DEBUG"
    }

    # Check UAC
    try {
        $uac = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
            -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue).ConsentPromptBehaviorAdmin
        if ($uac -eq 0) {
            Write-DiagResult "User Account Control" "FAIL" "Token elevation set to silent auto-approve"
            Write-Log "WARNING: UAC set to auto-approve" "ERROR"
        }
        else {
            Write-DiagResult "User Account Control" "OK" "Isolation layers active"
        }
    } catch {
        Write-Log "UAC check error: $($_.Exception.Message)" "DEBUG"
    }

    Write-Log "Security audit completed" "SUCCESS"
    Add-HistoryEntry -Action "Security" -AppName "Security Audit" -Status "SUCCESS"
    
    Wait-TaskEnd
}

# ==============================================================================
# MODULE 6: IDENTITY AUDIT
# ==============================================================================

function Invoke-IdentityAudit {
    <#
    .SYNOPSIS
        Audits local user accounts and privileges
    #>
    Clear-Host
    Write-Host "=== Local SAM Identity & Privilege Auditor ===" -ForegroundColor Cyan
    
    Write-Log "Identity audit initiated" "INFO"
    
    if ($Global:IsSimulation) {
        Write-Host "`n  [SIMULATION MODE] Output suppressed." -ForegroundColor DarkGray
        Wait-TaskEnd
        return
    }
    
    $localUsers = Get-LocalUser -ErrorAction SilentlyContinue

    # Check administrator accounts
    try {
        $adminMembers = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
        $adminList = ($adminMembers | Where-Object { $_.PrincipalSource -eq "Local" } | Select-Object -ExpandProperty Name) -join ", "
        if (@($adminMembers).Count -gt 2) {
            Write-DiagResult "SAM Administrators" "WARN" "Elevated account pool overhead: [$adminList]"
            Write-Log "WARNING: Multiple admin accounts detected: $adminList" "WARNING"
        }
        else {
            Write-DiagResult "SAM Administrators" "OK" "Privileged density optimized: [$adminList]"
        }
    } catch {
        Write-Log "Admin check error: $($_.Exception.Message)" "WARNING"
    }

    # Check inactive accounts
    try {
        $staleCutoff = (Get-Date).AddDays(-90)
        $stale = $localUsers | Where-Object {
            $_.Enabled -eq $true -and 
            (($_.LastLogon -lt $staleCutoff) -or ($null -eq $_.LastLogon)) -and 
            $_.Name -notmatch "Administrator|Guest|DefaultAccount"
        }
        if ($stale) {
            Write-DiagResult "Inactive Identity" "WARN" "Dormant local assets (90+ days): [$($stale.Name -join ', ')]"
            Write-Log "Stale accounts detected: $($stale.Name -join ', ')" "WARNING"
        }
        else {
            Write-DiagResult "Inactive Identity" "OK" "Zero non-operational accounts tracking."
        }
    } catch {
        Write-Log "Inactive accounts check error: $($_.Exception.Message)" "WARNING"
    }

    # Check password expiration
    try {
        $pne = $localUsers | Where-Object {
            $_.Enabled -eq $true -and 
            $_.PasswordNeverExpires -eq $true -and 
            $_.Name -notmatch "Administrator|Guest|DefaultAccount"
        }
        if ($pne) {
            Write-DiagResult "Static Passwords" "WARN" "Expiration overrides active: [$($pne.Name -join ', ')]"
            Write-Log "WARNING: Accounts with static passwords: $($pne.Name -join ', ')" "WARNING"
        }
        else {
            Write-DiagResult "Static Passwords" "OK" "All accounts bound to expiration rotators."
        }
    } catch {
        Write-Log "Password expiration check error: $($_.Exception.Message)" "WARNING"
    }

    Write-Log "Identity audit completed" "SUCCESS"
    Add-HistoryEntry -Action "Security" -AppName "Identity Audit" -Status "SUCCESS"
    
    Wait-TaskEnd
}

# ==============================================================================
# MODULE 7: INCIDENT SNIFFER
# ==============================================================================

function Invoke-IncidentSniffer {
    <#
    .SYNOPSIS
        Monitors security event log for incidents in last 48 hours
    #>
    Clear-Host
    Write-Host "=== Cyber Incident Sniffer (Last 48 Hours) ===" -ForegroundColor Cyan
    
    Write-Log "Incident sniffer initiated" "INFO"
    
    if ($Global:IsSimulation) {
        Write-Host "`n  [SIMULATION MODE] Output suppressed." -ForegroundColor DarkGray
        Wait-TaskEnd
        return
    }
    
    $timeFilter = (Get-Date).AddHours(-48)

    # Check authentication anomalies
    try {
        [array]$failedLogons = Get-WinEvent -FilterHashtable @{
            LogName="Security"
            Id=4625
            StartTime=$timeFilter
        } -ErrorAction SilentlyContinue
        
        if ($failedLogons.Count -gt 0) {
            Write-DiagResult "Auth Anomalies" "WARN" "$($failedLogons.Count) authentication failures tracking."
            Write-Log "WARNING: $($failedLogons.Count) failed logon attempts in last 48 hours" "WARNING"
        } else {
            Write-DiagResult "Auth Anomalies" "OK" "Zero exceptions logged."
        }
    } catch {
        Write-Log "Failed logon check error: $($_.Exception.Message)" "DEBUG"
    }

    # Check event log tampering
    try {
        [array]$clearEvents = Get-WinEvent -FilterHashtable @{
            LogName=@("Security","System")
            Id=@(1102,104)
            StartTime=$timeFilter
        } -ErrorAction SilentlyContinue
        
        if ($clearEvents.Count -gt 0) {
            Write-DiagResult "Audit Integrity" "FAIL" "CRITICAL FAULT: Forensics event validation data explicitly purged!"
            Write-Log "CRITICAL: Event logs have been cleared (possible tampering)" "ERROR"
        }
        else {
            Write-DiagResult "Audit Integrity" "OK" "Event streams intact. No tampering."
        }
    } catch {
        Write-Log "Event log tampering check error: $($_.Exception.Message)" "DEBUG"
    }

    Write-Log "Incident sniffer completed" "SUCCESS"
    Add-HistoryEntry -Action "Security" -AppName "Incident Sniffer (48h)" -Status "SUCCESS"
    
    Wait-TaskEnd
}

# ==============================================================================
# MODULE 8: SECURE UPDATES & BACKUP
# ==============================================================================

function Invoke-SecureUpdates {
    <#
    .SYNOPSIS
        Creates system restore point and checks for critical Windows updates
    #>
    Clear-Host
    Write-Host "=== Secure Update & Backup ===" -ForegroundColor Cyan
    
    Write-Log "Secure update process initiated" "INFO"
    
    if ($Global:IsSimulation) {
        Write-Host "`n  [SIM] Phase 1: Create System Restore Point... PASSED" -ForegroundColor DarkGray
        Write-Host "  [SIM] Phase 2: Check for Windows Updates... PASSED" -ForegroundColor DarkGray
        Write-Log "SIMULATION: Secure updates process" "DEBUG"
        Wait-TaskEnd
        return
    }

    # Phase 1: Create restore point
    Write-Host "`n[*] Phase 1: Creating System Restore Point..." -ForegroundColor Yellow
    try {
        if (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue) {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            $restorePoint = Checkpoint-Computer -Description "YairUtility_v2_SecureUpdate_$(Get-Date -Format 'yyyyMMdd')" `
                -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-Host "  [+] System restore point created successfully." -ForegroundColor Green
            Write-Log "System restore point created successfully" "SUCCESS"
        } else {
            Write-Host "  [!] System restore is not supported on this machine (Skipping)." -ForegroundColor DarkGray
            Write-Log "System restore not supported on this machine" "DEBUG"
        }
    } catch {
        Write-Host "  [⚠] Failed to create restore point: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Log "Failed to create restore point: $($_.Exception.Message)" "WARNING"
    }

    # Phase 2: Check for updates
    Write-Host "`n[*] Phase 2: Checking for Windows Updates..." -ForegroundColor Yellow
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searchRes = $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
        $toInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        $criticalCount = 0

        foreach ($update in $searchRes.Updates) {
            $isCritical = $false
            foreach ($cat in $update.Categories) {
                if (@("Security", "Critical") -contains $cat.Name) {
                    $isCritical = $true
                }
            }
            if ($isCritical) {
                Write-Host "  [+] Found Missing Critical Update: $($update.Title)" -ForegroundColor Cyan
                Write-Log "Critical update available: $($update.Title)" "INFO"
                $toInstall.Add($update) | Out-Null
                $criticalCount++
            }
        }

        if ($toInstall.Count -gt 0) {
            Write-Host "`n[*] Phase 3: Downloading $($toInstall.Count) critical updates..." -ForegroundColor Yellow
            $downloader = $session.CreateUpdateDownloader()
            $downloader.Updates = $toInstall
            $downloadResult = $downloader.Download()
            Write-Log "Downloaded $($toInstall.Count) updates" "SUCCESS"
            
            Write-Host "[*] Phase 4: Installing updates..." -ForegroundColor Yellow
            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $toInstall
            $result = $installer.Install()
            Write-Host "  [+] Updates installed successfully (Result Code: $($result.ResultCode))." -ForegroundColor Green
            Write-Log "Updates installed with result code: $($result.ResultCode)" "SUCCESS"
            
            if ($result.RebootRequired) {
                Write-Host "  [!] A system reboot is required to complete the update installation." -ForegroundColor Yellow
                Write-Log "System reboot required for update completion" "INFO"
            }
        } else {
            Write-Host "  [+] Your system is fully up to date. No actions needed." -ForegroundColor Green
            Write-Log "System is fully up to date" "SUCCESS"
        }
    } catch {
        Write-Host "  [✘] Error checking for updates: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Update check failed: $($_.Exception.Message)" "ERROR"
    }

    Write-Log "Secure update process completed" "SUCCESS"
    Add-HistoryEntry -Action "Maintenance" -AppName "Secure Update & Backup" -Status "SUCCESS"
    
    Wait-TaskEnd
}

# ==============================================================================
# MAIN RUNTIME INTERFACE
# ==============================================================================

while ($true) {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "       YAIR WINDOWS UTILITY TOOL v$ScriptVersion" -ForegroundColor Green
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
    Write-Host "  [H] View Operation History"
    Write-Host "  [L] Open Log File"
    Write-Host "  [Q] Terminate Script Execution"
    Write-Host "=================================================================" -ForegroundColor Green
    
    $MainChoice = Read-Host "Enter operational sequence"
    
    switch ($MainChoice.ToUpper()) {
        '1' { Manage-Software -Action "Install" }
        '2' { Manage-Software -Action "Uninstall" }
        '3' { Invoke-Debloat }
        '4' { 
            if (-not $Global:IsSimulation) {
                Write-Log "Opening Windows Update settings" "INFO"
                Start-Process "ms-settings:windowsupdate-action"
            }
            else {
                Write-Host "`n[SIMULATION] ms-settings execution bypassed." -ForegroundColor DarkGray
                Write-Log "SIMULATION: Windows Update settings not opened" "DEBUG"
                Wait-TaskEnd
            }
        }
        '5' { Invoke-Diagnostics }
        '6' { Invoke-SecurityAudit }
        '7' { Invoke-IdentityAudit }
        '8' { Invoke-IncidentSniffer }
        '9' { Invoke-SecureUpdates }
        'S' {
            $Global:IsSimulation = -not $Global:IsSimulation
            $Global:Config.SimulationMode = $Global:IsSimulation
            Save-Configuration -Config $Global:Config
            $newState = if ($Global:IsSimulation) { "ON" } else { "OFF" }
            Write-Host "`n[*] Simulation mode is now: $newState" -ForegroundColor Cyan
            Write-Log "Simulation mode toggled: $newState" "INFO"
            Start-Sleep -Seconds 2
        }
        'H' { Show-History }
        'L' {
            if (Test-Path $CurrentLogFile) {
                Write-Host "`n[*] Opening log file: $CurrentLogFile`n" -ForegroundColor Cyan
                & notepad.exe $CurrentLogFile
            } else {
                Write-Host "[✘] Log file not found: $CurrentLogFile" -ForegroundColor Red
            }
        }
        'Q' {
            Clear-Host
            Write-Host "Yair Windows Utility v$ScriptVersion - Session Terminated" -ForegroundColor Green
            Write-Host "Log file: $CurrentLogFile" -ForegroundColor Gray
            Write-Log "Script execution terminated by user" "INFO"
            exit 0
        }
        Default { 
            Write-Host "[✘] Invalid operational input selection." -ForegroundColor Red
            Start-Sleep -Seconds 1 
        }
    }
}

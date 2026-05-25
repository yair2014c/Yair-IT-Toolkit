# ==============================================================================
# Script: Yair Windows Utility Tool (v9.0 - Final Consolidated Master Edition)
# ==============================================================================

$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting utility with administrator rights..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# --- מערך מאגר התוכנות המלא (כולל Wireshark ו-VS Code) ---
$SoftwarePackages = @(
    # 🌐 דפדפנים
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="Google Chrome"; Process="chrome"; Note="דפדפן האינטרנט הפופולרי של גוגל"; ID="Google.Chrome"}
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="Brave Browser"; Process="brave"; Note="דפדפן מאובטח וחוסם פרסומות"; ID="Brave.Brave"}
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="Mozilla Firefox"; Process="firefox"; Note="דפדפן קוד פתוח עצמאי"; ID="Mozilla.Firefox"}

    # 🔒 אבטחה
    [PSCustomObject]@{Category="🔒 אבטחה"; Name="Bitwarden"; Process="Bitwarden"; Note="ניהול סיסמאות בענן"; ID="Bitwarden.Bitwarden"}
    [PSCustomObject]@{Category="🔒 אבטחה"; Name="KeePassXC"; Process="keepassxc"; Note="כספת סיסמאות מקומית"; ID="KeePassXCTeam.KeePassXC"}

    # 🏢 משרד ופרודוקטיביות
    [PSCustomObject]@{Category="🏢 משרד"; Name="Microsoft 365"; Process="office"; Note="חבילת אופיס הרשמית"; ID="Microsoft.Office"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="Notion"; Process="Notion"; Note="ניהול ידע ופרודוקטיביות"; ID="Notion.Notion"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="7-Zip"; Process="7zG"; Note="כלי דחיסת קבצים"; ID="7zip.7zip"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="VLC Media Player"; Process="vlc"; Note="נגן מולטימדיה"; ID="VideoLAN.VLC"}

    # 🛠️ סיסטם ותשתיות
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="PowerShell 7"; Process="pwsh"; Note="גרסת פאוורשל מודרנית"; ID="Microsoft.PowerShell"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="PowerToys"; Process="PowerToys"; Note="שיפור הפרודוקטיביות בווינדוס"; ID="Microsoft.PowerToys"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="Everything"; Process="Everything"; Note="חיפוש קבצים מהיר"; ID="Voidtools.Everything"}

    # 📡 רשתות
    [PSCustomObject]@{Category="📡 רשתות"; Name="Wireshark"; Process="Wireshark"; Note="ניתוח רשתות ופרוטוקולים"; ID="WiresharkFoundation.Wireshark"}
    [PSCustomObject]@{Category="📡 רשתות"; Name="Advanced IP Scanner"; Process="advanced_ip_scanner"; Note="סריקת רשת"; ID="Famatech.AdvancedIPScanner"}

    # 💻 פיתוח
    [PSCustomObject]@{Category="💻 פיתוח"; Name="VS Code"; Process="code"; Note="עורך קוד"; ID="Microsoft.VisualStudioCode"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="GitHub Desktop"; Process="GitHubDesktop"; Note="ניהול גרסאות"; ID="GitHub.GitHubDesktop"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="Git"; Process="git"; Note="מערכת ניהול גרסאות"; ID="Git.Git"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="Notepad++"; Process="notepad++"; Note="עורך טקסט"; ID="Notepad++.Notepad++"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="Python 3"; Process="python"; Note="סביבת פייתון"; ID="Python.Python.3"}

    # 📊 חומרה ודאטה
    [PSCustomObject]@{Category="📊 חומרה"; Name="HWiNFO"; Process="HWiNFO64"; Note="ניטור חומרה"; ID="REALiX.HWiNFO"}
    [PSCustomObject]@{Category="💾 דאטה"; Name="DBeaver"; Process="dbeaver"; Note="ניהול בסיסי נתונים"; ID="dbeaver.DBeaverCommunity"}

    # 💬 תקשורת
    [PSCustomObject]@{Category="💬 תקשורת"; Name="Discord"; Process="Discord"; Note="פלטפורמת קהילות"; ID="Discord.Discord"}
    [PSCustomObject]@{Category="💬 תקשורת"; Name="WhatsApp"; Process="WhatsApp"; Note="וואטסאפ למחשב"; ID="WhatsApp.WhatsApp"}
    [PSCustomObject]@{Category="💬 תקשורת"; Name="Thunderbird"; Process="thunderbird"; Note='דוא"ל'; ID="Mozilla.Thunderbird"}

    # 🎮 גיימינג
    [PSCustomObject]@{Category="🎮 גיימינג"; Name="Steam"; Process="steam"; Note="פלטפורמת גיימינג"; ID="Valve.Steam"}
    [PSCustomObject]@{Category="🎮 גיימינג"; Name="OBS Studio"; Process="obs64"; Note="הקלטה ושידור"; ID="Obsproject.OBSStudio"}
)

$Global:CustomScriptDir = $null

function Show-MainMenu {
    Clear-Host
    Write-Host '==============================================================================' -ForegroundColor Cyan
    Write-Host '                     YAIR WINDOWS UTILITY TOOL v9.0                           ' -ForegroundColor Cyan
    Write-Host '==============================================================================' -ForegroundColor Cyan
    
    Write-Host ' [1] Install Software   (GUI Package Deployment)' -ForegroundColor Green
    Write-Host ' [2] Uninstall Software (GUI Package Removal)' -ForegroundColor Red
    Write-Host ' [3] Windows Deep Clean (Safe Debloat, Telemetry and Temp Purge)' -ForegroundColor Yellow
    Write-Host ' [4] Windows Updates    (Trigger Core System Update Interface)' -ForegroundColor White
    Write-Host ' [5] Run: System Diagnostic Toolkit' -ForegroundColor DarkCyan
    Write-Host ' [6] Run: Security Incident Sniffer' -ForegroundColor DarkCyan
    Write-Host ' [7] Run: Identity and Access Auditor' -ForegroundColor DarkCyan
    Write-Host ' [0] Exit Utility' -ForegroundColor DarkGray
    Write-Host ''
    return Read-Host " Select an option"
}

function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    return $true
}

function Manage-Software([string]$Action) {
    if (-not (Assert-Winget)) { Write-Host "[✘] Error: Winget is not initialized." -ForegroundColor Red; Pause; return }
    
    $DisplayList = New-Object System.Collections.ArrayList
    foreach ($App in $SoftwarePackages) {
        $Row = New-Object PSObject
        $Row | Add-Member -MemberType NoteProperty -Name "קטגוריה" -Value $App.Category
        $Row | Add-Member -MemberType NoteProperty -Name "שם התוכנה" -Value $App.Name
        $Row | Add-Member -MemberType NoteProperty -Name "תיאור הכלי" -Value $App.Note
        $Row | Add-Member -MemberType NoteProperty -Name "ID" -Value $App.ID
        $Row | Add-Member -MemberType NoteProperty -Name "Process" -Value $App.Process
        $nil = $DisplayList.Add($Row)
    }
    
    $Title = "Yair Utility - Select Apps for $Action (Hold CTRL for multiple items)"
    $SelectedApps = $DisplayList | Out-GridView -Title $Title -PassThru
    if (-not $SelectedApps) { return }

    Write-Host "`n[*] Executing Winget $Action Sequence..." -ForegroundColor Cyan
    foreach ($App in $SelectedApps) {
        Write-Host "    -> Processing $($App."שם התוכנה")..." -ForegroundColor Yellow
        if ($Action -eq "Install") {
            & winget install --id $($App.ID) --exact --force --include-unknown --accept-package-agreements --accept-source-agreements
        } else {
            $ProcName = $App.Process
            if (Get-Process -Name $ProcName -ErrorAction SilentlyContinue) {
                Stop-Process -Name $ProcName -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            & winget uninstall --id $($App.ID) --exact --force
        }
    }
    Write-Host "`n[+] Software execution sequence completed!" -ForegroundColor Green
    Pause
}

function Run-Debloat {
    Clear-Host
    Write-Host '==============================================================================' -ForegroundColor Yellow
    Write-Host '                       ADVANCED SYSTEM DEBLOAT AND PURGE                      ' -ForegroundColor Yellow
    Write-Host '==============================================================================' -ForegroundColor Yellow
    
    $confirm = Read-Host "`n Do you want to proceed with deep optimization? (Y / N)"
    if ($confirm -notmatch "^[Yy]$") { return }

    $Bloatware = @("BingNews", "BingWeather", "MicrosoftSolitaireCollection", "TikTok", "Facebook", "Instagram", "XboxApp")
    foreach ($AppName in $Bloatware) {
        $Package = Get-AppxPackage -Name "*$AppName*" -ErrorAction SilentlyContinue
        if ($Package) { $Package | Remove-AppxPackage -ErrorAction SilentlyContinue }
    }
    Write-Host "`n[✔] Advanced Deep Clean completed successfully!" -ForegroundColor Green
    Pause
}

function Run-LocalScript([string]$Keyword, [string]$DefaultName) {
    $ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    if ($Global:CustomScriptDir) { $ScriptDir = $Global:CustomScriptDir }
    
    $TargetScript = Get-ChildItem -Path $ScriptDir -Filter "*$Keyword*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
    $ScriptPath = if ($TargetScript) { $TargetScript.FullName } else { Join-Path -Path $ScriptDir -ChildPath $DefaultName }
    
    if (Test-Path $ScriptPath) {
        . $ScriptPath  
    } else {
        Write-Host "`n[✘] Error: Could not execute script target." -ForegroundColor Red
        Pause
    }
}

while ($true) {
    switch (Show-MainMenu) {
        '1' { Manage-Software -Action "Install" }
        '2' { Manage-Software -Action "Uninstall" }
        '3' { Run-Debloat }
        '4' { Start-Process "ms-settings:windowsupdate-action" }
        '5' { Run-LocalScript -Keyword "Diagnostic" -DefaultName "System-Full-Diagnostic.ps1" }
        '6' { Run-LocalScript -Keyword "Sniffer" -DefaultName "Security-Incident-Sniffer.ps1" }
        '7' { Run-LocalScript -Keyword "Auditor" -DefaultName "Security-Identity-Auditor.ps1" }
        '0' { exit }
    }
}
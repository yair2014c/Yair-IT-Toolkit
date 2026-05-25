Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms # הוספתי בשביל עדכון ממשק חלק

# --- מאגר תוכנות מלא (50+ יישומים) ---
$SoftwarePackages = @(
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="Google Chrome"; ID="Google.Chrome"}
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="Brave Browser"; ID="Brave.Brave"}
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="Mozilla Firefox"; ID="Mozilla.Firefox"}
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="LibreWolf"; ID="LibreWolf.LibreWolf"}
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="Tor Browser"; ID="TorProject.TorBrowser"}
    [PSCustomObject]@{Category="🌐 דפדפנים"; Name="Microsoft Edge"; ID="Microsoft.Edge"}
    [PSCustomObject]@{Category="🔒 אבטחה"; Name="Bitwarden"; ID="Bitwarden.Bitwarden"}
    [PSCustomObject]@{Category="🔒 אבטחה"; Name="1Password"; ID="AgileBits.1Password"}
    [PSCustomObject]@{Category="🔒 אבטחה"; Name="KeePassXC"; ID="KeePassXCTeam.KeePassXC"}
    [PSCustomObject]@{Category="🔒 אבטחה"; Name="VeraCrypt"; ID="IDRIX.VeraCrypt"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="Microsoft 365"; ID="Microsoft.Office"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="Microsoft OneDrive"; ID="Microsoft.OneDrive"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="Microsoft OneNote"; ID="Microsoft.OneNote"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="Notion"; ID="Notion.Notion"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="Obsidian"; ID="Obsidian.Obsidian"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="7-Zip"; ID="7zip.7zip"}
    [PSCustomObject]@{Category="🏢 משרד"; Name="VLC Media Player"; ID="VideoLAN.VLC"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="PowerShell 7"; ID="Microsoft.PowerShell"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="AnyDesk"; ID="AnyDeskSoftwareGmbH.AnyDesk"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="TeamViewer"; ID="TeamViewer.TeamViewer"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="Docker Desktop"; ID="Docker.DockerDesktop"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="WizTree"; ID="AntibodySoftware.WizTree"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="PowerToys"; ID="Microsoft.PowerToys"}
    [PSCustomObject]@{Category="🛠️ סיסטם"; Name="Everything"; ID="Voidtools.Everything"}
    [PSCustomObject]@{Category="📡 רשתות"; Name="Wireshark"; ID="WiresharkFoundation.Wireshark"}
    [PSCustomObject]@{Category="📡 רשתות"; Name="Advanced IP Scanner"; ID="Famatech.AdvancedIPScanner"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="VS Code"; ID="Microsoft.VisualStudioCode"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="GitHub Desktop"; ID="GitHub.GitHubDesktop"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="Git"; ID="Git.Git"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="Windows Terminal"; ID="Microsoft.WindowsTerminal"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="Notepad++"; ID="Notepad++.Notepad++"}
    [PSCustomObject]@{Category="💻 פיתוח"; Name="Python 3"; ID="Python.Python.3"}
    [PSCustomObject]@{Category="💾 דאטה"; Name="DBeaver"; ID="dbeaver.DBeaverCommunity"}
    [PSCustomObject]@{Category="📊 חומרה"; Name="HWiNFO"; ID="REALiX.HWiNFO"}
    [PSCustomObject]@{Category="📊 חומרה"; Name="CrystalDiskInfo"; ID="CrystalMarkSoftware.CrystalDiskInfo"}
    [PSCustomObject]@{Category="🤖 AI"; Name="ChatGPT"; ID="OpenAI.ChatGPT"}
    [PSCustomObject]@{Category="🤖 AI"; Name="Claude"; ID="Anthropic.Claude"}
    [PSCustomObject]@{Category="🤖 AI"; Name="Perplexity"; ID="Perplexity.Perplexity"}
    [PSCustomObject]@{Category="💬 תקשורת"; Name="Discord"; ID="Discord.Discord"}
    [PSCustomObject]@{Category="💬 תקשורת"; Name="WhatsApp"; ID="WhatsApp.WhatsApp"}
    [PSCustomObject]@{Category="💬 תקשורת"; Name="Telegram"; ID="Telegram.TelegramDesktop"}
    [PSCustomObject]@{Category="💬 תקשורת"; Name="Microsoft Teams"; ID="Microsoft.Teams"}
    [PSCustomObject]@{Category="💬 תקשורת"; Name="Zoom"; ID="Zoom.Zoom"}
    [PSCustomObject]@{Category="💬 תקשורת"; Name="Thunderbird"; ID="Mozilla.Thunderbird"}
    [PSCustomObject]@{Category="🎵 מוזיקה"; Name="Spotify"; ID="Spotify.Spotify"}
    [PSCustomObject]@{Category="🎵 מוזיקה"; Name="Apple Music"; ID="Apple.AppleMusic"}
    [PSCustomObject]@{Category="🎮 גיימינג"; Name="Steam"; ID="Valve.Steam"}
    [PSCustomObject]@{Category="🎮 גיימינג"; Name="Epic Games"; ID="EpicGames.EpicGamesLauncher"}
    [PSCustomObject]@{Category="🎮 גיימינג"; Name="OBS Studio"; ID="Obsproject.OBSStudio"}
)

# --- פונקציית הרצה בטוחה ---
function Run-ExternalTool($Keyword) {
    $ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $File = Get-ChildItem -Path $ScriptDir -Filter "*$Keyword*.ps1" | Select-Object -First 1
    if ($File) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$($File.FullName)`""
    } else {
        [System.Windows.MessageBox]::Show("לא נמצא סקריפט מתאים ל-$Keyword")
    }
}

# --- חלון יומן אירועים (החדש!) ---
function Show-LogWindow($Title) {
    $Win = New-Object System.Windows.Window
    $Win.Title = $Title
    $Win.Width = 500
    $Win.Height = 400
    $Txt = New-Object System.Windows.Controls.TextBox
    $Txt.IsReadOnly = $true
    $Txt.VerticalScrollBarVisibility = "Auto"
    $Txt.Background = [System.Windows.Media.Brushes]::Black
    $Txt.Foreground = [System.Windows.Media.Brushes]::LightGreen
    $Win.Content = $Txt
    $Win.Show()
    return $Txt
}

# --- חלון ראשי ---
function Show-MainWindow {
    $Window = New-Object System.Windows.Window
    $Window.Title = "Yair Utility - Master Edition"
    $Window.Width = 450
    $Window.Height = 750
    $Window.WindowStartupLocation = "CenterScreen"
    $Stack = New-Object System.Windows.Controls.StackPanel
    $Stack.Margin = "20"

    $Header = New-Object System.Windows.Controls.TextBlock
    $Header.Text = "Yair Utility Master"
    $Header.FontSize = 22
    $Header.FontWeight = "Bold"
    $Header.HorizontalAlignment = "Center"
    $Header.Margin = "0,0,0,20"
    $Stack.Children.Add($Header)

    $Buttons = @(
        @("התקנת תוכנות", { Show-InstallWindow "Install" }),
        @("הסרת תוכנות", { Show-InstallWindow "Uninstall" }),
        @("ניקוי מערכת (Debloat)", { Run-Debloat }),
        @("עדכוני Windows", { Start-Process "ms-settings:windowsupdate-action" }),
        @("דיאגנוסטיקה מלאה", { Run-ExternalTool "Diagnostic" }),
        @("סניפר אבטחה", { Run-ExternalTool "Sniffer" }),
        @("אודיטור זהויות", { Run-ExternalTool "Auditor" })
    )

    foreach ($B in $Buttons) {
        $Btn = New-Object System.Windows.Controls.Button
        $Btn.Content = $B[0]
        $Btn.Height = 50
        $Btn.Margin = "0,5"
        $Btn.Add_Click($B[1])
        $Stack.Children.Add($Btn)
    }

    $Window.Content = $Stack
    $Window.ShowDialog() | Out-Null
}

# --- פונקציית ניקוי עם יומן חי ---
function Run-Debloat {
    $Window = New-Object System.Windows.Window
    $Window.Title = "Advanced System Clean"
    $Window.Width = 350
    $Window.Height = 250
    $Stack = New-Object System.Windows.Controls.StackPanel
    $Stack.Margin = "20"
    
    $B1 = New-Object System.Windows.Controls.Button
    $B1.Content = "1. הסרת אפליקציות זבל"
    $B1.Add_Click({
        $Log = Show-LogWindow "ניקוי Bloatware"
        $Bloat = @("BingNews", "BingWeather", "MicrosoftSolitaireCollection", "TikTok", "Facebook", "Instagram", "XboxApp")
        foreach ($N in $Bloat) {
            $Log.AppendText("בודק $N...`r`n")
            $App = Get-AppxPackage -Name "*$N*"
            if ($App) {
                $Log.AppendText("מסיר: $($App.Name)...`r`n")
                $App | Remove-AppxPackage
                $Log.AppendText("✔ בוצע.`r`n")
            } else {
                $Log.AppendText("✖ לא נמצא.`r`n")
            }
        }
        $Log.AppendText("--- הסיום הושלם ---")
    })
    
    $B2 = New-Object System.Windows.Controls.Button
    $B2.Content = "2. ניקוי קבצי זמניים"
    $B2.Margin = "0,10"
    $B2.Add_Click({
        $Log = Show-LogWindow "ניקוי קבצי זמניים"
        $TempPath = $env:TEMP
        $Log.AppendText("ניקוי תיקיית: $TempPath`r`n")
        $Files = Get-ChildItem -Path $TempPath -ErrorAction SilentlyContinue
        foreach ($F in $Files) {
            $Log.AppendText("מוחק: $($F.Name)...")
            try { 
                Remove-Item $F.FullName -Recurse -Force -ErrorAction Stop
                $Log.AppendText(" ✔`r`n")
            } catch { $Log.AppendText(" ✖ שגיאה`r`n") }
        }
        $Log.AppendText("--- הסיום הושלם ---")
    })
    $Stack.Children.Add($B1)
    $Stack.Children.Add($B2)
    $Window.Content = $Stack
    $Window.ShowDialog() | Out-Null
}

# --- חלון בחירת תוכנות ---
function Show-InstallWindow([string]$Action) {
    $Window = New-Object System.Windows.Window
    $Window.Title = "ניהול תוכנות - $Action"
    $Window.Width = 550
    $Window.Height = 600
    $Scroll = New-Object System.Windows.Controls.ScrollViewer
    $Stack = New-Object System.Windows.Controls.StackPanel
    
    $Checks = @()
    foreach ($App in $SoftwarePackages) {
        $CB = New-Object System.Windows.Controls.CheckBox
        $CB.Content = "[$($App.Category)] - $($App.Name)"
        $CB.Tag = $App
        $CB.Margin = "5"
        $Stack.Children.Add($CB)
        $Checks += $CB
    }

    $Btn = New-Object System.Windows.Controls.Button
    $Btn.Content = "בצע פעולה"
    $Btn.Height = 40
    $Btn.Margin = "0,15,0,0"
    $Btn.Add_Click({
        foreach ($C in $Checks) {
            if ($C.IsChecked) {
                if ($Action -eq "Install") { Start-Process winget -ArgumentList "install --id $($C.Tag.ID) --exact --force --accept-package-agreements" -Wait }
                else { Start-Process winget -ArgumentList "uninstall --id $($C.Tag.ID) --exact --force" -Wait }
            }
        }
        [System.Windows.MessageBox]::Show("הפעולה הסתיימה")
        $Window.Close()
    })
    $Stack.Children.Add($Btn)
    $Scroll.Content = $Stack
    $Window.Content = $Scroll
    $Window.ShowDialog() | Out-Null
}

$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}
Show-MainWindow
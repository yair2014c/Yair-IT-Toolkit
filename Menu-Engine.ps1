# Establish strict root execution context
if (-not $PSScriptRoot) {
    $RootPath = (Get-Location).Path
} else {
    $RootPath = $PSScriptRoot
}
Set-Location -Path $RootPath

function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "        YAIR AUTOMATION MENU              " -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "[1] Network Scripts" -ForegroundColor Yellow
        Write-Host "[2] Security Scripts" -ForegroundColor Yellow
        Write-Host "[3] Windows Scripts" -ForegroundColor Yellow
        Write-Host "[4] Windows Utility Tool" -ForegroundColor Yellow
        Write-Host "[Q] Exit Console" -ForegroundColor Red
        Write-Host "==========================================" -ForegroundColor Cyan
        
        $Choice = Read-Host "Select a category number"
        switch ($Choice) {
            '1' { Show-SubMenu "Network-Scripts" }
            '2' { Show-SubMenu "Security-Scripts" }
            '3' { Show-SubMenu "Windows-Scripts" }
            '4' { Show-SubMenu "Windows-Utility-Tool" }
            'q' { Clear-Host; exit }
            'Q' { Clear-Host; exit }
            Default { 
                Write-Host "Invalid choice. Try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Show-SubMenu ($FolderName) {
    $TargetFolder = Join-Path $RootPath $FolderName
    
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  CATEGORY: $FolderName" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        
        if ($TargetFolder -and (Test-Path $TargetFolder)) {
            $Scripts = Get-ChildItem -Path $TargetFolder -Filter *.ps1 | Where-Object {
                $_.Name -notlike "Untitled*" -and 
                $_.Name -notlike "README*" -and
                $_.Name -ne "menu-engine.ps1"
            }
        } else {
            $Scripts = @()
        }
        
        if ($Scripts.Count -eq 0) {
            Write-Host "No functional scripts found in this directory:" -ForegroundColor Red
            Write-Host "$TargetFolder" -ForegroundColor Yellow
            Read-Host "`nPress Enter to return to Main Menu..."
            break
        }
        
        for ($i = 0; $i -lt $Scripts.Count; $i++) {
            Write-Host ("[{0}] {1}" -f ($i + 1), $Scripts[$i].BaseName) -ForegroundColor Yellow
        }
        Write-Host "[B] Back to Main Menu" -ForegroundColor Red
        Write-Host "==========================================" -ForegroundColor Cyan
        
        $Selection = Read-Host "Select a script option"
        if ($Selection -eq 'b' -or $Selection -eq 'B') { break }
        
        if ($Selection -match '^\d+$') {
            $Index = [int]$Selection
            if ($Index -gt 0 -and $Index -le $Scripts.Count) {
                $ScriptToRun = $Scripts[$Index - 1].FullName
                Write-Host "`n[!] Running: $($Scripts[$Index - 1].Name)...`n" -ForegroundColor Green
                
                try {
                    & $ScriptToRun
                } catch {
                    Write-Host "An error occurred while running the script: $_" -ForegroundColor Red
                }
                
                Write-Host "`n[+] Execution Finished." -ForegroundColor Green
                Read-Host "Press Enter to return to the menu..."
            } else {
                Write-Host "Selection out of range." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        } else {
            Write-Host "Invalid input. Enter a number or 'B'." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

# Run Menu
Show-MainMenu
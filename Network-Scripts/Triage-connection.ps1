$Config = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
$Gateway = $Config.IPv4DefaultGateway.NextHop
$DNS = $Config.DNSServer.ServerAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1

$Checklist = [ordered]@{
    "Local Router" = $Gateway
    "DNS Server"   = $DNS
    "Internet"     = "8.8.8.8"
    "Game Latency" = "1.1.1.1"
}

Write-Host "`n--- Advanced IT Diagnostic Tool ---" -ForegroundColor Cyan
$FinalReport = @()

foreach ($Item in $Checklist.GetEnumerator()) {
    $Addr = $Item.Value
    if (-not $Addr) {
        $FinalReport += [PSCustomObject]@{ Component = $Item.Key; Status = "Error"; Details = "Address Missing" }; continue
    }

    try {
        $Ping = Test-Connection -ComputerName $Addr -Count 1 -ErrorAction Stop
        $Avg = [math]::Round($Ping.ResponseTime)
        $FinalReport += [PSCustomObject]@{ 
            Component = $Item.Key; 
            Address = $Addr; 
            Status = "OK"; 
            Latency = "$($Avg)ms"; 
            Details = "Connected" 
        }
    }
    catch {
        $ErrorCode = $_.Exception.InnerException.NativeErrorCode
        $ErrorMsg = switch ($ErrorCode) {
            11010 { "Request Timed Out (Firewall/Silent)" }
            11003 { "Destination Unreachable (No Path)" }
            1231  { "Hardware Error (Network Down)" }
            default { "Connection Failed" }
        }
        
        $FinalReport += [PSCustomObject]@{ 
            Component = $Item.Key; 
            Address = $Addr; 
            Status = "FAILED"; 
            Latency = "N/A"; 
            Details = $ErrorMsg 
        }
    }
}
$FinalReport | Format-Table -AutoSize
Write-Host "`n--- Diagnostic Complete ---" -ForegroundColor Cyan
pause > $null
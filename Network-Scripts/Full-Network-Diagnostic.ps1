param(
    [switch]$ContinuousPing
)

$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Restarting script with administrator rights..." -ForegroundColor Yellow
    $arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($ContinuousPing) { $arguments += " -ContinuousPing" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

Clear-Host
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Running network diagnostics hop-by-hop, please wait..." -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

# 1. Local Adapter Check (Smart Selection: Target the adapter with the internet route first, then physical)
$activeAdapter = $null
$defaultRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object InterfaceMetric, RouteMetric | Select-Object -First 1

if ($defaultRoute) {
    $activeAdapter = Get-NetAdapter -InterfaceIndex $defaultRoute.InterfaceIndex -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
}
if (-not $activeAdapter) {
    $activeAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.HardwareInterface -eq $true } | Select-Object -First 1
}
if (-not $activeAdapter) {
    $activeAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
}

if (-not $activeAdapter) {
    $results.Add([PSCustomObject]@{ Component = "Network Interface"; Status = "FAIL"; Details = "No active network adapters connected (LAN/Wi-Fi)"; Fix = "Connect a LAN cable or enable Wi-Fi. Check Device Manager for driver issues." })
} else {
    $details = "$($activeAdapter.Name) | Speed: $($activeAdapter.LinkSpeed) | Type: $($activeAdapter.PhysicalMediaType)"
    $results.Add([PSCustomObject]@{ Component = "Network Interface"; Status = "OK"; Details = $details; Fix = "" })
    
    # 2. IP Stack Check
    $ipConfig = Get-NetIPAddress -InterfaceIndex $activeAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ipConfig) {
        $results.Add([PSCustomObject]@{ Component = "IP Configuration"; Status = "FAIL"; Details = "No IPv4 address assigned to the adapter"; Fix = "Run 'ipconfig /renew' or verify DHCP server availability on your router." })
    } elseif ($ipConfig.IPAddress -like "169.254.*") {
        $results.Add([PSCustomObject]@{ Component = "IP Configuration"; Status = "FAIL"; Details = "APIPA Address detected ($($ipConfig.IPAddress)) - No DHCP response"; Fix = "The router didn't assign an IP. Reboot the router or check the DHCP scope." })
    } else {
        $results.Add([PSCustomObject]@{ Component = "IP Configuration"; Status = "OK"; Details = "Valid local IP assigned: $($ipConfig.IPAddress)"; Fix = "" })
    }
    
    # 3. Default Gateway Check (Local Router)
    $gateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -InterfaceIndex $activeAdapter.InterfaceIndex -ErrorAction SilentlyContinue).NextHop | Select-Object -Unique
    if (-not $gateway -or $gateway -eq "0.0.0.0") {
        $results.Add([PSCustomObject]@{ Component = "Default Gateway"; Status = "FAIL"; Details = "No Default Gateway found in routing table"; Fix = "Statically configure a gateway or repair DHCP connection." })
    } else {
        $gwPing = Test-Connection -ComputerName $gateway -Count 2 -ErrorAction SilentlyContinue
        if ($gwPing) {
            $avgGw = [math]::Round(($gwPing | Measure-Object -Property ResponseTime -Average).Average, 1)
            $results.Add([PSCustomObject]@{ Component = "Gateway Connection"; Status = "OK"; Details = "Local Router ($gateway) responds. Avg Latency: ${avgGw}ms"; Fix = "" })
        } else {
            $results.Add([PSCustomObject]@{ Component = "Gateway Connection"; Status = "FAIL"; Details = "Ping to local router ($gateway) failed"; Fix = "Check physical connection to the router. Verify router is powered on and ICMP is allowed." })
        }
    }
    
    # 4. DNS Server Connectivity
    $dnsServers = (Get-DnsClientServerAddress -InterfaceIndex $activeAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
    if (-not $dnsServers) {
        $results.Add([PSCustomObject]@{ Component = "DNS Server Assignment"; Status = "WARN"; Details = "No DNS servers configured on this adapter"; Fix = "Assign manual DNS servers (e.g., 8.8.8.8 / 1.1.1.1) in network settings." })
    } else {
        $dnsReachable = $false
        foreach ($dns in $dnsServers) {
            $dnsPing = Test-Connection -ComputerName $dns -Count 1 -ErrorAction SilentlyContinue
            if ($dnsPing) { $dnsReachable = $true }
        }
        if ($dnsReachable) {
            $results.Add([PSCustomObject]@{ Component = "DNS Reachability"; Status = "OK"; Details = "Assigned DNS servers ($($dnsServers -join ', ')) are responding"; Fix = "" })
        } else {
            $results.Add([PSCustomObject]@{ Component = "DNS Reachability"; Status = "FAIL"; Details = "Configured DNS servers ($($dnsServers -join ', ')) are unreachable"; Fix = "Change DNS configuration to public servers like 8.8.8.8 or 1.1.1.1." })
        }
    }
    
    # 5. DNS Resolution Test
    try {
        $dnsTest = [System.Net.Dns]::GetHostAddresses("google.com") 2>$null
        if ($dnsTest) {
            $results.Add([PSCustomObject]@{ Component = "DNS Resolution"; Status = "OK"; Details = "Domain names resolve correctly (google.com -> $($dnsTest[0].IPAddressToString))"; Fix = "" })
        } else {
            $results.Add([PSCustomObject]@{ Component = "DNS Resolution"; Status = "FAIL"; Details = "DNS Resolution failed (Cannot convert names to IP)"; Fix = "Run 'ipconfig /flushdns'. If issues persist, your DNS provider might be down." })
        }
    } catch {
        $results.Add([PSCustomObject]@{ Component = "DNS Resolution"; Status = "FAIL"; Details = "Critical DNS Resolution failure"; Fix = "Flush DNS and verify adapter DNS configurations." })
    }
    
    # 6. WAN / Internet / ISP Hop Check
    $publicTarget = "8.8.8.8"
    $ispPing = Test-Connection -ComputerName $publicTarget -Count 4 -ErrorAction SilentlyContinue
    if ($ispPing) {
        $avgIsp = [math]::Round(($ispPing | Measure-Object -Property ResponseTime -Average).Average, 1)
        $loss = 4 - ($ispPing.Count)
        if ($loss -gt 0) {
            $results.Add([PSCustomObject]@{ Component = "Internet Connection"; Status = "WARN"; Details = "Online with Packet Loss ($($loss * 25)% loss) | Avg Latency: ${avgIsp}ms"; Fix = "Potential line instability. Check infrastructure cables or contact ISP." })
        } else {
            $results.Add([PSCustomObject]@{ Component = "Internet Connection"; Status = "OK"; Details = "Fully Online. Route to WAN ($publicTarget) is clean. Avg Latency: ${avgIsp}ms"; Fix = "" })
        }
    } else {
        if ($results | Where-Object { $_.Component -eq "Gateway Connection" -and $_.Status -eq "OK" }) {
            $results.Add([PSCustomObject]@{ Component = "Internet Connection"; Status = "FAIL"; Details = "Local network OK, but WAN ($publicTarget) is unreachable"; Fix = "Your router is fine, but there is no internet feed. Check fiber/coaxial links or call ISP." })
        } else {
            $results.Add([PSCustomObject]@{ Component = "Internet Connection"; Status = "FAIL"; Details = "Internet connection link completely down"; Fix = "Resolve local network and gateway connectivity issues first." })
        }
    }
}

Clear-Host
Write-Host "┌────────────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│                               NETWORK DIAGNOSTICS DASHBOARD                            │" -ForegroundColor Cyan
Write-Host "└────────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host "  Host:      $($env:COMPUTERNAME.PadRight(15))  Active Adapter: $($activeAdapter.Name)"
Write-Host "  Driver:    $($activeAdapter.InterfaceDescription)"
Write-Host " ────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""

foreach ($res in $results) {
    switch ($res.Status) {
        "OK"   { $color = "Green";  $tag = "  [✔]  " }
        "WARN" { $color = "Yellow"; $tag = "  [⚠]  " }
        "FAIL" { $color = "Red";    $tag = "  [✘]  " }
    }
    
    Write-Host $tag -ForegroundColor $color -NoNewline
    Write-Host "$($res.Component.PadRight(25)) $($res.Details)"
    
    if ($res.Fix) {
        Write-Host "       ↳ Fix: $($res.Fix)" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host " ────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""

$stopwatch.Stop()
$elapsedSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)

Read-Host "Network diagnostics complete in $elapsedSeconds seconds. Press ENTER to close the window"
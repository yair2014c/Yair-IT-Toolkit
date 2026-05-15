Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, 
@{Name="ProcessName";Expression={(Get-Process -Id $_.OwningProcess).ProcessName}} |
Where-Object {$_.State -eq "Established"} | Out-GridView
pause | Out-Null
Clear-Host
$equipo = $env:COMPUTERNAME
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object prefixOrigin -EQ "Manual").IPAddress
$disco = Get-PSDrive C 
$libre = [MATH]::Round($disco.Free/1GB,1)
$total = [MATH]::Round(($disco.Used + $disco.Free)/1GB,1)

Write-Host "-----------------------------------------------------"
Write-Host "|Nombre del Equipo : $equipo " 
Write-Host "-----------------------------------------------------"
Write-Host "|IP : $ip"
Write-Host "-----------------------------------------------------"
Write-Host "|Espacio en Disco : $libre GB Disponibles de $total GB"   
Write-Host "-----------------------------------------------------"
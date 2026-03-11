function Validar-IP {
    param([string]$ip)
    if ([string]::IsNullOrWhiteSpace($ip)) { return $false }
    if (-not ($ip -match '^([0-9]{1,3}\.){3}[0-9]{1,3}$')) { return $false }
    foreach ($o in $ip.Split('.')) {
        if ([int]$o -gt 255) { return $false }
    }
    return $true
}

function IP-a-Entero {
    param([string]$ip)
    $o = $ip.Split('.')
    return ([int]$o[0] -shl 24) -bor ([int]$o[1] -shl 16) -bor ([int]$o[2] -shl 8) -bor ([int]$o[3])
}

function Entero-a-IP {
    param([int]$n)
    return "$(($n -shr 24) -band 255).$((($n -shr 16) -band 255)).$((($n -shr 8) -band 255)).$($n -band 255)"
}

function Siguiente-IP {
    param([string]$ip)
    return Entero-a-IP ((IP-a-Entero $ip) + 1)
}

function Calcular-Mascara24 {
    return "255.255.255.0"
}

function Seleccionar-Adaptador {
    $adaptadores = Get-NetAdapter
    
    if ($adaptadores.Count -eq 0) {
        Write-Host "No se detectaron tarjetas de red."
        return $null
    }

    Write-Host "`n--- TARJETAS DE RED DISPONIBLES ---"
    for ($i=0; $i -lt $adaptadores.Count; $i++) {
        Write-Host "[$($i+1)] $($adaptadores[$i].Name) - $($adaptadores[$i].InterfaceDescription) (Estado: $($adaptadores[$i].Status))"
    }

    $sel = Read-Host "`nSelecciona el numero de la tarjeta para la Red Interna (DHCP)"
    
    if ([int]$sel -gt 0 -and [int]$sel -le $adaptadores.Count) {
        return $adaptadores[[int]$sel - 1]
    } else {
        Write-Host "Seleccion invalida."
        return $null
    }
}

function Configurar-IPServidor {
    param([string]$ip, $adapter)

    $prefix = 24

    Write-Host "Limpiando IPs anteriores en $($adapter.Name)..."
    Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false

    Write-Host "Asignando nueva IP..."
    New-NetIPAddress -IPAddress $ip -PrefixLength $prefix -InterfaceIndex $adapter.InterfaceIndex | Out-Null

    Write-Host "Servidor configurado con IP $ip en $($adapter.Name)"
}

function DHCP-Instalado {
    return (Get-WindowsFeature DHCP).Installed
}

function Verificar-EstadoServicio {
    Write-Host "`n--- ESTADO DEL SERVICIO DHCP ---"
    if (DHCP-Instalado) {
        Write-Host "Servicio DHCP: INSTALADO"
        $serv = Get-Service DHCPServer -ErrorAction SilentlyContinue
        if ($serv.Status -eq "Running") {
            Write-Host "Estado: EN EJECUCION"
        } else {
            Write-Host "Estado: DETENIDO"
        }
    } else {
        Write-Host "Servicio DHCP: NO INSTALADO"
    }
    Read-Host "`nPresiona Enter para continuar..."
}

function Instalar-DHCP {
    Write-Host "`n--- INSTALACION DE DHCP ---"
    if (DHCP-Instalado) {
        $r = Read-Host "El servicio ya esta instalado. Deseas reinstalarlo? (s/n)"
        if ($r -notmatch "^[sS]$") { return }

        Write-Host "Desinstalando DHCP..."
        Uninstall-WindowsFeature DHCP -IncludeManagementTools | Out-Null
        Restart-Computer -Force
        return
    }

    Write-Host "Instalando rol DHCP, espera..."
    Install-WindowsFeature DHCP -IncludeManagementTools | Out-Null
    Add-DhcpServerInDC | Out-Null
    Write-Host "DHCP instalado correctamente."
    Read-Host "`nPresiona Enter para continuar..."
}

function Limpiar-ScopesDHCP {
    Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Remove-DhcpServerv4Scope -Force -ErrorAction SilentlyContinue
}

function Forzar-InterfazDHCP {
    param([string]$NombreTarjeta)
    
    Write-Host "Amarrando DHCP a la tarjeta: $NombreTarjeta"
    $bindings = Get-DhcpServerv4Binding
    foreach ($b in $bindings) {
        $esLaBuena = ($b.InterfaceAlias -eq $NombreTarjeta)
        Set-DhcpServerv4Binding -InterfaceAlias $b.InterfaceAlias -BindingState $esLaBuena
    }
    Restart-Service DHCPServer
}

function Configurar-DHCP {
    Write-Host "`n--- CONFIGURACION DE AMBITO DHCP ---"
    if (-not (DHCP-Instalado)) {
        Write-Host "DHCP no esta instalado. Ve a la opcion 1 primero."
        Read-Host "Presiona Enter..."
        return
    }

    $adapter = Seleccionar-Adaptador
    if (-not $adapter) { Read-Host "Presiona Enter para volver..."; return }

    Limpiar-ScopesDHCP

    $scope = Read-Host "`nNombre del ambito (ej: Red_Alumnos)"

    do { $start = Read-Host "IP inicial (sera la del servidor, ej: 192.168.10.1)" }
    until (Validar-IP $start)

    do { $end = Read-Host "IP final del pool (ej: 192.168.10.50)" }
    until (Validar-IP $end)

    $poolStart = Siguiente-IP $start
    $mask = Calcular-Mascara24

    Configurar-IPServidor -ip $start -adapter $adapter
    Write-Host "Esperando estabilizacion de red..."
    Start-Sleep -Seconds 2
    
    Forzar-InterfazDHCP -NombreTarjeta $adapter.Name

    $ipEntero = IP-a-Entero $start
    $scopeIdEntero = $ipEntero -band 0xFFFFFF00
    $CalculatedScopeId = Entero-a-IP $scopeIdEntero

    Write-Host "Creando ambito $scope ($CalculatedScopeId)..."
    Add-DhcpServerv4Scope -Name $scope -StartRange $poolStart -EndRange $end -SubnetMask $mask -State Active | Out-Null

    $gateway = Read-Host "`nGateway (Opcional - Enter para omitir)"
    if (Validar-IP $gateway) {
        Set-DhcpServerv4OptionValue -ScopeId $CalculatedScopeId -Router $gateway
    }

    $dns = Read-Host "DNS (Enter para usar la IP del servidor: $start)"
    if ([string]::IsNullOrWhiteSpace($dns)) { $dns = $start }
    
    if (Validar-IP $dns) {
        try {
            Set-DhcpServerv4OptionValue -ScopeId $CalculatedScopeId -DnsServer $dns -Force
            Write-Host "Opcion 006 (DNS) configurada correctamente hacia $dns."
        } catch {
            Write-Host "Error al configurar DNS. Intenta aplicarlo manualmente."
        }
    }

    Write-Host "`n=========================================="
    Write-Host "  CONFIGURACION FINALIZADA CON EXITO"
    Write-Host "=========================================="
    Write-Host " Tarjeta : $($adapter.Name)"
    Write-Host " Servidor: $start"
    Write-Host " Ambito  : $CalculatedScopeId"
    Write-Host " Pool    : $poolStart -> $end"
    Write-Host " DNS     : $dns"
    Read-Host "`nPresiona Enter para continuar..."
}

function Monitoreo-DHCP {
    if (-not (DHCP-Instalado)) {
        Write-Host "DHCP no instalado."
        Read-Host "Presiona Enter..."
        return
    }

    while ($true) {
        Clear-Host
        Write-Host "=== MONITOREO DHCP (CTRL + C para salir) ==="
        Get-Service DHCPServer | Select-Object Name, Status | Format-Table -AutoSize
        
        $scopes = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue

        foreach ($s in $scopes) {
            Write-Host "`nAmbito: $($s.Name) ($($s.ScopeId))"
            $leases = Get-DhcpServerv4Lease -ScopeId $s.ScopeId -ErrorAction SilentlyContinue
            if ($leases) {
                $leases | Select-Object IPAddress, ClientId, HostName | Format-Table -AutoSize
            } else {
                Write-Host "  No hay IPs prestadas aun."
            }
        }
        Start-Sleep -Seconds 5
    }
}

function Validar-IP {
    param([string]$ip)
    if ([string]::IsNullOrWhiteSpace($ip)) { return $false }
    if (-not ($ip -match '^([0-9]{1,3}\.){3}[0-9]{1,3}$')) { return $false }
    foreach ($o in $ip.Split('.')) {
        if ([int]$o -gt 255) { return $false }
    }
    return $true
}

function Escribir-Mensaje($msg) {
    Write-Host " [*] $msg"
}

function Opcion-Verificar {
    Write-Host "`n--- Verificando instalacion DNS ---"
    $check = Get-WindowsFeature -Name DNS
    if ($check.Installed) {
        Escribir-Mensaje "El rol DNS esta instalado."
        Get-Service -Name DNS | Select-Object Name, Status | Format-Table -AutoSize
    } else {
        Escribir-Mensaje "DNS NO esta instalado."
    }
    Read-Host "`nPresiona Enter para volver al menu..."
}

function Opcion-Instalar {
    Write-Host "`n--- Instalando y Configurando DNS ---"
    $check = Get-WindowsFeature -Name DNS
    
    if (-not $check.Installed) {
        Escribir-Mensaje "Instalando DNS, espera un momento..."
        Install-WindowsFeature -Name DNS -IncludeManagementTools | Out-Null
        Start-Service -Name DNS

        Escribir-Mensaje "Configurando reglas de Firewall (Puerto 53)..."
        Enable-NetFirewallRule -DisplayGroup "DNS Server" -ErrorAction SilentlyContinue | Out-Null
        Enable-NetFirewallRule -DisplayGroup "Servidor DNS" -ErrorAction SilentlyContinue | Out-Null
        
        Escribir-Mensaje "Instalacion y configuracion completadas."
    } else {
        Escribir-Mensaje "El rol DNS ya estaba instalado."
    }
    Read-Host "`nPresiona Enter para volver al menu..."
}

function Opcion-Agregar {
    Write-Host "`n--- Agregar Dominio DNS ---"
    $ZONA = Read-Host " [+] Dominio (ej: reprobados.com)"
    
    if ([string]::IsNullOrWhiteSpace($ZONA)) {
        Escribir-Mensaje "El dominio no puede estar vacio."
        Read-Host "`nPresiona Enter para volver..."
        return
    }

    if (Get-DnsServerZone -Name $ZONA -ErrorAction SilentlyContinue) {
        Escribir-Mensaje "El dominio '$ZONA' ya existe."
        Read-Host "`nPresiona Enter para volver..."
        return
    }


    Write-Host "`n Como quieres asignar la IP?"
    Write-Host "  [1] Detectar IP de este servidor automaticamente"
    Write-Host "  [2] Ingresar IP manualmente"
    $IP_OPCION = Read-Host " Selecciona una opcion"

    if ($IP_OPCION -eq "1") {
        Escribir-Mensaje "Detectando IP local de este servidor..."
        $IP_CLIENTE = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notmatch "^169\.254" } | Select-Object -First 1).IPAddress
        if (-not $IP_CLIENTE) {
            Escribir-Mensaje "No se pudo detectar una IP valida automaticamente."
            return
        }
    } else {
        do {
            $IP_CLIENTE = Read-Host " [+] Ingresa la IP manual (ej: 10.10.10.10)"
            if (-not (Validar-IP $IP_CLIENTE)) {
                Escribir-Mensaje "IP invalida. Intenta de nuevo."
            }
        } until (Validar-IP $IP_CLIENTE)
    }

    Escribir-Mensaje "Usando IP: $IP_CLIENTE"

    try {
        Add-DnsServerPrimaryZone -Name $ZONA -ZoneFile "$ZONA.dns"
        Add-DnsServerResourceRecordA -Name "@" -IPv4Address $IP_CLIENTE -ZoneName $ZONA
        Add-DnsServerResourceRecordA -Name "www" -IPv4Address $IP_CLIENTE -ZoneName $ZONA
        Add-DnsServerResourceRecordA -Name "ns1" -IPv4Address $IP_CLIENTE -ZoneName $ZONA
        Escribir-Mensaje "Dominio '$ZONA' apuntando a $IP_CLIENTE agregado con exito."
    } catch {
        Escribir-Mensaje "[ERROR] No se pudo agregar la zona. Ejecutaste PowerShell como Administrador?"
    }
    
    Read-Host "`nPresiona Enter para volver al menu..."
}

function Opcion-Borrar {
    Write-Host "`n--- Borrar Dominio DNS ---"
    $DOMINIOS = Get-DnsServerZone | Where-Object { $_.IsAutoCreated -eq $false -and $_.ZoneName -ne "TrustAnchors" }
    
    if ($DOMINIOS.Count -eq 0) {
        Escribir-Mensaje "No hay dominios configurados para eliminar."
        Read-Host "`nPresiona Enter para volver..."
        return
    }

    Write-Host "`n Dominios disponibles:"
    for ($i=0; $i -lt $DOMINIOS.Count; $i++) {
        Write-Host "  [$($i+1)] $($DOMINIOS[$i].ZoneName)"
    }
    Write-Host "  [0] Cancelar"

    $SEL = Read-Host "`n [+] Selecciona el numero del dominio a borrar"
    if ($SEL -eq "0" -or [string]::IsNullOrWhiteSpace($SEL)) { return }

    try {
        $ZONA = $DOMINIOS[[int]$SEL - 1].ZoneName
        $CONFIRM = Read-Host " [!] Vas a eliminar '$ZONA'. Confirmas? (s/n)"
        
        if ($CONFIRM -match "^[sS]$") {
            Remove-DnsServerZone -Name $ZONA -Force
            Escribir-Mensaje "Dominio '$ZONA' eliminado correctamente."
        } else {
            Escribir-Mensaje "Operacion cancelada."
        }
    } catch {
        Escribir-Mensaje "Opcion invalida."
    }
    Read-Host "`nPresiona Enter para volver al menu..."
}

function Opcion-Ver {
    Write-Host "`n--- Dominios Configurados ---"
    $Zonas = Get-DnsServerZone | Where-Object { $_.IsAutoCreated -eq $false -and $_.ZoneName -ne "TrustAnchors" } | Select-Object ZoneName
    if ($Zonas) {
        $Zonas | Format-Table -HideTableHeaders | Out-String | Write-Host
    } else {
        Escribir-Mensaje "No hay dominios personalizados creados aun."
    }
    Read-Host "Presiona Enter para volver al menu..."
}

# Bucle principal del menu
while ($true) {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "        SISTEMA DNS :3     "
    Write-Host "=========================================="
    Write-Host "  [1] Verificar instalacion DNS"
    Write-Host "  [2] Instalar DNS "
    Write-Host "  [3] Agregar dominio "
    Write-Host "  [4] Borrar dominio"
    Write-Host "  [5] Ver dominios Creados"
    Write-Host "  [6] Salir"
    Write-Host "------------------------------------------"
    
    $OPT = Read-Host " Selecciona una opcion"

    switch ($OPT) {
        "1" { Opcion-Verificar }
        "2" { Opcion-Instalar }
        "3" { Opcion-Agregar }
        "4" { Opcion-Borrar }
        "5" { Opcion-Ver }
        "6" { exit }
        default { 
            Escribir-Mensaje "Opcion invalida."
            Start-Sleep -Seconds 1 
        }
    }
}
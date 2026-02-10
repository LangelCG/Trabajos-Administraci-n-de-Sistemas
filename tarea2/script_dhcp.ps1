$ProgressPreference = 'SilentlyContinue'

# --- Funcion para validar IP y regla de doble cero ---
function Validar-IP($IP) {
    if ($IP -as [ipaddress]) {
        $octetos = $IP.Split('.')
        # Regla: No permitir 0.0 en los ultimos dos octetos al mismo tiempo
        if ([int]$octetos[2] -eq 0 -and [int]$octetos[3] -eq 0) {
            Write-Host "Error: No se permite el formato X.X.0.0." -ForegroundColor Red
            return $false
        }
        return $true
    }
    Write-Host "Error: Formato de IP invalido." -ForegroundColor Red
    return $false
}

# --- Funcion para validar DNS ---
function Validar-DNS($IP) {
    if (-not (Validar-IP $IP)) { return $false }
    
    Write-Host "Verificando servidor DNS ($IP)..."
    if (Test-Connection -ComputerName $IP -Count 1 -Quiet) {
        Write-Host "DNS detectado."
        return $true
    } else {
        Write-Host "--- AVISO: El servidor DNS no responde ---"
        $force = Read-Host "¿Deseas usar esta IP de todos modos? (s/n)"
        if ($force -eq "s") { return $true } else { return $false }
    }
}

# --- 1. Instalacion ---
function Instalar-Servicio {
    Write-Host "-------------------------------------------------"
    Write-Host "Comprobando si el servicio DHCP esta instalado..."
    $f = Get-WindowsFeature -Name DHCP
    if ($f.Installed -eq $false) {
        Write-Host "-------------------------------------------------"
        Write-Host "Servicio no encontrado, Iniciando instalacion..."
        Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null
        Write-Host "Instalacion completa."
    } else {
        Write-Host "-------------------------------------------------"
        Write-Host "El servicio ya esta instalado..."
    }
}

# --- 2. Configuracion ---
function Configurar-Ambito {
    Write-Host "-------------------------------------------------"
    Write-Host "----- Configuracion de Ambito DHCP -----"
    $SCOPE_NAME = Read-Host "Nombre del Ambito (Scope)"
    
    do { $IP_START = Read-Host "Rango Inicial IP"; $v = Validar-IP $IP_START } until ($v)
    do { $IP_END = Read-Host "Rango Final IP"; $v = Validar-IP $IP_END } until ($v)
    do { $GW_IP = Read-Host "Puerta de enlace (Gateway)"; $v = Validar-IP $GW_IP } until ($v)
    do { $DNS_IP = Read-Host "IP del DNS"; $v = Validar-DNS $DNS_IP } until ($v)
    
    $LEASE_TIME = "00:10:00"

    # Limpieza de ambito anterior para evitar errores
    Remove-DhcpServerv4Scope -ScopeId 192.168.100.0 -Force -ErrorAction SilentlyContinue | Out-Null

    # Creacion del ambito y opciones
    Add-DhcpServerv4Scope -Name $SCOPE_NAME -StartRange $IP_START -EndRange $IP_END -SubnetMask 255.255.255.0 -State Active -LeaseDuration $LEASE_TIME | Out-Null
    Set-DhcpServerv4OptionValue -ScopeId 192.168.100.0 -OptionId 3 -Value $GW_IP -Force | Out-Null
    Set-DhcpServerv4OptionValue -ScopeId 192.168.100.0 -OptionId 6 -Value $DNS_IP -Force | Out-Null

    Write-Host "-------------------------------------------------"
    Write-Host "Servicio configurado y reiniciado con exito."
}

# --- 3. Diagnostico ---
function Ver-Diagnostico {
    Write-Host "-------------------------------------------------"
    Write-Host "----- Diagnostico del Sistema -----"
    Write-Host "Estado del servicio:"
    Get-Service DHCPServer | Select-Object -ExpandProperty Status
    Write-Host "-------------------------------------------------"
    Write-Host "Concesiones (Leases) activas:"
    Get-DhcpServerv4Lease -ScopeId 192.168.100.0 -ErrorAction SilentlyContinue
}

# --- MENU PRINCIPAL ---
while ($true) {
    Write-Host "`n=========================================="
    Write-Host "      MENU GESTION DHCP "
    Write-Host "=========================================="
    Write-Host "1. Instalar Servicio DHCP"
    Write-Host "2. Configurar Nuevo Ambito"
    Write-Host "3. Ver Diagnostico y Clientes"
    Write-Host "4. Salir"
    Write-Host "------------------------------------------"
    $opt = Read-Host "Selecciona una opcion"

    switch ($opt) {
        "1" { Instalar-Servicio }
        "2" { Configurar-Ambito }
        "3" { Ver-Diagnostico }
        "4" { exit }
        default { Write-Host "Opcion invalida." }
    }
}
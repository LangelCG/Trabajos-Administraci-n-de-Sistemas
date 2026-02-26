# MenuSSH.ps1

# Cargar las funciones externas (OBLIGATORIO)
. .\ssh_functions.ps1

# Validacion inicial de permisos
if (-not (Verificar-Admin)) {
    Write-Host " [!] ERROR: Debes ejecutar PowerShell como Administrador."
    exit
}

function Escribir-Mensaje($msg) {
    Write-Host " [*] $msg"
}

function Opcion-Verificar {
    Write-Host "`n--- Verificando estado SSH ---"
    
    $estado = Obtener-Estado-SSH

    if ($estado.Instalado) {
        Escribir-Mensaje "OpenSSH Server: INSTALADO"
        Escribir-Mensaje "Estado del Servicio: $($estado.Servicio)"
        Escribir-Mensaje "Tipo de Inicio: $($estado.Inicio)"
        
        if ($estado.Firewall) {
            Escribir-Mensaje "Regla de Firewall (Puerto 22): ACTIVA"
        } else {
            Escribir-Mensaje "Regla de Firewall (Puerto 22): NO ENCONTRADA"
        }
    } else {
        Escribir-Mensaje "OpenSSH Server NO esta instalado."
    }
    
    Read-Host "`nPresiona Enter para volver al menu..."
}

function Opcion-Instalar {
    Write-Host "`n--- Instalando y Configurando SSH ---"
    
    # 1. Instalacion
    $estado = Obtener-Estado-SSH
    if (-not $estado.Instalado) {
        Escribir-Mensaje "Instalando OpenSSH Server, espera un momento..."
        try {
            Instalar-Paquete-SSH | Out-Null
            Escribir-Mensaje "Paquete instalado correctamente."
        } catch {
            Escribir-Mensaje "[ERROR] Fallo la instalacion."
            return
        }
    } else {
        Escribir-Mensaje "El paquete OpenSSH ya estaba instalado."
    }

    # 2. Configuracion Servicio
    try {
        Escribir-Mensaje "Configurando servicio para inicio automatico..."
        Configurar-Arranque-SSH
        Escribir-Mensaje "Servicio iniciado y configurado."
    } catch {
        Escribir-Mensaje "[ERROR] No se pudo iniciar el servicio."
    }

    # 3. Firewall
    try {
        Escribir-Mensaje "Configurando reglas de Firewall (Puerto 22)..."
        if (Configurar-Firewall-SSH) {
            Escribir-Mensaje "Regla de firewall creada con exito."
        } else {
            Escribir-Mensaje "La regla de firewall ya existia."
        }
    } catch {
        Escribir-Mensaje "[ERROR] Fallo al configurar firewall."
    }

    Escribir-Mensaje "Instalacion y configuracion completadas."
    Read-Host "`nPresiona Enter para volver al menu..."
}

function Opcion-Info {
    Write-Host "`n--- Informacion de Conexion ---"
    
    $IPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notmatch "^169\.254" }
    
    if ($IPs) {
        foreach ($ip in $IPs) {
            Escribir-Mensaje "Interfaz: $($ip.InterfaceAlias)"
            Escribir-Mensaje "IP: $($ip.IPAddress)"
            Write-Host ""
        }
        Write-Host " Para conectar usa: ssh Administrator@IP_DEL_SERVIDOR"
    } else {
        Escribir-Mensaje "No se detectaron IPs validas."
    }
    Read-Host "`nPresiona Enter para volver al menu..."
}

# Bucle principal del menu
while ($true) {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "       SISTEMA SSH "
    Write-Host "=========================================="
    Write-Host "  [1] Verificar estado SSH"
    Write-Host "  [2] Instalar y Configurar (Completo) "
    Write-Host "  [3] Ver IPs para conectar "
    Write-Host "  [4] Salir"
    Write-Host "------------------------------------------"
    
    $OPT = Read-Host " Selecciona una opcion"

    switch ($OPT) {
        "1" { Opcion-Verificar }
        "2" { Opcion-Instalar }
        "3" { Opcion-Info }
        "4" { exit }
        default { 
            Escribir-Mensaje "Opcion invalida."
            Start-Sleep -Seconds 1 
        }
    }
}
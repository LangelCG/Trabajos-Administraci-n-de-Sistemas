# ssh_functions.ps1

function Verificar-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Obtener-Estado-SSH {
    $info = @{
        Instalado = $false
        Servicio  = "Desconocido"
        Inicio    = "Desconocido"
        Firewall  = $false
    }

    # 1. Verificar si esta instalado
    $cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($cap.State -eq 'Installed') { $info.Instalado = $true }

    # 2. Verificar servicio
    $srv = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if ($srv) {
        $info.Servicio = $srv.Status
        $info.Inicio = $srv.StartType
    }

    # 3. Verificar Firewall
    $regla = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if ($regla -and $regla.Enabled -eq $true) { $info.Firewall = $true }

    return $info
}

function Instalar-Paquete-SSH {
    # Instala solo si no esta puesto
    $cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($cap.State -ne 'Installed') {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        return $true
    }
    return $false
}

function Configurar-Arranque-SSH {
    # Habilita el inicio automatico y arranca el servicio
    Set-Service -Name sshd -StartupType 'Automatic'
    Start-Service sshd
}

function Configurar-Firewall-SSH {
    # Crea la regla si no existe
    $regla = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if (-not $regla) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        return $true
    }
    return $false
}
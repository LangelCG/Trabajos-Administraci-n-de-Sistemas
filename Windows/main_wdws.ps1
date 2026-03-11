
#Requires -RunAsAdministrator

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Launch-Script {
    param([string]$File)
    $path = Join-Path $ScriptDir $File
    if (-not (Test-Path $path)) {
        Write-Host ""
        Write-Host "  [ERROR] No se encontro el archivo: $File" -ForegroundColor Red
        Write-Host "  Asegurate de que todos los scripts esten en el mismo directorio." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Presiona Enter para continuar"
        return
    }
    & powershell.exe -ExecutionPolicy Bypass -File $path
}

while ($true) {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "     ADMINISTRACION DE SERVICIOS"
    Write-Host "          Windows Server :3"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  Host : $env:COMPUTERNAME"
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' } | Select-Object -First 1).IPAddress
    Write-Host "  IP   : $ip"
    Write-Host "  Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "------------------------------------------"
    Write-Host "  Selecciona el servicio a administrar:"
    Write-Host ""
    Write-Host "  1. DHCP"
    Write-Host "  2. DNS"
    Write-Host "  3. SSH"
    Write-Host "  4. FTP"
    Write-Host "  5. HTTP  (IIS / Apache / Nginx)"
    Write-Host "  0. Salir"
    Write-Host "------------------------------------------"

    $OPT = Read-Host "  Selecciona"

    switch ($OPT) {
        "1" { Launch-Script "dhcpWdws.ps1" }
        "2" { Launch-Script "dnsWdws.ps1" }
        "3" { Launch-Script "ssh.ps1" }
        "4" { Launch-Script "ftp.ps1" }
        "5" { Launch-Script "http.ps1" }
        "0" {
            Write-Host ""
            Write-Host "  Saliendo... Hasta luego!" -ForegroundColor Green
            Write-Host ""
            exit 0
        }
        default {
            Write-Host "  [WARN] Opcion invalida." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
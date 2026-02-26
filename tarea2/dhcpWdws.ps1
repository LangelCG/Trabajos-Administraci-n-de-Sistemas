. .\FuncionesDHCP.ps1

do {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "            SISTEMA DHCP :3     "
    Write-Host "=========================================="
    Write-Host "  [1] Instalar DHCP"
    Write-Host "  [2] Configurar DHCP (Mejorado)"
    Write-Host "  [3] Monitorear concesiones"
    Write-Host "  [4] Ver estado del servicio"
    Write-Host "  [5] Salir"
    Write-Host "------------------------------------------"

    $op = Read-Host "Seleccione opcion"

    if ($op -eq "1") { Instalar-DHCP }
    elseif ($op -eq "2") { Configurar-DHCP }
    elseif ($op -eq "3") { Monitoreo-DHCP }
    elseif ($op -eq "4") { Verificar-EstadoServicio }

} while ($op -ne "5")
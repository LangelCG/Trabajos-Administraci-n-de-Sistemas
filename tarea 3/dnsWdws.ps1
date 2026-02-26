. .\dns_functions.ps1

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
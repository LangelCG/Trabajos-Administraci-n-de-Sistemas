# ============================================================
# menu_ftp.ps1 - Menú Principal con tu diseño original nwn
# ============================================================

# Importamos las funciones usando el método seguro del punto
. ".\ftp_funciones.ps1"

while ($true) {
    Write-Host ""
    Write-Host "=================================================="
    Write-Host "      --- GESTOR DE SERVIDOR FTP ---"
    Write-Host "=================================================="
    Write-Host "1. Instalar componentes FTP"
    Write-Host "2. Configurar / Reconfigurar sitio FTP"
    Write-Host "3. Ver estado del servicio"
    Write-Host "4. Reiniciar servicio FTP"
    Write-Host "--------------------------------------------------"
    Write-Host "5. Agregar Usuarios"
    Write-Host "6. Ver Usuarios Registrados"
    Write-Host "7. Cambiar de Grupo a un Usuario"
    Write-Host "8. Eliminar Usuario"
    Write-Host "9. Salir"
    Write-Host "=================================================="
    $opcion = Read-Host "Elige una opcion (1-9)"

    switch ($opcion) {
        "1" { Opcion-Instalar-FTP }
        "2" { Opcion-Configurar-FTP }
        "3" { Opcion-Estado-FTP }
        "4" { Opcion-Reiniciar-FTP }
        "5" { Opcion-Crear-Usuarios }
        "6" { Opcion-Ver-Usuarios }
        "7" { Opcion-Cambiar-Grupo }
        "8" { Opcion-Eliminar-Usuario }
        "9" {
            Write-Host "Cerrando el gestor FTP. ¡Éxito con la práctica!" -ForegroundColor Cyan
            exit
        }
        default {
            Write-Host "Opción no válida. Intenta de nuevo." -ForegroundColor Red
        }
    }
}
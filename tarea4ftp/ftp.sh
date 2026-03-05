#!/bin/bash

source ./ftp_funciones.sh

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root."
  exit 1
fi

while true; do
    echo ""
    echo "========================================="
    echo "        MENU FTP     "
    echo "========================================="
    echo "1. Instalar y configurar servidor FTP"
    echo "2. Ver estado del servicio vsftpd"
    echo "3. Reiniciar vsftpd"
    echo "4. Crear usuarios FTP"
    echo "5. Ver usuarios registrados"
    echo "6. Cambiar grupo de un usuario"
    echo "7. Eliminar un usuario"
    echo "8. Salir"
    echo "========================================="
    read -p "Elige una opcion: " opcion

    case $opcion in
        1)
            opcion_instalar_ftp
            ;;
        2)
            opcion_estado_ftp
            ;;
        3)
            opcion_reiniciar_ftp
            ;;
        4)
            opcion_crear_usuarios
            ;;
        5)
            opcion_ver_usuarios
            ;;
        6)
            opcion_cambiar_grupo
            ;;
        7)
            opcion_eliminar_usuario
            ;;
        8)
            echo "Saliendo del script..."
            exit 0
            ;;
        *)
            echo "[-] Opcion no valida. Intenta de nuevo."
            ;;
    esac
done
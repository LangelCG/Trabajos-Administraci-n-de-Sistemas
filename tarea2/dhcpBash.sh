#!/bin/bash

source ./dhcp_functions.sh

while true; do
    clear
    echo "=========================================="
    echo "      SISTEMA DHCP :3 "
    echo "=========================================="
    echo "1. Verificar instalacion "
    echo "2. Instalar DHCP"
    echo "3. Configurar Ambito"
    echo "4. Ver Leases (Clientes)"
    echo "5. Salir"
    echo "------------------------------------------"
    read -p "Selecciona una opcion: " OPT
    
    case $OPT in
        1) opcion_verificar ;;
        2) opcion_instalar ;;
        3) opcion_configurar ;;
        4) opcion_leases ;;
        5) exit 0 ;;
        *) echo "Opcion invalida." ;;
    esac
done
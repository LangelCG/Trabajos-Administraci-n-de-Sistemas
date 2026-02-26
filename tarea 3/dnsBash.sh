#!/bin/bash

source ./dns_functions.sh

while true; do
    clear
    echo "=========================================="
    echo "      SISTEMA DNS :3"
    echo "=========================================="
    echo "0. SINCRONIZAR RED "
    echo "1. Agregar Dominio "
    echo "2. Borrar Dominio"
    echo "3. Ver Dominios Creados"
    echo "4. Salir"
    echo "------------------------------------------"
    read -p "Selecciona: " OPT
    case $OPT in
        0) opcion_auto_sync ;;
        1) opcion_alta ;;
        2) opcion_baja ;;
        3) opcion_listar ;;
        4) exit 0 ;;
    esac
done
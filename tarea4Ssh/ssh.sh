#!/bin/bash

source ./ssh_functions.sh

verificar_root

function escribir_mensaje() {
    echo " [*] $1"
}

function pausar() {
    echo ""
    read -p "Presiona Enter para volver al menu..." dummy
}

function opcion_verificar() {
    echo ""
    echo "--- Verificando estado SSH ---"

    ESTADO_PAQUETE=$(obtener_estado_ssh)
    
    if [ "$ESTADO_PAQUETE" == "INSTALADO" ]; then
        escribir_mensaje "OpenSSH Server: INSTALADO"
        
        ESTADO_SERV=$(obtener_estado_servicio)
        escribir_mensaje "Estado del Servicio: $ESTADO_SERV"
        
        ESTADO_FW=$(obtener_estado_firewall)
        if [ "$ESTADO_FW" == "PERMITIDO" ]; then
            escribir_mensaje "Regla de Firewall: ACTIVA"
        else
            escribir_mensaje "Regla de Firewall: NO ENCONTRADA"
        fi
    else
        escribir_mensaje "OpenSSH Server NO esta instalado."
    fi
    pausar
}

function opcion_instalar() {
    echo ""
    echo "--- Instalando y Configurando SSH ---"
    
    ESTADO_PAQUETE=$(obtener_estado_ssh)
    if [ "$ESTADO_PAQUETE" != "INSTALADO" ]; then
        escribir_mensaje "Instalando OpenSSH Server..."
        instalar_paquete_ssh
        if [ $? -eq 0 ]; then
            escribir_mensaje "Paquete instalado."
        else
            escribir_mensaje "ERROR: Fallo la instalacion."
            pausar
            return
        fi
    else
        escribir_mensaje "El paquete ya estaba instalado."
    fi

    escribir_mensaje "Configurando servicio..."
    configurar_arranque_ssh
    escribir_mensaje "Servicio iniciado."

    escribir_mensaje "Configurando firewall..."
    configurar_firewall_ssh
    escribir_mensaje "Reglas de firewall aplicadas."

    escribir_mensaje "Instalacion completada."
    pausar
}

function opcion_info() {
    echo ""
    echo "--- Informacion de Conexion ---"
    
    ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | while read IP; do
        escribir_mensaje "IP Detectada: $IP"
    done
    
    echo ""
    echo " Para conectar usa: ssh usuario@IP"
    pausar
}

while true; do
    clear
    echo "=========================================="
    echo "       SISTEMA SSH"
    echo "=========================================="
    echo "  [1] Verificar estado SSH"
    echo "  [2] Instalar y Configurar"
    echo "  [3] Ver IPs para conectar"
    echo "  [4] Salir"
    echo "------------------------------------------"
    
    echo -n " Selecciona una opcion: "
    read OPT

    case $OPT in
        1) opcion_verificar ;;
        2) opcion_instalar ;;
        3) opcion_info ;;
        4) exit 0 ;;
        *) 
            escribir_mensaje "Opcion invalida."
            sleep 1
            ;;
    esac
done
#!/bin/bash

function verificar_root() {
    if [ "$EUID" -ne 0 ]; then
        echo " [!] ERROR: Debes ejecutar este script como root (sudo)."
        exit 1
    fi
}

function obtener_estado_ssh() {
    # 1. Verificar instalacion (rpm -q devuelve 0 si existe)
    if rpm -q openssh-server &> /dev/null; then
        echo "INSTALADO"
    else
        echo "NO_INSTALADO"
    fi
}

function obtener_estado_servicio() {
    # 2. Verificar servicio
    if systemctl is-active --quiet sshd; then
        echo "ACTIVO"
    else
        echo "INACTIVO"
    fi
}

function obtener_estado_firewall() {
    # 3. Verificar si el servicio ssh esta permitido en firewall
    if firewall-cmd --list-services 2>/dev/null | grep -q "ssh"; then
        echo "PERMITIDO"
    else
        echo "BLOQUEADO"
    fi
}

function instalar_paquete_ssh() {
    yum install -y openssh-server &> /dev/null
}

function configurar_arranque_ssh() {
    systemctl enable sshd &> /dev/null
    systemctl start sshd &> /dev/null
}

function configurar_firewall_ssh() {
    firewall-cmd --permanent --add-service=ssh &> /dev/null
    firewall-cmd --reload &> /dev/null
}
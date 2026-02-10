#!/bin/bash

# funcion validar ip
validar_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! $ip =~ $regex ]]; then return 1; fi

    IFS='.' read -r -a octs <<< "$ip"
    
    for o in "${octs[@]}"; do
        if [[ $o -lt 0 || $o -gt 255 ]]; then return 1; fi
    done

    if [[ ${octs[2]} -eq 0 && ${octs[3]} -eq 0 ]]; then
        echo "Error: No se permite el formato X.X.0.0."
        return 1
    fi

    return 0
}

#validacion dns
validar_dns() {
    local dns=$1
    if ! validar_ip "$dns"; then return 1; fi

    echo "Verificando servidor DNS ($dns)..."
    # Intenta un ping rápido de 1 segundo
    if ping -c 1 -W 1 "$dns" > /dev/null 2>&1; then
        echo "DNS detectado y activo."
        return 0
    else
        echo "--- AVISO: El servidor DNS no responde ---"
        read -p "¿Es la IP de tu Windows Server? ¿Deseas usarla de todos modos? (s/n): " force
        [[ "$force" == "s" ]] && return 0 || return 1
    fi
}


instalar() {
    echo "-------------------------------------------------"
    echo "Comprobando estado del servicio..."
    if ! rpm -q dhcp &> /dev/null; then
        echo "Servicio no encontrado, Instalando de forma desatendida..."
        sudo yum install -y dhcp > /dev/null 2>&1
        echo "Instalación terminada con éxito."
    else
        echo "El servicio ya está instalado..."
    fi
}

configurar() {
    echo "-------------------------------------------------"
    echo "----- Configuración de Ámbito DHCP -----"
    read -p "Nombre del Ámbito (Scope): " SCOPE_NAME
    
    while :; do
        read -p "Rango Inicial IP (ej. 192.168.100.50): " IP_START
        validar_ip "$IP_START" && break || echo "IP no válida o formato X.X.0.0 detectado."
    done

    while :; do
        read -p "Rango Final IP (ej. 192.168.100.150): " IP_END
        validar_ip "$IP_END" && break || echo "IP no válida."
    done

    while :; do
        read -p "Puerta de enlace (Gateway): " GW_IP
        validar_ip "$GW_IP" && break || echo "IP no válida."
    done

    while :; do
        read -p "IP del DNS (Windows Server .20): " DNS_IP
        validar_dns "$DNS_IP" && break
    done

    read -p "Tiempo de concesión (segundos): " LEASE_TIME

    sudo bash -c "cat > /etc/dhcp/dhcpd.conf" <<EOF
subnet 192.168.100.0 netmask 255.255.255.0 {
    range $IP_START $IP_END;
    option routers $GW_IP;
    option domain-name-servers $DNS_IP;
    default-lease-time $LEASE_TIME;
    max-lease-time 7200;
}
EOF
    if dhcpd -t -cf /etc/dhcp/dhcpd.conf > /dev/null 2>&1; then
        sudo systemctl restart dhcpd
        echo "-------------------------------------------------"
        echo "Configuración aplicada y servicio reiniciado."
    else
        echo "Error crítico en el archivo de configuración."
    fi
}

# --- 3. Diagnóstico ---
diagnostico() {
    echo "-------------------------------------------------"
    echo "ESTADO: $(systemctl is-active dhcpd)"
    echo "CONCESIONES ACTUALES:"
    grep "lease" /var/lib/dhcpd/dhcpd.leases 2>/dev/null | sort | uniq || echo "No hay clientes conectados."
}

# --- MENÚ PRINCIPAL ---
while true; do
    echo -e "\n=========================================="
    echo "      SISTEMA DE GESTIÓN DHCP"
    echo "=========================================="
    echo "1. Instalar Servicio DHCP"
    echo "2. Configurar Nuevo Ambito"
    echo "3. Ver Diagnóstico y Clientes"
    echo "4. Salir"
    echo "------------------------------------------"
    read -p "Selecciona una opción: " OPT
    case $OPT in
        1) instalar ;;
        2) configurar ;;
        3) diagnostico ;;
        4) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción inválida." ;;
    esac
done
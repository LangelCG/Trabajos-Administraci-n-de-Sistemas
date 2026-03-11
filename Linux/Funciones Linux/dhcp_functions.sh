#!/bin/bash

ip_to_int() {
    local IFS=.
    read -r i1 i2 i3 i4 <<< "$1"
    echo "$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))"
}

int_to_ip() {
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo $ip
}

validar_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! $ip =~ $regex ]]; then return 1; fi

    IFS='.' read -r -a octs <<< "$ip"
    for o in "${octs[@]}"; do
        if [[ $o -lt 0 || $o -gt 255 ]]; then return 1; fi
    done
    return 0
}

opcion_verificar() {
    echo "-------------------------------------------------"
    echo "Verificando instalacion..."
    if rpm -q dhcp &> /dev/null; then
        echo "[OK] El paquete DHCP esta instalado."
        systemctl status dhcpd | grep "Active:"
    else
        echo "[!] El paquete DHCP NO esta instalado."
    fi
    read -p "Presiona Enter para continuar..."
}

opcion_instalar() {
    echo "-------------------------------------------------"
    if ! rpm -q dhcp &> /dev/null; then
        echo "Instalando DHCP..."
        sudo yum install -y dhcp > /dev/null 2>&1
        echo "[OK] Instalacion completada."
    else
        echo "[INFO] El servicio ya estaba instalado."
    fi
    read -p "Presiona Enter para continuar..."
}

opcion_configurar() {
    echo "-------------------------------------------------"
    echo "      CONFIGURACION DEL AMBITO (CALCULO AUTOMATICO)"
    echo "-------------------------------------------------"
    read -p "Nombre del Ambito (Scope): " SCOPE_NAME
    
    while true; do
        read -p "IP Inicial (ej: 192.168.110.0 o .1): " IP_INPUT
        if validar_ip "$IP_INPUT"; then break; fi
    done

    while true; do
        read -p "IP Final (ej: 192.168.110.20): " IP_END
        if validar_ip "$IP_END"; then
            INT_START=$(ip_to_int "$IP_INPUT")
            INT_END=$(ip_to_int "$IP_END")
            
            if [[ $INT_END -le $INT_START ]]; then
                echo "   [ERROR] La IP Final debe ser MAYOR a la Inicial."
            else
                break 
            fi
        fi
    done

    read -p "Gateway (Enter para omitir): " GW_IP
    read -p "DNS Server (Enter para omitir): " DNS_IP
    read -p "Tiempo de concesion (segundos): " LEASE_TIME
    if [[ -z "$LEASE_TIME" ]]; then LEASE_TIME=600; fi

    SUBNET_PRE=$(echo $IP_INPUT | cut -d'.' -f1-3)
    LAST_OCTET=$(echo $IP_INPUT | cut -d'.' -f4)

    if [[ "$LAST_OCTET" -eq "0" ]]; then
        SERVER_IP="$SUBNET_PRE.1"
    else
        SERVER_IP="$IP_INPUT"
    fi

    SERVER_INT=$(ip_to_int "$SERVER_IP")
    POOL_START_INT=$((SERVER_INT + 1))
    POOL_START_IP=$(int_to_ip "$POOL_START_INT")
    
    SUBNET_ID="$SUBNET_PRE.0"

    INTERFAZ="enp0s8" 

    echo "-------------------------------------------------"
    echo "Calculos realizados:"
    echo " -> Red:            $SUBNET_ID"
    echo " -> IP Server:      $SERVER_IP (Se configurara en $INTERFAZ)"
    echo " -> Pool DHCP:      $POOL_START_IP hasta $IP_END"
    echo "-------------------------------------------------"

    echo "Configurando IP del servidor..."
    sudo ip addr flush dev $INTERFAZ
    sudo ip addr add $SERVER_IP/24 dev $INTERFAZ
    sudo ip link set $INTERFAZ up

    CONF="/etc/dhcp/dhcpd.conf"
    
    sudo bash -c "cat > $CONF" <<EOF
default-lease-time $LEASE_TIME;
max-lease-time 7200;
authoritative;

subnet $SUBNET_ID netmask 255.255.255.0 {
    range $POOL_START_IP $IP_END;
EOF

    if [[ -n "$GW_IP" ]]; then
        sudo bash -c "echo '    option routers $GW_IP;' >> $CONF"
    fi
    if [[ -n "$DNS_IP" ]]; then
        sudo bash -c "echo '    option domain-name-servers $DNS_IP;' >> $CONF"
    fi
    
    sudo bash -c "echo '}' >> $CONF"

    if dhcpd -t -cf $CONF > /dev/null 2>&1; then
        sudo systemctl restart dhcpd
        echo "[OK] Servicio configurado y reiniciado con exito."
    else
        echo "-------------------------------------------------"
        echo "[ERROR] La configuracion generada no es valida."
        dhcpd -t -cf $CONF
    fi
    read -p "Presiona Enter para continuar..."
}

opcion_leases() {
    echo "-------------------------------------------------"
    echo "CLIENTES CONECTADOS : "
    LEASE_FILE="/var/lib/dhcpd/dhcpd.leases"
    if [ -f "$LEASE_FILE" ]; then
        grep -E "lease |hardware ethernet|client-hostname" $LEASE_FILE | awk '{print $2}' | xargs -n3 | sed 's/;//g'
    else
        echo "No hay registro de leases."
    fi
    read -p "Presiona Enter para continuar..."
}
#!/bin/bash

CONF="/etc/named.conf"
ZONES_DIR="/var/named"
DHCP_CONF="/etc/dhcp/dhcpd.conf"
INTERFAZ_INTERNA="enp0s8"

opcion_auto_sync() {
    echo "-------------------------------------------------"
    IP_SERVER=$(ip -4 addr show $INTERFAZ_INTERNA 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    if [ -z "$IP_SERVER" ]; then
        echo " No se detecto IP en $INTERFAZ_INTERNA." ; read -p "Enter..." ; return
    fi
    echo "nameserver $IP_SERVER" > /etc/resolv.conf
    chown root:named $CONF && chmod 640 $CONF
    restorecon -v $CONF &> /dev/null
    echo " Servidor sincronizado a la IP: $IP_SERVER"
    read -p "Presiona Enter..."
}

opcion_alta() {
    echo "-------------------------------------------------"
    read -p "Nombre del Dominio: " DOMINIO
    [ -z "$DOMINIO" ] && return

    read -p "IP para el dominio : " IP_DEST
    [ -z "$IP_DEST" ] && return

    ZONA_FILE="$ZONES_DIR/${DOMINIO}.zone"
    
    if grep -q "zone \"$DOMINIO\"" $CONF; then
        echo "[!] El dominio ya existe." ; read -p "Enter..." ; return
    fi

    echo -e "\nzone \"$DOMINIO\" IN {\n    type master;\n    file \"$ZONA_FILE\";\n    allow-update { none; };\n};" >> $CONF

    cat <<EOF | tr -d '\r' > $ZONA_FILE
\$TTL 86400
@ IN SOA ns1.$DOMINIO. admin.$DOMINIO. ($(date +%Y%m%d01) 3600 1800 604800 86400)
@ IN NS ns1.$DOMINIO.
ns1 IN A $IP_DEST
@ IN A $IP_DEST
www IN CNAME $DOMINIO.
EOF

    chown root:named $ZONA_FILE
    chmod 640 $ZONA_FILE
    restorecon -v $ZONA_FILE &> /dev/null

    if named-checkconf $CONF &> /dev/null; then
        systemctl restart named
        echo " Dominio $DOMINIO -> $IP_DEST listo."
    else
        echo " Error de sintaxis. Revisa el archivo $CONF"
    fi
    read -p "Enter..."
}

opcion_listar() {
    echo "-------------------------------------------------"
    echo "          DOMINIOS Y IPS CONFIGURADOS"
    echo "-------------------------------------------------"
    printf "%-25s | %-15s\n" "DOMINIO" "IP DESTINO"
    echo "-------------------------------------------------"
    for f in $ZONES_DIR/*.zone; do
        [ -e "$f" ] || continue
        [[ "$f" =~ (named.localhost|named.loopback|named.empty|named.ca) ]] && continue
        DOM=$(basename "$f" .zone)
        IP_Z=$(grep -E "\s+A\s+" "$f" | awk '{print $NF}' | tail -n1)
        printf "%-25s | %-15s\n" "$DOM" "$IP_Z"
    done
    echo "-------------------------------------------------"
    read -p "Presiona Enter para continuar..."
}

# --- MENU ---
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
        2) read -p "Dominio: " D; sed -i "/^zone \"$D\" IN {/,/^};/d" $CONF; rm -f $ZONES_DIR/$D.zone; systemctl restart named; echo "Borrado." ; read ;;
        3) opcion_listar ;;
        4) exit 0 ;;
    esac
done
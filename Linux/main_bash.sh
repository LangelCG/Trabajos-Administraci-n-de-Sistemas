#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Verifica root ────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Ejecuta este script como root (sudo)."
    exit 1
fi

# ─── Verifica que un script existe antes de lanzarlo ─────────────────────────
launch_script() {
    local file="$1"
    local path="${SCRIPT_DIR}/${file}"
    if [[ ! -f "$path" ]]; then
        echo -e "\n  ${RED}[ERROR]${NC} No se encontro el archivo: ${YELLOW}${file}${NC}"
        echo -e "  Asegurate de que todos los scripts esten en el mismo directorio."
        echo ""
        read -rp "  Presiona Enter para continuar..." _
        return 1
    fi
    bash "$path"
}

# ─── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo "=========================================="
    echo "     ADMINISTRACION DE SERVICIOS"
    echo "            CentOS 7 :3"
    echo "=========================================="
    echo ""
    echo -e "  Host : ${YELLOW}$(hostname)${NC}"
    echo -e "  IP   : ${YELLOW}$(hostname -I | awk '{print $1}')${NC}"
    echo -e "  Fecha: ${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo "------------------------------------------"
}

while true; do
    show_banner
    echo "  Selecciona el servicio a administrar:"
    echo ""
    echo "  1. DHCP"
    echo "  2. DNS"
    echo "  3. SSH"
    echo "  4. FTP"
    echo "  5. HTTP "
    echo "  0. Salir"
    echo "------------------------------------------"
    read -rp "  Selecciona: " OPT

    case "$OPT" in
        1) launch_script "dhcpBash.sh" ;;
        2) launch_script "dnsBash.sh" ;;
        3) launch_script "ssh.sh" ;;
        4) launch_script "ftp.sh" ;;
        5) launch_script "http.sh" ;;
        0)
            echo ""
            echo "  Saliendo... Hasta luego!"
            echo ""
            exit 0
            ;;
        *)
            echo -e "  ${YELLOW}[WARN]${NC}  Opcion invalida."
            sleep 1
            ;;
    esac
done
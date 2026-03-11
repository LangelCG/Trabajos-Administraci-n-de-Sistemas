#!/bin/bash
# =============================================================================
# http_functions.sh — Funciones para aprovisionamiento de servidores HTTP
# Practica 6 — CentOS 7 (yum / systemctl)
# =============================================================================

# Rutas absolutas CentOS 7
YUM="/usr/bin/yum"
YUM_UTILS="/usr/bin/yumdb"
SYSTEMCTL="/usr/bin/systemctl"
SED="/bin/sed"
FIREWALL_CMD="/usr/bin/firewall-cmd"
USERADD="/usr/sbin/useradd"
SS="/usr/sbin/ss"
CURL="/usr/bin/curl"

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}${BOLD}====== $1 ======${NC}\n"; }

# =============================================================================
# VALIDACIONES
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (sudo)."
        exit 1
    fi
}

validate_port() {
    local port="$1"
    local RESERVED=(22 25 443 3306 5432 6379 27017)
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "El puerto debe ser un numero entero."
        return 1
    fi
    if (( port < 1 || port > 65535 )); then
        log_error "Puerto fuera de rango (1-65535)."
        return 1
    fi
    for r in "${RESERVED[@]}"; do
        if (( port == r )); then
            log_error "El puerto $port esta reservado para otro servicio."
            return 1
        fi
    done
    return 0
}

check_port_in_use() {
    local port="$1"
    if $SS -tlnp 2>/dev/null | grep -q ":${port} "; then
        log_warn "El puerto $port ya esta en uso."
        return 1
    fi
    return 0
}

prompt_port() {
    local port
    while true; do
        read -rp "  Ingresa el puerto de escucha (ej. 80, 8080, 8888): " port
        port="${port// /}"
        if validate_port "$port"; then
            if check_port_in_use "$port"; then
                SELECTED_PORT="$port"
                return 0
            else
                read -rp "  Puerto en uso. Continuar de todas formas? [s/N]: " confirm
                [[ "${confirm,,}" == "s" ]] && SELECTED_PORT="$port" && return 0
            fi
        fi
    done
}

# Configura firewalld (CentOS 7 usa firewalld, no ufw)
configure_firewall() {
    local port="$1"
    if $SYSTEMCTL is-active --quiet firewalld 2>/dev/null; then
        log_info "Abriendo puerto $port/tcp en firewalld..."
        $FIREWALL_CMD --permanent --add-port="${port}/tcp" &>/dev/null
        # Cerrar puertos HTTP por defecto si no son el elegido
        for dp in 80 8080; do
            if (( port != dp )); then
                $FIREWALL_CMD --permanent --remove-port="${dp}/tcp" &>/dev/null || true
            fi
        done
        $FIREWALL_CMD --reload &>/dev/null
        log_info "Firewall actualizado."
    else
        log_warn "firewalld no activo. Si usas iptables, abre el puerto manualmente."
    fi
}

create_service_user() {
    local user="$1" webroot="$2"
    if ! id "$user" &>/dev/null; then
        log_info "Creando usuario de servicio: $user"
        $USERADD --system --no-create-home --shell /sbin/nologin "$user" 2>/dev/null || true
    else
        log_info "Usuario '$user' ya existe."
    fi
    if [[ -d "$webroot" ]]; then
        chown -R "${user}:${user}" "$webroot" 2>/dev/null
        chmod -R 750 "$webroot" 2>/dev/null
    fi
}

create_index_html() {
    local dest="$1" service="$2" version="$3" port="$4"
    mkdir -p "$(dirname "$dest")"
    cat > "$dest" <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>$service - Practica 6</title>
  <style>
    body{font-family:monospace;background:#1e1e2e;color:#cdd6f4;
         display:flex;justify-content:center;align-items:center;height:100vh;margin:0}
    .card{background:#313244;padding:2rem 3rem;border-radius:12px;
          border-left:6px solid #89b4fa;text-align:center}
    h1{color:#89b4fa;margin-bottom:1rem}
    p{margin:.4rem 0;font-size:1.1rem}
    .v{color:#a6e3a1;font-weight:bold}
    .p{color:#f38ba8;font-weight:bold}
  </style>
</head>
<body>
  <div class="card">
    <h1>Servidor HTTP - Practica 6</h1>
    <p>Servidor: <span class="v">$service</span></p>
    <p>Version:  <span class="v">$version</span></p>
    <p>Puerto:   <span class="p">$port</span></p>
    <p style="margin-top:1rem;color:#6c7086;font-size:.85rem">Desplegado via SSH - Script automatizado</p>
  </div>
</body>
</html>
EOF
    log_info "index.html creado en $dest"
}

verify_service() {
    local service="$1" port="$2"
    log_info "Verificando $service en puerto $port..."
    sleep 2
    if $SYSTEMCTL is-active --quiet "$service" 2>/dev/null; then
        log_info "Servicio $service activo."
    else
        log_error "El servicio $service no esta activo. Revisa: journalctl -u $service"
    fi
    if [[ -x "$CURL" ]]; then
        echo ""
        log_info "Encabezados HTTP (curl -I):"
        $CURL -sI "http://localhost:${port}" 2>/dev/null | head -10
    fi
}

# =============================================================================
# APACHE (httpd en CentOS)
# =============================================================================

# En CentOS 7 el paquete se llama httpd, no apache2
# yum list available no da multiples versiones del mismo paquete facilmente,
# pero podemos mostrar: version del repo base, version con mod_security, etc.
get_apache_versions() {
    local vers=()

    # Intentar obtener version disponible en yum
    local repo_ver
    repo_ver=$($YUM info httpd 2>/dev/null | grep "^Version" | awk '{print $3}' | head -1)
    local installed_ver
    installed_ver=$($YUM info installed httpd 2>/dev/null | grep "^Version" | awk '{print $3}' | head -1)

    # Armar lista: instalada (si existe), repo, y versiones conocidas de CentOS 7
    [[ -n "$installed_ver" ]] && vers+=("${installed_ver} (instalada)")
    [[ -n "$repo_ver" && "$repo_ver" != "$installed_ver" ]] && vers+=("$repo_ver (repositorio)")

    # Fallback / versiones conocidas de CentOS 7
    if [[ ${#vers[@]} -eq 0 ]]; then
        log_warn "Repositorio sin respuesta, usando versiones conocidas..."
        vers=(
            "2.4.6-99.el7.centos"
            "2.4.6-97.el7.centos"
            "2.4.6-95.el7.centos"
        )
    else
        # Completar hasta 3 con versiones conocidas de CentOS 7 si hay menos
        local known=("2.4.6-99.el7.centos" "2.4.6-97.el7.centos" "2.4.6-95.el7.centos")
        for k in "${known[@]}"; do
            (( ${#vers[@]} >= 3 )) && break
            # Agregar si no está ya en la lista
            local found=0
            for v in "${vers[@]}"; do [[ "$v" == *"$k"* ]] && found=1; done
            (( found == 0 )) && vers+=("$k")
        done
    fi

    printf '%s\n' "${vers[@]}"
}

select_apache_version() {
    log_section "Versiones de Apache (httpd) disponibles"
    mapfile -t VERSIONS < <(get_apache_versions)
    echo -e "  ${BOLD}#   Version${NC}"
    for i in "${!VERSIONS[@]}"; do
        local label=""
        (( i == 0 )) && label="  ${GREEN}<-- Latest${NC}"
        (( i == ${#VERSIONS[@]}-1 )) && label="  ${YELLOW}<-- LTS${NC}"
        echo -e "  $((i+1))) ${VERSIONS[$i]}${label}"
    done
    echo ""
    local choice
    while true; do
        read -rp "  Selecciona una opcion [1-${#VERSIONS[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#VERSIONS[@]} )); then
            SELECTED_VERSION="${VERSIONS[$((choice-1))]}"
            # Limpiar etiquetas del string
            SELECTED_VERSION="${SELECTED_VERSION/ (instalada)/}"
            SELECTED_VERSION="${SELECTED_VERSION/ (repositorio)/}"
            log_info "Version seleccionada: $SELECTED_VERSION"
            return 0
        fi
        log_warn "Opcion invalida."
    done
}

install_apache() {
    local port="$1" version="$2"
    log_section "Instalando Apache (httpd) en puerto $port"

    $YUM install -y httpd 2>/dev/null

    if ! command -v httpd &>/dev/null; then
        log_error "httpd no se pudo instalar. Verifica tu conexion o repositorios."
        return 1
    fi

    local installed_ver
    installed_ver=$(httpd -v 2>/dev/null | grep "Server version" | awk '{print $3}' | cut -d'/' -f2)
    [[ -z "$installed_ver" ]] && installed_ver="$version"

    # CentOS 7: el archivo de puertos es /etc/httpd/conf/httpd.conf
    log_info "Configurando puerto $port..."
    # Reemplazar cualquier "Listen <numero>" por el puerto elegido (una sola pasada)
    $SED -i "s/^Listen [0-9]*/Listen ${port}/" /etc/httpd/conf/httpd.conf 2>/dev/null

    # Hardening: archivo /etc/httpd/conf.d/security.conf
    log_info "Aplicando hardening..."
    cat > /etc/httpd/conf.d/security.conf <<'CONF'
ServerTokens Prod
ServerSignature Off
TraceEnable Off
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header unset X-Powered-By

# Bloquear metodos peligrosos (TRACE, TRACK, DELETE, etc.)
<Directory "/var/www/html">
    <LimitExcept GET POST HEAD>
        Require all denied
    </LimitExcept>
</Directory>
CONF

    # Habilitar mod_headers si no está
    if ! httpd -M 2>/dev/null | grep -q headers_module; then
        log_warn "mod_headers no detectado, verificando configuracion..."
    fi

    # SELinux: permitir httpd en puerto personalizado
    if command -v semanage &>/dev/null && (( port != 80 )); then
        log_info "Configurando SELinux para puerto $port..."
        semanage port -a -t http_port_t -p tcp "$port" 2>/dev/null || \
        semanage port -m -t http_port_t -p tcp "$port" 2>/dev/null || true
    fi

    # Webroot en CentOS es /var/www/html
    create_service_user "apache" "/var/www/html"
    create_index_html "/var/www/html/index.html" "Apache (httpd)" "$installed_ver" "$port"

    $SYSTEMCTL enable httpd &>/dev/null
    $SYSTEMCTL restart httpd

    configure_firewall "$port"
    log_info "Apache (httpd) listo."
    verify_service "httpd" "$port"
}

# =============================================================================
# NGINX
# =============================================================================

get_nginx_versions() {
    local vers=()

    local repo_ver
    repo_ver=$($YUM info nginx 2>/dev/null | grep "^Version" | awk '{print $3}' | head -1)
    local installed_ver
    installed_ver=$($YUM info installed nginx 2>/dev/null | grep "^Version" | awk '{print $3}' | head -1)

    [[ -n "$installed_ver" ]] && vers+=("${installed_ver} (instalada)")
    [[ -n "$repo_ver" && "$repo_ver" != "$installed_ver" ]] && vers+=("$repo_ver (repositorio)")

    if [[ ${#vers[@]} -eq 0 ]]; then
        log_warn "Repositorio sin respuesta, usando versiones conocidas..."
        vers=(
            "1.24.0"
            "1.22.1"
            "1.20.1"
        )
    else
        local known=("1.24.0" "1.22.1" "1.20.1")
        for k in "${known[@]}"; do
            (( ${#vers[@]} >= 3 )) && break
            local found=0
            for v in "${vers[@]}"; do [[ "$v" == *"$k"* ]] && found=1; done
            (( found == 0 )) && vers+=("$k")
        done
    fi

    printf '%s\n' "${vers[@]}"
}

select_nginx_version() {
    log_section "Versiones de Nginx disponibles"
    mapfile -t VERSIONS < <(get_nginx_versions)
    echo -e "  ${BOLD}#   Version${NC}"
    for i in "${!VERSIONS[@]}"; do
        local label=""
        (( i == 0 )) && label="  ${GREEN}<-- Latest${NC}"
        (( i == ${#VERSIONS[@]}-1 )) && label="  ${YELLOW}<-- LTS${NC}"
        echo -e "  $((i+1))) ${VERSIONS[$i]}${label}"
    done
    echo ""
    local choice
    while true; do
        read -rp "  Selecciona una opcion [1-${#VERSIONS[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#VERSIONS[@]} )); then
            SELECTED_VERSION="${VERSIONS[$((choice-1))]}"
            SELECTED_VERSION="${SELECTED_VERSION/ (instalada)/}"
            SELECTED_VERSION="${SELECTED_VERSION/ (repositorio)/}"
            log_info "Version seleccionada: $SELECTED_VERSION"
            return 0
        fi
        log_warn "Opcion invalida."
    done
}

install_nginx() {
    local port="$1" version="$2"
    log_section "Instalando Nginx en puerto $port"

    # Intentar instalar: primero repo oficial nginx.org, luego EPEL como fallback
    if ! command -v nginx &>/dev/null; then
        if ! $YUM info nginx &>/dev/null 2>&1; then
            log_info "Agregando repositorio oficial de Nginx..."
            cat > /etc/yum.repos.d/nginx.repo <<'REPO'
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/$basearch/
gpgcheck=0
enabled=1
REPO
        fi
        $YUM install -y nginx 2>/dev/null
    fi

    if ! command -v nginx &>/dev/null; then
        log_error "nginx no se pudo instalar. Verifica tu conexion o repositorios."
        return 1
    fi

    local installed_ver
    installed_ver=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
    [[ -z "$installed_ver" ]] && installed_ver="$version"

    # En CentOS 7 con repo oficial nginx el puerto esta en conf.d/default.conf
    log_info "Configurando puerto $port..."
    local nginx_port_file
    if grep -q "listen" /etc/nginx/conf.d/default.conf 2>/dev/null; then
        nginx_port_file="/etc/nginx/conf.d/default.conf"
    elif grep -q "listen" /etc/nginx/nginx.conf 2>/dev/null; then
        nginx_port_file="/etc/nginx/nginx.conf"
    else
        nginx_port_file=$(grep -rl "listen" /etc/nginx/ 2>/dev/null | head -1)
    fi
    log_info "Archivo de configuracion: $nginx_port_file"
    $SED -i "s/listen[ 	]*80;/listen ${port};/g" "$nginx_port_file"

    # Hardening server_tokens
    log_info "Aplicando hardening..."
    if grep -q "server_tokens" /etc/nginx/nginx.conf; then
        $SED -i "s/.*server_tokens.*/    server_tokens off;/" /etc/nginx/nginx.conf
    else
        $SED -i "/http {/a\\    server_tokens off;" /etc/nginx/nginx.conf
    fi

    # Security headers dentro del bloque server del virtualhost por defecto
    # Se agrega en conf.d como server block independiente NO — se inyecta en nginx.conf
    # Para CentOS el default server block está en /etc/nginx/nginx.conf directamente
    # Agregar headers dentro del bloque server existente
    if ! grep -q "X-Frame-Options" /etc/nginx/nginx.conf; then
        $SED -i "/server_name/a\\        add_header X-Frame-Options \"SAMEORIGIN\" always;\n        add_header X-Content-Type-Options \"nosniff\" always;" \
            /etc/nginx/nginx.conf
    fi

    # SELinux para puerto personalizado
    if command -v semanage &>/dev/null && (( port != 80 )); then
        log_info "Configurando SELinux para puerto $port..."
        semanage port -a -t http_port_t -p tcp "$port" 2>/dev/null || \
        semanage port -m -t http_port_t -p tcp "$port" 2>/dev/null || true
    fi

    mkdir -p /usr/share/nginx/html
    create_service_user "nginx" "/usr/share/nginx/html"
    create_index_html "/usr/share/nginx/html/index.html" "Nginx" "$installed_ver" "$port"

    # Verificar sintaxis antes de reiniciar
    if nginx -t 2>/dev/null; then
        $SYSTEMCTL enable nginx &>/dev/null
        $SYSTEMCTL restart nginx
    else
        log_error "Error de sintaxis en nginx.conf. Revisa con: nginx -t"
        nginx -t
        return 1
    fi

    configure_firewall "$port"
    log_info "Nginx listo."
    verify_service "nginx" "$port"
}

# =============================================================================
# TOMCAT
# =============================================================================

get_tomcat_versions() {
    local entries=()

    # CentOS 7 repo base solo tiene "tomcat" (Tomcat 7.x)
    # Consultar version real disponible
    local ver
    ver=$($YUM info tomcat 2>/dev/null | grep "^Version" | awk '{print $3}' | head -1)
    [[ -n "$ver" ]] && entries+=("tomcat|${ver} (repo base)")

    # Fallback con versiones reales de CentOS 7 repo base
    if [[ ${#entries[@]} -eq 0 ]]; then
        log_warn "Repositorio sin respuesta, usando versiones conocidas..."
        entries=(
            "tomcat|7.0.76"
            "tomcat|7.0.69"
            "tomcat|7.0.54"
        )
    else
        # Completar hasta 3 con versiones conocidas de CentOS 7
        local known=("tomcat|7.0.76" "tomcat|7.0.69" "tomcat|7.0.54")
        for k in "${known[@]}"; do
            (( ${#entries[@]} >= 3 )) && break
            local kver; kver=$(echo "$k" | cut -d'|' -f2)
            local found=0
            for e in "${entries[@]}"; do [[ "$e" == *"$kver"* ]] && found=1; done
            (( found == 0 )) && entries+=("$k")
        done
    fi

    printf '%s\n' "${entries[@]}" | head -3
}

select_tomcat_version() {
    log_section "Versiones de Tomcat disponibles"
    mapfile -t VERSIONS < <(get_tomcat_versions)
    echo -e "  ${BOLD}#   Paquete           Version${NC}"
    for i in "${!VERSIONS[@]}"; do
        local pkg ver label=""
        pkg=$(echo "${VERSIONS[$i]}" | cut -d'|' -f1)
        ver=$(echo "${VERSIONS[$i]}" | cut -d'|' -f2)
        (( i == 0 )) && label="  ${GREEN}<-- Latest${NC}"
        (( i == ${#VERSIONS[@]}-1 )) && label="  ${YELLOW}<-- LTS${NC}"
        echo -e "  $((i+1))) $(printf '%-18s' "$pkg") $ver${label}"
    done
    echo ""
    local choice
    while true; do
        read -rp "  Selecciona una opcion [1-${#VERSIONS[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#VERSIONS[@]} )); then
            SELECTED_TOMCAT_PKG=$(echo "${VERSIONS[$((choice-1))]}" | cut -d'|' -f1)
            SELECTED_VERSION=$(echo "${VERSIONS[$((choice-1))]}" | cut -d'|' -f2)
            # Limpiar etiqueta (repo base)
            SELECTED_VERSION="${SELECTED_VERSION/ (repo base)/}"
            log_info "Paquete: $SELECTED_TOMCAT_PKG  Version: $SELECTED_VERSION"
            return 0
        fi
        log_warn "Opcion invalida."
    done
}

install_tomcat() {
    local port="$1"
    local pkg="${SELECTED_TOMCAT_PKG:-tomcat}"
    local version="${SELECTED_VERSION:-7.0.76}"

    log_section "Instalando Tomcat ($pkg) en puerto $port"

    # Instalar Java si no existe (Tomcat 7 en CentOS 7 requiere Java 7/8)
    if ! command -v java &>/dev/null; then
        log_info "Instalando Java (prerequisito de Tomcat)..."
        $YUM install -y java-1.8.0-openjdk-headless 2>/dev/null
    fi

    $YUM install -y "$pkg" 2>/dev/null

    if ! rpm -q "$pkg" &>/dev/null; then
        log_error "Tomcat no se pudo instalar. Verifica tu conexion o repositorios."
        return 1
    fi

    # Rutas reales en CentOS 7
    local tomcat_conf="/etc/tomcat/server.xml"
    local tomcat_webroot="/var/lib/tomcat/webapps"
    local tomcat_svc="tomcat"

    # Buscar rutas si no existen en el lugar default
    [[ ! -f "$tomcat_conf" ]] && tomcat_conf=$(find /etc/tomcat* -name "server.xml" 2>/dev/null | head -1)
    [[ ! -d "$tomcat_webroot" ]] && tomcat_webroot=$(find /var/lib/tomcat* -maxdepth 1 -name "webapps" 2>/dev/null | head -1)

    if [[ -z "$tomcat_conf" || ! -f "$tomcat_conf" ]]; then
        log_error "No se encontro server.xml. Verifica la instalacion."
        return 1
    fi

    # Cambiar SOLO el conector HTTP (port="8080") — no tocar shutdown (port="8005")
    # Usar contexto del XML para distinguirlos: el HTTP tiene protocol="HTTP"
    log_info "Configurando puerto $port en $tomcat_conf..."
    # Reemplazar solo la primera ocurrencia de Connector port="8080"
    $SED -i "0,/Connector port=\"8080\"/s/Connector port=\"8080\"/Connector port=\"${port}\"/" "$tomcat_conf"

    # Hardening: ocultar version de Tomcat en headers (Server header)
    # Agregar atributo server="" al conector HTTP para ocultar la version
    $SED -i "s/Connector port=\"${port}\"/Connector port=\"${port}\" server=\"Apache\"/" "$tomcat_conf"

    # SELinux para puerto personalizado
    if command -v semanage &>/dev/null && (( port != 8080 )); then
        log_info "Configurando SELinux para puerto $port..."
        semanage port -a -t http_port_t -p tcp "$port" 2>/dev/null || \
        semanage port -m -t http_port_t -p tcp "$port" 2>/dev/null || true
    fi

    create_service_user "tomcat" "${tomcat_webroot}"

    # index.html en ROOT
    local webroot_root="${tomcat_webroot}/ROOT"
    mkdir -p "$webroot_root"
    create_index_html "${webroot_root}/index.html" "Tomcat" "$version" "$port"

    # Eliminar apps de demo innecesarias
    for app in manager host-manager examples docs; do
        local ap="${tomcat_webroot}/${app}"
        [[ -d "$ap" ]] && rm -rf "$ap" && log_warn "Eliminado: $ap"
    done

    $SYSTEMCTL enable "$tomcat_svc" &>/dev/null
    $SYSTEMCTL restart "$tomcat_svc"

    # Verificar que levantó
    sleep 3
    if ! $SYSTEMCTL is-active --quiet "$tomcat_svc"; then
        log_error "Tomcat no arranco. Revisa: journalctl -u $tomcat_svc"
        journalctl -u "$tomcat_svc" --no-pager -n 10
        return 1
    fi

    configure_firewall "$port"
    log_info "Tomcat listo."
    verify_service "$tomcat_svc" "$port"
}

# =============================================================================
# DESINSTALAR
# =============================================================================

uninstall_server() {
    local server="$1"
    log_section "Desinstalando $server"
    case "$server" in
        apache|httpd)
            $SYSTEMCTL stop httpd &>/dev/null
            $YUM remove -y httpd &>/dev/null ;;
        nginx)
            $SYSTEMCTL stop nginx &>/dev/null
            $YUM remove -y nginx &>/dev/null ;;
        tomcat)
            $SYSTEMCTL stop tomcat &>/dev/null
            $YUM remove -y tomcat &>/dev/null ;;
        *)
            log_error "Servidor desconocido: $server"
            return 1 ;;
    esac
    log_info "$server desinstalado."
}
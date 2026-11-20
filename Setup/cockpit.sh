#!/usr/bin/env bash
# ==============================================================================
# cockpit.sh - Gestor y Optimizador de Cockpit Web Console y Cliente de Escritorio
# Sistema: Golden Dog Linux (Debian 13 Trixie) | Escritorio: KDE Plasma Wayland
# Preinstalados en Golden Dog Linux: Cockpit base + UFW (Puerto 9090)
# Integración: Podman Rootless + KVM/QEMU Libvirt + NetworkManager + Btrfs/Ext4
# ==============================================================================
# Características:
# - Verifica la instalación base preinstalada en Golden Dog Linux e instala de
#   forma idempotente los módulos complementarios (Podman, Files, Sosreport).
# - Modo idempotente sin privilegios innecesarios: no solicita sudo si los
#   paquetes, /etc/cockpit/cockpit.conf, el socket y UFW ya están listos.
# - Optimizado para batería de portátil: activación bajo demanda mediante
#   cockpit.socket y cierre automático por inactividad (IdleTimeout=15).
# - Orígenes seguros en /etc/cockpit/cockpit.conf (localhost, hostname, .local y LAN).
# - Diagnóstico 100% no privilegiado (sin sudo) de socket, servicios, módulos y UFW.
# - Control granular del ciclo de vida: --start, --stop, --restart, --disable, --open, --client.
# ==============================================================================

set -euo pipefail

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="${USER:-$(id -un)}"
    USER_HOME="${HOME:-/home/$REAL_USER}"
fi

if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")

# Paquetes base preinstalados en Golden Dog Linux
PREINSTALLED_PACKAGES=(
    "cockpit"
    "cockpit-bridge"
    "cockpit-ws"
    "cockpit-system"
    "cockpit-machines"
    "cockpit-storaged"
    "cockpit-networkmanager"
    "cockpit-packagekit"
)

# Módulos complementarios recomendados
EXTRA_PACKAGES=(
    "cockpit-podman"
    "cockpit-files"
    "cockpit-sosreport"
)

ALL_PACKAGES=("${PREINSTALLED_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}")

COCKPIT_CONF="/etc/cockpit/cockpit.conf"

run_as_user() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$REAL_UID}"
    local dbus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime_dir/bus}"
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        sudo -u "$REAL_USER" env \
            HOME="$USER_HOME" \
            USER="$REAL_USER" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            ${DISPLAY:+DISPLAY="$DISPLAY"} \
            ${WAYLAND_DISPLAY:+WAYLAND_DISPLAY="$WAYLAND_DISPLAY"} \
            ${XDG_CURRENT_DESKTOP:+XDG_CURRENT_DESKTOP="$XDG_CURRENT_DESKTOP"} \
            "$@"
    else
        env \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            "$@"
    fi
}

require_root() {
    if [ "$EUID" -ne 0 ] && ! command -v sudo &>/dev/null; then
        echo "❌ Error: Esta operación requiere privilegios de administrador ('sudo')."
        exit 1
    fi
}

# Devuelve la IP IPv4 principal de red local (o cadena vacía si no hay)
get_host_ip() {
    local ip_addr
    ip_addr=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' || true)
    if [ -z "$ip_addr" ]; then
        ip_addr=$(hostname -I 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i !~ /^127\./ && $i !~ /^169\.254\./) {print $i; exit}}' || true)
    fi
    if [ -n "$ip_addr" ] && [ "$ip_addr" != "127.0.0.1" ]; then
        echo "$ip_addr"
    fi
}

# Obtiene los paquetes instalados del conjunto dado en una sola llamada a dpkg-query
get_installed_packages_map() {
    dpkg-query -W -f='${Package}\t${db:Status-Status}\n' "${ALL_PACKAGES[@]}" 2>/dev/null || true
}

is_pkg_installed() {
    local pkg="$1"
    local pkg_map="$2"
    grep -qx "${pkg}"$'\t'"installed" <<< "$pkg_map"
}

# Genera el contenido esperado de /etc/cockpit/cockpit.conf
build_cockpit_conf() {
    local host_ip short_host fqdn_host
    host_ip=$(get_host_ip)
    short_host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
    fqdn_host=$(hostname -f 2>/dev/null || true)

    local origins=("https://localhost:9090" "https://127.0.0.1:9090")
    local candidate origin_exists
    for candidate in "$short_host" "${short_host:+${short_host}.local}" "$fqdn_host" "$host_ip"; do
        [ -z "$candidate" ] && continue
        [ "$candidate" = "localhost" ] && continue
        [ "$candidate" = "127.0.0.1" ] && continue
        local url="https://${candidate}:9090"
        origin_exists=0
        for existing in "${origins[@]}"; do
            if [ "$existing" = "$url" ]; then
                origin_exists=1
                break
            fi
        done
        if [ "$origin_exists" -eq 0 ]; then
            origins+=("$url")
        fi
    done

    cat <<EOF
# Configuración optimizada de Cockpit para Golden Dog Linux (Debian Workstation)
[WebService]
Origins = ${origins[*]}
MaxStartups = 5
AllowUnencrypted = false

[Session]
# Cierre automático de sesión tras 15 minutos de inactividad para preservar batería y memoria
IdleTimeout = 15
EOF
}

show_help() {
    cat <<EOF
🎛️ Gestor de Cockpit Web Console - Golden Dog Linux (Debian Workstation)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)    Verifica Cockpit preinstalado, añade módulos extra y optimiza la configuración.
  --status, -s        Muestra diagnóstico completo (sin pedir sudo) de socket, módulos y red.
  --open, -o          Abre Cockpit en el navegador web predeterminado (https://localhost:9090).
  --client, -c        Lanza Cockpit Client (Flatpak o nativo) si está disponible, o abre el navegador.
  --start             Inicia manualmente el socket bajo demanda de Cockpit.
  --stop              Detiene el servicio y socket de Cockpit (libera memoria y CPU).
  --restart           Reinicia el socket y servicio de Cockpit.
  --disable           Deshabilita permanentemente el socket de Cockpit.
  --help, -h          Muestra este mensaje de ayuda.

CARACTERÍSTICAS Y EFICIENCIA EN PORTÁTILES:
  • Base preinstalada: Cockpit y el puerto 9090/tcp en UFW ya vienen integrados en Golden Dog Linux.
  • Cero consumo en reposo: Activación bajo demanda por socket de systemd (cockpit.socket).
    El servicio web solo despierta cuando un cliente se conecta al puerto 9090.
  • Ahorro de batería: Configuración con IdleTimeout=15 para cerrar sesiones inactivas.
  • Gestión completa de Podman Rootless: Módulo cockpit-podman integrado con quadlets.
  • Control de VMs KVM/QEMU: Módulo cockpit-machines con almacenamiento y redes virtuales.
  • Telemetría de hardware NVMe & RAM: Módulo cockpit-storaged con soporte SMART y ZRAM.
EOF
}

show_status() {
    echo "================================================================="
    echo "🔍 ESTADO DE COCKPIT WEB CONSOLE - GOLDEN DOG LINUX"
    echo "================================================================="

    local socket_status ws_status port_listening
    socket_status=$(systemctl is-active cockpit.socket 2>/dev/null || echo "inactivo")
    ws_status=$(systemctl is-active cockpit.service 2>/dev/null || echo "inactivo")
    if ss -tlnH sport = :9090 2>/dev/null | grep -q .; then
        port_listening=1
    else
        port_listening=0
    fi

    echo "• Socket de Cockpit (Systemd): $(if [ "$socket_status" = "active" ]; then echo "✅ Activo (bajo demanda / 0% CPU en reposo)"; else echo "❌ Inactivo"; fi)"
    echo "• Servicio Web (cockpit.ws):   $(if [ "$ws_status" = "active" ]; then echo "🟢 En ejecución"; else echo "⚪ Inactivo (se activará al conectar)"; fi)"
    echo "• Puerto 9090 (TCP):           $(if [ "$port_listening" -eq 1 ]; then echo "✅ Escuchando"; else echo "❌ No detectado"; fi)"

    if [ -f "$COCKPIT_CONF" ] && grep -qE '^\s*IdleTimeout\s*=\s*15\b' "$COCKPIT_CONF" 2>/dev/null; then
        echo "• Perfil Portátil (cockpit.conf): ✅ Optimizado (IdleTimeout=15 min)"
    elif [ -f "$COCKPIT_CONF" ]; then
        echo "• Perfil Portátil (cockpit.conf): ⚠️ Personalizado (sin IdleTimeout=15)"
    else
        echo "• Perfil Portátil (cockpit.conf): ℹ️ Configuración de fábrica (ejecuta 'just cockpit' para optimizar)"
    fi

    echo "-----------------------------------------------------------------"
    echo "• Cortafuegos y Red (UFW):"
    if systemctl is-active --quiet ufw 2>/dev/null; then
        echo "  - Estado de UFW:             ✅ Activo"
        if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
            if LC_ALL=C $SUDO ufw status 2>/dev/null | grep -qE "9090(/tcp)?\s+ALLOW"; then
                echo "  - Puerto 9090 (Cockpit):     ✅ Permitido en UFW"
            else
                echo "  - Puerto 9090 (Cockpit):     ⚠️ No encontrado en reglas UFW"
            fi
        else
            echo "  - Puerto 9090 (Cockpit):     ℹ️ Comprobable con: sudo ufw status"
        fi
    else
        echo "  - Estado de UFW:             ℹ️ Inactivo o no instalado"
    fi

    echo "-----------------------------------------------------------------"
    echo "• Integraciones de Contenedores y Virtualización:"
    local podman_user_socket="ℹ️ Podman no instalado"
    if command -v podman &>/dev/null; then
        if [ "$(run_as_user systemctl --user is-active podman.socket 2>/dev/null || true)" = "active" ]; then
            podman_user_socket="✅ Activo (Rootless)"
        else
            podman_user_socket="ℹ️ Inactivo (se activa con 'systemctl --user enable --now podman.socket')"
        fi
    fi
    echo "  - Socket Podman Rootless:    $podman_user_socket"

    local libvirt_status="❌ Inactivo"
    if systemctl is-active --quiet libvirtd 2>/dev/null || systemctl is-active --quiet libvirtd.socket 2>/dev/null; then
        libvirt_status="✅ Activo (libvirtd)"
    elif systemctl is-active --quiet virtqemud 2>/dev/null || systemctl is-active --quiet virtqemud.socket 2>/dev/null; then
        libvirt_status="✅ Activo (virtqemud modular)"
    fi
    echo "  - Hipervisor KVM/Libvirt:    $libvirt_status"

    local pkg_map
    pkg_map=$(get_installed_packages_map)

    echo "-----------------------------------------------------------------"
    echo "• Módulos Base (preinstalados en Golden Dog Linux):"
    for pkg in "${PREINSTALLED_PACKAGES[@]}"; do
        if is_pkg_installed "$pkg" "$pkg_map"; then
            printf "  - %-26s ✅ Instalado\n" "$pkg"
        else
            printf "  - %-26s ❌ No instalado\n" "$pkg"
        fi
    done

    echo "• Módulos Complementarios:"
    for pkg in "${EXTRA_PACKAGES[@]}"; do
        if is_pkg_installed "$pkg" "$pkg_map"; then
            printf "  - %-26s ✅ Instalado\n" "$pkg"
        else
            printf "  - %-26s ⚪ Opcional no instalado (ejecuta 'just cockpit')\n" "$pkg"
        fi
    done

    echo "================================================================="
    local host_ip
    host_ip=$(get_host_ip)
    echo "🌐 URL de acceso local:       https://localhost:9090"
    if [ -n "$host_ip" ]; then
        echo "🌐 URL en red local (LAN):   https://$host_ip:9090"
    fi
    echo "💡 Inicia sesión con tus credenciales de usuario de Debian ($REAL_USER)."
    echo "================================================================="
}

ensure_socket_active() {
    if ! systemctl is-active --quiet cockpit.socket 2>/dev/null; then
        echo "ℹ️ El socket de Cockpit está inactivo. Activándolo bajo demanda..."
        start_cockpit
    fi
}

open_browser() {
    ensure_socket_active
    echo "🌐 Abriendo Cockpit en el navegador web..."
    if command -v xdg-open &>/dev/null; then
        nohup run_as_user xdg-open "https://localhost:9090" >/dev/null 2>&1 &
    else
        echo "Accede manualmente a: https://localhost:9090"
    fi
}

launch_client() {
    ensure_socket_active
    echo "🖥️ Comprobando cliente de escritorio para Cockpit..."
    if command -v cockpit-client &>/dev/null; then
        echo "▶️ Lanzando cockpit-client nativo..."
        nohup run_as_user cockpit-client localhost >/dev/null 2>&1 &
    elif command -v flatpak &>/dev/null && flatpak info org.cockpit_project.CockpitClient &>/dev/null; then
        echo "▶️ Lanzando Cockpit Client vía Flatpak..."
        nohup run_as_user flatpak run org.cockpit_project.CockpitClient localhost >/dev/null 2>&1 &
    else
        echo "ℹ️ Cliente de escritorio no instalado. Abriendo en el navegador web predeterminado..."
        open_browser
    fi
}

start_cockpit() {
    require_root
    echo "▶️ Iniciando Cockpit socket bajo demanda..."
    $SUDO systemctl enable --now cockpit.socket
    echo "✅ Cockpit socket activo en puerto 9090."
}

stop_cockpit() {
    require_root
    echo "⏹️ Deteniendo Cockpit (liberando recursos del sistema)..."
    $SUDO systemctl stop cockpit.service cockpit.socket 2>/dev/null || true
    echo "✅ Cockpit detenido."
}

restart_cockpit() {
    require_root
    echo "🔄 Reiniciando Cockpit socket y servicio..."
    $SUDO systemctl restart cockpit.socket 2>/dev/null || true
    $SUDO systemctl stop cockpit.service 2>/dev/null || true
    echo "✅ Cockpit reiniciado correctamente."
}

disable_cockpit() {
    require_root
    echo "🛑 Deshabilitando Cockpit..."
    $SUDO systemctl disable --now cockpit.socket cockpit.service 2>/dev/null || true
    echo "✅ Cockpit deshabilitado."
}

case "${1:-}" in
    "")
        ;;
    --status|-s|status)
        show_status
        exit 0
        ;;
    --open|-o)
        open_browser
        exit 0
        ;;
    --client|-c)
        launch_client
        exit 0
        ;;
    --start)
        start_cockpit
        exit 0
        ;;
    --stop)
        stop_cockpit
        exit 0
        ;;
    --restart)
        restart_cockpit
        exit 0
        ;;
    --disable)
        disable_cockpit
        exit 0
        ;;
    --help|-h|help)
        show_help
        exit 0
        ;;
    *)
        echo "❌ Opción desconocida: $1"
        echo ""
        show_help
        exit 1
        ;;
esac

echo "================================================================="
echo "🎛️ VERIFICANDO Y OPTIMIZANDO COCKPIT (GOLDEN DOG LINUX)"
echo "================================================================="

# 1. Identificar e instalar paquetes faltantes de forma idempotente
PKG_MAP=$(get_installed_packages_map)
MISSING_PKGS=()
for pkg in "${ALL_PACKAGES[@]}"; do
    if ! is_pkg_installed "$pkg" "$PKG_MAP"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    require_root
    echo "ℹ️ [1/4] Instalando ${#MISSING_PKGS[@]} paquete(s) faltante(s): ${MISSING_PKGS[*]}..."
    $SUDO apt-get update -qq
    $SUDO apt-get install -y "${MISSING_PKGS[@]}"
else
    echo "ℹ️ [1/4] Cockpit base y módulos complementarios ya están instalados."
fi

# 2. Configuración optimizada de Cockpit para portátiles y acceso en red local (LAN)
echo "ℹ️ [2/4] Verificando optimizaciones de rendimiento y sesión ($COCKPIT_CONF)..."
DESIRED_CONF=$(build_cockpit_conf)
CURRENT_CONF=""
if [ -r "$COCKPIT_CONF" ]; then
    CURRENT_CONF=$(cat "$COCKPIT_CONF")
fi

if [ "$CURRENT_CONF" != "$DESIRED_CONF" ]; then
    require_root
    $SUDO mkdir -p /etc/cockpit
    printf '%s\n' "$DESIRED_CONF" | $SUDO tee "$COCKPIT_CONF" >/dev/null
    echo "  ✅ Configuración actualizada en $COCKPIT_CONF (IdleTimeout=15)."
    if systemctl is-active --quiet cockpit.service 2>/dev/null; then
        $SUDO systemctl stop cockpit.service 2>/dev/null || true
    fi
else
    echo "  ✅ $COCKPIT_CONF ya cuenta con la configuración óptima."
fi

# 3. Habilitar Cockpit Socket (Activación bajo demanda)
echo "ℹ️ [3/4] Verificando activación bajo demanda (cockpit.socket)..."
if systemctl is-enabled --quiet cockpit.socket 2>/dev/null && systemctl is-active --quiet cockpit.socket 2>/dev/null; then
    echo "  ✅ cockpit.socket ya está habilitado y activo bajo demanda."
else
    require_root
    $SUDO systemctl enable --now cockpit.socket
    echo "  ✅ cockpit.socket habilitado y activo."
fi

# 4. Configurar UFW (puerto 9090/tcp)
echo "ℹ️ [4/4] Verificando UFW (puerto 9090/tcp para Cockpit)..."
if command -v ufw &>/dev/null && systemctl is-active --quiet ufw 2>/dev/null; then
    require_root
    if ! LC_ALL=C $SUDO ufw status 2>/dev/null | grep -qE "9090(/tcp)?\s+ALLOW"; then
        $SUDO ufw allow 9090/tcp comment 'Cockpit Web Console' >/dev/null 2>&1 || true
        $SUDO ufw reload >/dev/null 2>&1 || true
        echo "  ✅ Regla UFW para Cockpit (9090/tcp) añadida."
    else
        echo "  ✅ El puerto 9090/tcp ya está permitido en UFW."
    fi
else
    echo "  ℹ️ UFW no está activo o no instalado; omitiendo regla de firewall."
fi

echo ""
echo "================================================================="
echo "✅ Cockpit Web Console verificado y optimizado con éxito."
echo "🌐 URL Local:   https://localhost:9090"
HOST_IP=$(get_host_ip)
if [ -n "$HOST_IP" ]; then
    echo "🌐 URL Red LAN: https://$HOST_IP:9090"
fi
echo "💡 Inicia sesión con tus credenciales de usuario ($REAL_USER)."
echo "================================================================="

#!/usr/bin/env bash
# ==============================================================================
# SEGURIDAD Y RED DE DESARROLLO (seguridad.sh) - Golden Dog Linux (Debian 13 KDE)
# ==============================================================================
# Configuración orientada a estación de trabajo local/hogar para desarrollo:
# • UFW nativo + Goldendog Firewall GUI (goldendog-firewall) y KDE Plasma Firewall
#   (plasma-firewall / kcm_firewall) preinstalados en Golden Dog Linux.
# • Reglas 100% compatibles y editables desde la interfaz gráfica Goldendog Firewall:
#   Cockpit (9090/tcp), KDE Connect (1714:1764 tcp/udp), mDNS (5353/udp), SSH (22/tcp),
#   y enrutamiento para KVM/QEMU (virbr0) y Podman (podman0).
# • Sincronización de IP Forwarding con /etc/ufw/sysctl.conf y /etc/sysctl.d/99-dev-network.conf
#   (coexistiendo con el baseline de hardening /etc/sysctl.d/90-goldendog.conf).
# • Sysctl: IP Forwarding con accept_ra=2 (IPv6 SLAAC estable), puertos sin privilegios (>=80),
#   ping_group_range completo para contenedores rootless y diagnóstico de user namespaces en Debian 13.
# • Soporte CLI: --status / -s, --gui / --open, --dev-ports / -d, --close-dev-ports, --sysctl, --help / -h.
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="${USER:-$(id -un)}"
    USER_HOME="${HOME:-/home/$REAL_USER}"
fi

if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo "❌ Error: 'sudo' no está disponible."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

run_as_user() {
    if [ "$EUID" -eq 0 ] && [ "$REAL_USER" != "root" ]; then
        local uid
        uid=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")
        sudo -u "$REAL_USER" env \
            HOME="$USER_HOME" \
            USER="$REAL_USER" \
            XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}" \
            DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$uid/bus}" \
            DISPLAY="${DISPLAY:-:0}" \
            WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
            "$@"
    else
        "$@"
    fi
}

show_help() {
    cat <<EOF
🛡️ Gestor de Seguridad y Red de Desarrollo - Golden Dog Linux (Debian 13 KDE Plasma 6)
(Integrado con UFW nativo, Goldendog Firewall GUI, Podman Rootless y KVM/Libvirt)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)      Verifica UFW y sus interfaces gráficas (goldendog-firewall / plasma-firewall),
                        aplica reglas compatibles con la GUI (Cockpit, KDE Connect, mDNS, Podman, KVM)
                        y configura sysctl para desarrollo rootless sin bloqueos.
  --status, -s          Muestra el diagnóstico completo (sin requerir sudo) de UFW, políticas,
                        interfaces gráficas, baseline 90-goldendog.conf y sysctl de red.
  --gui, --open, -g, -o Abre la interfaz gráfica nativa Goldendog Firewall (o el módulo KCM de KDE).
  --dev-ports, -d       Abre en UFW los puertos locales de desarrollo con etiquetas individuales
                        editables desde Goldendog Firewall (5173, 3000, 8000, 8080).
  --close-dev-ports     Cierra en UFW los puertos locales de desarrollo (5173, 3000, 8000, 8080).
  --sysctl              Aplica únicamente los parámetros sysctl de red y contenedores rootless.
  --help, -h            Muestra este mensaje de ayuda.

Características en Golden Dog Linux:
  • UFW + GUI Nativa:   Preinstalados de serie ('ufw', 'goldendog-firewall' y 'plasma-firewall').
                        Todas las reglas de puerto usan sintaxis numérica con comentario limpio para
                        que puedan visualizarse y editarse directamente en Goldendog Firewall.
  • Podman & KVM:       Reglas de paso y enrutamiento para 'virbr0' y 'podman0', más persistencia
                        de IP Forwarding en /etc/ufw/sysctl.conf al guardar cambios desde la GUI.
  • Hardening & Dev:    Respeta /etc/sysctl.d/90-goldendog.conf y añade en 99-dev-network.conf
                        accept_ra=2 (SLAAC IPv6), puertos rootless >=80 y ping_group_range.
EOF
}

read_ufw_kv() {
    local file="$1"
    local key="$2"
    local default_val="${3:-}"
    if [ -r "$file" ]; then
        local val
        val=$(awk -F= -v k="$key" '$1 ~ "^[[:space:]]*"k"[[:space:]]*$" {gsub(/["'\''[:space:]]/, "", $2); print $2; exit}' "$file" 2>/dev/null || true)
        if [ -n "$val" ]; then
            echo "$val"
            return 0
        fi
    fi
    echo "$default_val"
}

show_status() {
    echo "================================================================="
    echo "🔍 ESTADO DE SEGURIDAD Y RED DE DESARROLLO - GOLDEN DOG LINUX"
    echo "================================================================="

    local ufw_conf_enabled ufw_in_policy ufw_out_policy ufw_fwd_policy ufw_ipv6
    ufw_conf_enabled=$(read_ufw_kv "/etc/ufw/ufw.conf" "ENABLED" "no")
    ufw_in_policy=$(read_ufw_kv "/etc/default/ufw" "DEFAULT_INPUT_POLICY" "DROP")
    ufw_out_policy=$(read_ufw_kv "/etc/default/ufw" "DEFAULT_OUTPUT_POLICY" "ACCEPT")
    ufw_fwd_policy=$(read_ufw_kv "/etc/default/ufw" "DEFAULT_FORWARD_POLICY" "DROP")
    ufw_ipv6=$(read_ufw_kv "/etc/default/ufw" "IPV6" "yes")

    local ufw_state_str="❌ Inactivo"
    if systemctl is-active --quiet ufw 2>/dev/null || [ "${ufw_conf_enabled,,}" = "yes" ]; then
        ufw_state_str="✅ Activo (ENABLED=${ufw_conf_enabled}, IPv6=${ufw_ipv6})"
    fi
    echo "• Cortafuegos UFW (Nativo):   $ufw_state_str"
    echo "• Políticas por defecto UFW:  Entrada: $ufw_in_policy | Salida: $ufw_out_policy | Reenvío: $ufw_fwd_policy"

    echo "• Interfaces Gráficas (GUI):"
    if command -v goldendog-firewall &>/dev/null || dpkg -s goldendog-firewall &>/dev/null; then
        echo "  - Goldendog Firewall:       ✅ Instalada (ejecutar 'goldendog-firewall' o '$0 --gui')"
    else
        echo "  - Goldendog Firewall:       ⚠️ No detectada"
    fi
    if dpkg -s plasma-firewall &>/dev/null || [ -f /usr/share/applications/kcm_firewall.desktop ]; then
        echo "  - KDE Plasma Firewall KCM:  ✅ Integrado en Preferencias del Sistema (systemsettings kcm_firewall)"
    else
        echo "  - KDE Plasma Firewall KCM:  ℹ️ No instalado"
    fi

    if command -v ufw &>/dev/null; then
        if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
            echo "-----------------------------------------------------------------"
            $SUDO ufw status verbose 2>/dev/null || true
        else
            echo "  ℹ️ Para listar las reglas activas en terminal usa 'sudo ufw status' o abre 'goldendog-firewall'."
        fi
    fi

    echo "-----------------------------------------------------------------"
    echo "🛡️ Hardening Base de Golden Dog Linux (/etc/sysctl.d/90-goldendog.conf):"
    if [ -f /etc/sysctl.d/90-goldendog.conf ]; then
        echo "  • Perfil 90-goldendog.conf:                 ✅ Presente"
    else
        echo "  • Perfil 90-goldendog.conf:                 ℹ️ No encontrado"
    fi
    echo "  • Ocultación punteros kernel (kptr_restrict): $(cat /proc/sys/kernel/kptr_restrict 2>/dev/null || echo 'n/a') (Recomendado: 1)"
    echo "  • Protección ptrace (yama.ptrace_scope):      $(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo 'n/a') (Recomendado: 1)"
    echo "  • Core dumps SUID (fs.suid_dumpable):         $(cat /proc/sys/fs/suid_dumpable 2>/dev/null || echo 'n/a') (Recomendado: 0)"

    echo "-----------------------------------------------------------------"
    echo "⚙️ Parámetros de Kernel para Desarrollo (Podman Rootless & KVM):"
    echo "  • Perfil 99-dev-network.conf:               $([ -f /etc/sysctl.d/99-dev-network.conf ] && echo '✅ Activo' || echo 'ℹ️ Pendiente de aplicar ($0)')"
    echo "  • Reenvío IPv4 (ip_forward):                $(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 'n/a') (Requerido: 1)"
    echo "  • Reenvío IPv6 (forwarding):                $(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || echo 'n/a') (Requerido: 1)"
    echo "  • IPv6 Router Advertisements (accept_ra):   $(cat /proc/sys/net/ipv6/conf/all/accept_ra 2>/dev/null || echo 'n/a') (Requerido: 2 si forwarding=1)"
    echo "  • Puerto inicio sin privilegios (Podman):   $(cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || echo 'n/a') (Recomendado: 80)"
    echo "  • Rango grupos ping (Podman rootless):      $(tr '\t' ' ' < /proc/sys/net/ipv4/ping_group_range 2>/dev/null || echo 'n/a') (Objetivo: 0 2147483647)"
    echo "  • User namespaces (max_user_namespaces):    $(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo 'n/a')"
    echo "  • Userns sin privilegios (Debian 13):       $(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo 'n/a') (1=habilitado para Podman/Flatpak)"

    echo "-----------------------------------------------------------------"
    echo "🏠 Servicios y privacidad en red local de hogar:"
    local f2b_status="inactivo"
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        f2b_status="activo"
    fi
    echo "  • Fail2ban:                 $f2b_status (innecesario en LAN doméstica)"
    echo "  • MAC Randomization:        $(if [ -f /etc/NetworkManager/conf.d/00-macrandomize.conf ]; then echo '⚠️ Activo (puede alterar reservas DHCP)'; else echo '✅ Inactivo (IP estática y DHCP estable)'; fi)"
    echo "================================================================="
}

open_firewall_gui() {
    echo "🛡️ Abriendo interfaz gráfica de cortafuegos de Golden Dog Linux..."
    if command -v goldendog-firewall &>/dev/null; then
        run_as_user goldendog-firewall &>/dev/null &
        echo "✅ Goldendog Firewall iniciado."
    elif command -v systemsettings &>/dev/null && [ -f /usr/share/applications/kcm_firewall.desktop ]; then
        run_as_user systemsettings kcm_firewall &>/dev/null &
        echo "✅ Módulo de Cortafuegos de KDE Plasma iniciado."
    else
        echo "❌ No se encontró 'goldendog-firewall' ni 'plasma-firewall'."
        exit 1
    fi
}

open_dev_ports() {
    echo "================================================================="
    echo "🌐 HABILITANDO PUERTOS DE DESARROLLO LOCAL EN UFW"
    echo "================================================================="
    if ! command -v ufw &>/dev/null; then
        echo "❌ UFW no está disponible."
        exit 1
    fi

    if ! $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "⚡ Activando UFW..."
        $SUDO ufw --force enable >/dev/null 2>&1 || true
    fi

    # Reglas con formato numérico y comentario individual compatibles con el editor de Goldendog Firewall
    $SUDO ufw allow 5173/tcp comment 'Vite Astro Frontend 5173' >/dev/null 2>&1 || true
    $SUDO ufw allow 3000/tcp comment 'Nextjs Nodejs Dev 3000' >/dev/null 2>&1 || true
    $SUDO ufw allow 8000/tcp comment 'FastAPI Python Dev 8000' >/dev/null 2>&1 || true
    $SUDO ufw allow 8080/tcp comment 'Local Web Containers 8080' >/dev/null 2>&1 || true
    $SUDO ufw reload >/dev/null 2>&1 || true

    echo "  ✅ Puertos abiertos en UFW (visibles y editables en Goldendog Firewall):"
    echo "     • 5173/tcp (Vite Astro Frontend 5173)"
    echo "     • 3000/tcp (Nextjs Nodejs Dev 3000)"
    echo "     • 8000/tcp (FastAPI Python Dev 8000)"
    echo "     • 8080/tcp (Local Web Containers 8080)"
    echo "================================================================="
}

close_dev_ports() {
    echo "================================================================="
    echo "🔒 CERRANDO PUERTOS DE DESARROLLO LOCAL EN UFW"
    echo "================================================================="
    if ! command -v ufw &>/dev/null; then
        echo "❌ UFW no está disponible."
        exit 1
    fi

    for port in 5173/tcp 3000/tcp 8000/tcp 8080/tcp; do
        $SUDO ufw delete allow "$port" >/dev/null 2>&1 || true
        $SUDO ufw delete allow in "$port" >/dev/null 2>&1 || true
    done
    $SUDO ufw reload >/dev/null 2>&1 || true
    echo "  ✅ Puertos de desarrollo (5173, 3000, 8000, 8080) eliminados de UFW."
    echo "================================================================="
}

apply_dev_sysctl() {
    echo "⚙️ Aplicando parámetros sysctl de red y contenedores rootless..."
    $SUDO mkdir -p /etc/sysctl.d
    $SUDO tee /etc/sysctl.d/99-dev-network.conf > /dev/null <<'EOF'
# ==============================================================================
# RED DE DESARROLLO Y VIRTUALIZACIÓN - GOLDEN DOG LINUX (DEBIAN 13 KDE)
# Complementa /etc/sysctl.d/90-goldendog.conf sin alterar sus reglas de hardening
# ==============================================================================

# Habilitar IP forwarding para contenedores Podman y máquinas virtuales KVM/Libvirt
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1

# Preservar Router Advertisements (SLAAC IPv6) cuando forwarding IPv6 está activo
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2

# Permitir puertos sin privilegios desde el puerto 80 (Podman Rootless / Reverse Proxies)
net.ipv4.ip_unprivileged_port_start = 80

# Permitir ICMP ping en contenedores Podman rootless sin CAP_NET_RAW
net.ipv4.ping_group_range = 0 2147483647

# Garantizar soporte de user namespaces sin privilegios en Debian 13 (Podman / Flatpak)
kernel.unprivileged_userns_clone = 1
EOF

    # Sincronizar IP forwarding en /etc/ufw/sysctl.conf para que al guardar cambios desde
    # Goldendog Firewall (que recarga /etc/ufw/sysctl.conf) no se desactive el enrutamiento KVM/Podman
    if [ -f /etc/ufw/sysctl.conf ]; then
        $SUDO sed -i -E 's|^#?[[:space:]]*net/ipv4/ip_forward=.*|net/ipv4/ip_forward=1|' /etc/ufw/sysctl.conf
        $SUDO sed -i -E 's|^#?[[:space:]]*net/ipv6/conf/default/forwarding=.*|net/ipv6/conf/default/forwarding=1|' /etc/ufw/sysctl.conf
        $SUDO sed -i -E 's|^#?[[:space:]]*net/ipv6/conf/all/forwarding=.*|net/ipv6/conf/all/forwarding=1|' /etc/ufw/sysctl.conf
    fi

    $SUDO sysctl --system >/dev/null 2>&1 || true
    echo "  ✅ Parámetros sysctl aplicados en /etc/sysctl.d/99-dev-network.conf y sincronizados con /etc/ufw/sysctl.conf."
}

case "${1:-}" in
    --help|-h|help)
        show_help
        exit 0
        ;;
    --status|-s|status)
        show_status
        exit 0
        ;;
    --gui|--open|-g|-o)
        open_firewall_gui
        exit 0
        ;;
    --dev-ports|-d|dev-ports)
        open_dev_ports
        exit 0
        ;;
    --close-dev-ports)
        close_dev_ports
        exit 0
        ;;
    --sysctl)
        apply_dev_sysctl
        exit 0
        ;;
    "")
        ;;
    *)
        echo "❌ Opción desconocida: $1"
        show_help
        exit 1
        ;;
esac

echo "================================================================="
echo "🛡️ CONFIGURANDO SEGURIDAD Y RED DE DESARROLLO (GOLDEN DOG LINUX)"
echo "================================================================="

# 1. Verificar UFW e interfaces gráficas nativas de Golden Dog Linux
echo "🔥 [1/4] Verificando UFW (preinstalado) e interfaz Goldendog Firewall..."
if ! command -v ufw &>/dev/null; then
    echo "📦 Instalando UFW vía APT..."
    export DEBIAN_FRONTEND=noninteractive
    $SUDO apt-get update -qq
    $SUDO apt-get install -y ufw
else
    echo "  ✅ UFW preinstalado detectado ($(ufw --version 2>/dev/null | head -n1 || echo 'activo'))."
fi

if command -v goldendog-firewall &>/dev/null; then
    echo "  ✅ Interfaz gráfica nativa 'goldendog-firewall' disponible."
elif [ -f /usr/share/applications/kcm_firewall.desktop ]; then
    echo "  ✅ Módulo gráfico 'plasma-firewall' (KDE System Settings) disponible."
fi

$SUDO systemctl enable --now ufw 2>/dev/null || true
if ! $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
    $SUDO ufw default deny incoming >/dev/null 2>&1 || true
    $SUDO ufw default allow outgoing >/dev/null 2>&1 || true
    $SUDO ufw --force enable >/dev/null 2>&1 || true
fi

# 2. Reglas de red compatibles con Goldendog Firewall GUI (Cockpit, KDE Connect, mDNS, KVM, Podman)
echo "🌐 [2/4] Aplicando reglas de red en UFW (compatibles con Goldendog Firewall)..."
$SUDO ufw allow 9090/tcp comment 'Cockpit Web Console' >/dev/null 2>&1 || true
$SUDO ufw allow 1714:1764/tcp comment 'KDE Connect TCP' >/dev/null 2>&1 || true
$SUDO ufw allow 1714:1764/udp comment 'KDE Connect UDP' >/dev/null 2>&1 || true
$SUDO ufw allow 5353/udp comment 'mDNS Avahi' >/dev/null 2>&1 || true

# Reglas para puentes virtuales KVM/Libvirt (virbr0) y Podman (podman0)
$SUDO ufw allow in on virbr0 comment 'KVM Libvirt NAT Bridge' >/dev/null 2>&1 || true
$SUDO ufw route allow in on virbr0 comment 'KVM Libvirt Forward In' >/dev/null 2>&1 || true
$SUDO ufw route allow out on virbr0 comment 'KVM Libvirt Forward Out' >/dev/null 2>&1 || true
$SUDO ufw allow in on podman0 comment 'Podman Bridge' >/dev/null 2>&1 || true
$SUDO ufw route allow in on podman0 comment 'Podman Forward In' >/dev/null 2>&1 || true

if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    # Usar 22/tcp en lugar del alias 'ssh' para que la regla sea editable desde Goldendog Firewall GUI
    $SUDO ufw allow 22/tcp comment 'SSH Server' >/dev/null 2>&1 || true
fi

$SUDO ufw reload >/dev/null 2>&1 || true
echo "  ✅ Reglas de UFW configuradas (Cockpit 9090, KDE Connect, mDNS, virbr0, podman0)."

# 3. Parámetros de Kernel (Sysctl) para Podman Rootless & KVM
echo "⚙️ [3/4] Configurando parámetros sysctl de red y namespaces..."
apply_dev_sysctl

# 4. Verificación de privacidad en LAN doméstica
echo "🏠 [4/4] Verificando estabilidad DHCP en red local..."
if [ -f /etc/NetworkManager/conf.d/00-macrandomize.conf ]; then
    echo "  ⚠️ Detectada configuración de MAC Randomization; conservada por seguridad del usuario."
else
    echo "  ✅ Sin MAC Randomization disruptiva (reservas DHCP e IP estable preservadas)."
fi

echo "================================================================="
echo "✅ Configuración de seguridad y red (UFW) completada."
echo "🖥️ Puedes gestionar tus reglas visualmente ejecutando: goldendog-firewall (o '$0 --gui')"
echo "================================================================="

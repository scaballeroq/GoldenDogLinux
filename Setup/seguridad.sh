#!/usr/bin/env bash
# ==============================================================================
# SEGURIDAD Y RED DE DESARROLLO (seguridad.sh) - Golden Dog Linux (Debian 13 KDE)
# ==============================================================================
# Configuración orientada a estación de trabajo local/hogar para desarrollo:
# • UFW nativo + Goldendog Firewall GUI (goldendog-firewall) y KDE Plasma Firewall
#   (plasma-firewall / kcm_firewall) preinstalados y preconfigurados en Golden Dog Linux.
# • Reglas 100% compatibles y editables desde la interfaz gráfica Goldendog Firewall:
#   Cockpit (9090/tcp), KDE Connect (1714:1764 tcp/udp), mDNS (5353/udp), SSH (22/tcp),
#   y enrutamiento para KVM/QEMU (virbr0) y Podman (podman0).
# • Sincronización de IP Forwarding con /etc/ufw/sysctl.conf y /etc/sysctl.d/99-dev-network.conf
#   (coexistiendo con el baseline de hardening /etc/sysctl.d/90-goldendog.conf).
# • Sysctl: IP Forwarding con accept_ra=2 (IPv6 SLAAC estable), puertos sin privilegios (>=80),
#   ping_group_range completo para contenedores rootless y soporte de user namespaces.
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
    SUDO="sudo"
else
    SUDO=""
fi

DEV_SYSCTL_CONF="/etc/sysctl.d/99-dev-network.conf"
UFW_SYSCTL_CONF="/etc/ufw/sysctl.conf"

# Puertos de desarrollo local (formato "puerto/proto:Comentario GUI")
DEV_PORTS=(
    "5173/tcp:Vite Astro Frontend 5173"
    "3000/tcp:Nextjs Nodejs Dev 3000"
    "8000/tcp:FastAPI Python Dev 8000"
    "8080/tcp:Local Web Containers 8080"
)

require_root() {
    if [ "$EUID" -ne 0 ] && ! command -v sudo &>/dev/null; then
        echo "❌ Error: Esta operación requiere privilegios de administrador ('sudo')."
        exit 1
    fi
}

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
            ${XDG_CURRENT_DESKTOP:+XDG_CURRENT_DESKTOP="$XDG_CURRENT_DESKTOP"} \
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
  (sin argumentos)      Verifica UFW preconfigurado y sus GUIs (goldendog-firewall / plasma-firewall),
                        añade solo las reglas faltantes (Cockpit, KDE Connect, mDNS, Podman, KVM)
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
  • UFW + GUI Nativa:   Preinstalados y activos de serie ('ufw', 'goldendog-firewall' y 'plasma-firewall').
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

    local gui_pkgs
    gui_pkgs=$(dpkg-query -W -f='${Package}\t${db:Status-Status}\n' goldendog-firewall plasma-firewall 2>/dev/null || true)

    echo "• Interfaces Gráficas (GUI):"
    if command -v goldendog-firewall &>/dev/null || grep -qx $'goldendog-firewall\tinstalled' <<< "$gui_pkgs"; then
        echo "  - Goldendog Firewall:       ✅ Instalada (ejecutar 'goldendog-firewall' o '$0 --gui')"
    else
        echo "  - Goldendog Firewall:       ⚠️ No detectada"
    fi
    if grep -qx $'plasma-firewall\tinstalled' <<< "$gui_pkgs" || [ -f /usr/share/applications/kcm_firewall.desktop ]; then
        echo "  - KDE Plasma Firewall KCM:  ✅ Integrado en Preferencias del Sistema (systemsettings kcm_firewall)"
    else
        echo "  - KDE Plasma Firewall KCM:  ℹ️ No instalado"
    fi

    if command -v ufw &>/dev/null; then
        if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
            echo "-----------------------------------------------------------------"
            LC_ALL=C $SUDO ufw status verbose 2>/dev/null || true
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
    if [ -f "$DEV_SYSCTL_CONF" ]; then
        echo "  • Perfil 99-dev-network.conf:               ✅ Activo"
    else
        echo "  • Perfil 99-dev-network.conf:               ℹ️ Pendiente de aplicar ($0)"
    fi
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

ensure_ufw_active() {
    require_root
    if ! command -v ufw &>/dev/null; then
        echo "❌ UFW no está disponible."
        exit 1
    fi
    if ! systemctl is-enabled --quiet ufw 2>/dev/null || ! systemctl is-active --quiet ufw 2>/dev/null; then
        $SUDO systemctl enable --now ufw >/dev/null 2>&1 || true
    fi
    if ! LC_ALL=C $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "⚡ Activando UFW..."
        $SUDO ufw default deny incoming >/dev/null 2>&1 || true
        $SUDO ufw default allow outgoing >/dev/null 2>&1 || true
        $SUDO ufw --force enable >/dev/null 2>&1 || true
    fi
}

# Añade una regla en UFW solo si no aparece ya en el snapshot actual.
# Uso: ufw_add_if_missing "$snapshot" "<regex_match>" <args de ufw...>
ufw_add_if_missing() {
    local snapshot="$1"
    local pattern="$2"
    shift 2
    if grep -qE "$pattern" <<< "$snapshot"; then
        return 1
    fi
    $SUDO ufw "$@" >/dev/null 2>&1 || true
    return 0
}

open_firewall_gui() {
    echo "🛡️ Abriendo interfaz gráfica de cortafuegos de Golden Dog Linux..."
    if command -v goldendog-firewall &>/dev/null; then
        nohup run_as_user goldendog-firewall >/dev/null 2>&1 &
        echo "✅ Goldendog Firewall iniciado."
    elif command -v systemsettings &>/dev/null && [ -f /usr/share/applications/kcm_firewall.desktop ]; then
        nohup run_as_user systemsettings kcm_firewall >/dev/null 2>&1 &
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
    ensure_ufw_active

    local ufw_snapshot changed=0
    ufw_snapshot=$(LC_ALL=C $SUDO ufw status 2>/dev/null || true)

    local entry port comment
    for entry in "${DEV_PORTS[@]}"; do
        port="${entry%%:*}"
        comment="${entry#*:}"
        if ufw_add_if_missing "$ufw_snapshot" "^${port}[[:space:]]+ALLOW" allow "$port" comment "$comment"; then
            changed=1
        fi
    done

    if [ "$changed" -eq 1 ]; then
        $SUDO ufw reload >/dev/null 2>&1 || true
        echo "  ✅ Puertos abiertos en UFW (visibles y editables en Goldendog Firewall):"
    else
        echo "  ✅ Todos los puertos de desarrollo ya estaban abiertos en UFW:"
    fi
    for entry in "${DEV_PORTS[@]}"; do
        port="${entry%%:*}"
        comment="${entry#*:}"
        echo "     • $port ($comment)"
    done
    echo "================================================================="
}

close_dev_ports() {
    echo "================================================================="
    echo "🔒 CERRANDO PUERTOS DE DESARROLLO LOCAL EN UFW"
    echo "================================================================="
    require_root
    if ! command -v ufw &>/dev/null; then
        echo "❌ UFW no está disponible."
        exit 1
    fi

    local ufw_snapshot changed=0 entry port
    ufw_snapshot=$(LC_ALL=C $SUDO ufw status 2>/dev/null || true)
    for entry in "${DEV_PORTS[@]}"; do
        port="${entry%%:*}"
        if grep -qE "^${port}[[:space:]]+ALLOW" <<< "$ufw_snapshot"; then
            $SUDO ufw delete allow "$port" >/dev/null 2>&1 || true
            $SUDO ufw delete allow in "$port" >/dev/null 2>&1 || true
            changed=1
        fi
    done

    if [ "$changed" -eq 1 ]; then
        $SUDO ufw reload >/dev/null 2>&1 || true
        echo "  ✅ Puertos de desarrollo (5173, 3000, 8000, 8080) eliminados de UFW."
    else
        echo "  ✅ Ninguno de los puertos de desarrollo estaba abierto en UFW."
    fi
    echo "================================================================="
}

build_dev_sysctl_conf() {
    cat <<'EOF'
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
}

apply_dev_sysctl() {
    require_root
    echo "⚙️ Verificando parámetros sysctl de red y contenedores rootless..."
    local desired_conf current_conf="" needs_reload=0
    desired_conf=$(build_dev_sysctl_conf)
    if [ -r "$DEV_SYSCTL_CONF" ]; then
        current_conf=$(cat "$DEV_SYSCTL_CONF")
    fi

    if [ "$current_conf" != "$desired_conf" ]; then
        $SUDO mkdir -p /etc/sysctl.d
        printf '%s\n' "$desired_conf" | $SUDO tee "$DEV_SYSCTL_CONF" >/dev/null
        needs_reload=1
    fi

    # Sincronizar IP forwarding en /etc/ufw/sysctl.conf para que al guardar cambios desde
    # Goldendog Firewall (que recarga /etc/ufw/sysctl.conf) no se desactive el enrutamiento KVM/Podman
    if [ -f "$UFW_SYSCTL_CONF" ]; then
        if ! grep -qx "net/ipv4/ip_forward=1" "$UFW_SYSCTL_CONF" 2>/dev/null || \
           ! grep -qx "net/ipv6/conf/default/forwarding=1" "$UFW_SYSCTL_CONF" 2>/dev/null || \
           ! grep -qx "net/ipv6/conf/all/forwarding=1" "$UFW_SYSCTL_CONF" 2>/dev/null; then
            $SUDO sed -i -E 's|^#?[[:space:]]*net/ipv4/ip_forward=.*|net/ipv4/ip_forward=1|' "$UFW_SYSCTL_CONF"
            $SUDO sed -i -E 's|^#?[[:space:]]*net/ipv6/conf/default/forwarding=.*|net/ipv6/conf/default/forwarding=1|' "$UFW_SYSCTL_CONF"
            $SUDO sed -i -E 's|^#?[[:space:]]*net/ipv6/conf/all/forwarding=.*|net/ipv6/conf/all/forwarding=1|' "$UFW_SYSCTL_CONF"
            needs_reload=1
        fi
    fi

    # También recargar si algún parámetro vivo en /proc/sys aún no refleja el perfil
    if [ "$needs_reload" -eq 0 ]; then
        if [ "$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || echo 0)" != "1" ] || \
           [ "$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || echo 1024)" != "80" ]; then
            needs_reload=1
        fi
    fi

    if [ "$needs_reload" -eq 1 ]; then
        $SUDO sysctl --system >/dev/null 2>&1 || true
        echo "  ✅ Parámetros sysctl aplicados en $DEV_SYSCTL_CONF y sincronizados con $UFW_SYSCTL_CONF."
    else
        echo "  ✅ Parámetros sysctl ya aplicados y sincronizados ($DEV_SYSCTL_CONF)."
    fi
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
    require_root
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

ensure_ufw_active

# 2. Reglas de red compatibles con Goldendog Firewall GUI (Cockpit, KDE Connect, mDNS, KVM, Podman)
echo "🌐 [2/4] Verificando reglas de red en UFW (compatibles con Goldendog Firewall)..."
UFW_SNAPSHOT=$(LC_ALL=C $SUDO ufw status 2>/dev/null || true)
UFW_CHANGED=0

ufw_add_if_missing "$UFW_SNAPSHOT" "^9090/tcp[[:space:]]+ALLOW" allow 9090/tcp comment 'Cockpit Web Console' && UFW_CHANGED=1 || true
ufw_add_if_missing "$UFW_SNAPSHOT" "^1714:1764/tcp[[:space:]]+ALLOW" allow 1714:1764/tcp comment 'KDE Connect TCP' && UFW_CHANGED=1 || true
ufw_add_if_missing "$UFW_SNAPSHOT" "^1714:1764/udp[[:space:]]+ALLOW" allow 1714:1764/udp comment 'KDE Connect UDP' && UFW_CHANGED=1 || true
ufw_add_if_missing "$UFW_SNAPSHOT" "^5353/udp[[:space:]]+ALLOW" allow 5353/udp comment 'mDNS Avahi' && UFW_CHANGED=1 || true

# Reglas para puentes virtuales KVM/Libvirt (virbr0) y Podman (podman0)
ufw_add_if_missing "$UFW_SNAPSHOT" "on virbr0[[:space:]]+ALLOW[[:space:]]+IN" allow in on virbr0 comment 'KVM Libvirt NAT Bridge' && UFW_CHANGED=1 || true
ufw_add_if_missing "$UFW_SNAPSHOT" "on virbr0[[:space:]]+ALLOW FWD" route allow in on virbr0 comment 'KVM Libvirt Forward In' && UFW_CHANGED=1 || true
ufw_add_if_missing "$UFW_SNAPSHOT" "ALLOW FWD[[:space:]]+.*on virbr0" route allow out on virbr0 comment 'KVM Libvirt Forward Out' && UFW_CHANGED=1 || true
ufw_add_if_missing "$UFW_SNAPSHOT" "on podman0[[:space:]]+ALLOW[[:space:]]+IN" allow in on podman0 comment 'Podman Bridge' && UFW_CHANGED=1 || true
ufw_add_if_missing "$UFW_SNAPSHOT" "on podman0[[:space:]]+ALLOW FWD" route allow in on podman0 comment 'Podman Forward In' && UFW_CHANGED=1 || true

if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    # Usar 22/tcp en lugar del alias 'ssh' para que la regla sea editable desde Goldendog Firewall GUI
    ufw_add_if_missing "$UFW_SNAPSHOT" "^22/tcp[[:space:]]+ALLOW" allow 22/tcp comment 'SSH Server' && UFW_CHANGED=1 || true
fi

if [ "$UFW_CHANGED" -eq 1 ]; then
    $SUDO ufw reload >/dev/null 2>&1 || true
    echo "  ✅ Reglas de UFW actualizadas y recargadas (Cockpit 9090, KDE Connect, mDNS, virbr0, podman0)."
else
    echo "  ✅ Todas las reglas de UFW ya estaban configuradas."
fi

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

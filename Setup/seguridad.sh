#!/usr/bin/env bash
# ==============================================================================
# SEGURIDAD Y RED DE DESARROLLO (seguridad.sh) - Golden Dog Linux (Debian 13 KDE)
# ==============================================================================
# Configuración orientada a estación de trabajo local/hogar para desarrollo:
# • UFW nativo (preinstalado y configurado en Golden Dog Linux): Cockpit (9090),
#   KDE Connect (1714-1764), mDNS (5353/udp), Podman Rootless y KVM/QEMU (virbr0).
# • Sysctl: IP Forwarding con accept_ra=2 (IPv6 estable), puertos sin privilegios (>=80),
#   namespaces de usuario optimizados y diagnóstico de restricción AppArmor.
# • Entorno de trabajo doméstico: IP y DHCP estables, sin MAC Randomization disruptiva.
# • Soporte CLI: --status / -s, --dev-ports / -d, --help / -h.
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
    if ! command -v sudo &> /dev/null; then
        echo "❌ Error: 'sudo' no está disponible."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

show_help() {
    cat <<EOF
🛡️ Gestor de Seguridad y Red de Desarrollo - Golden Dog Linux (Debian 13 KDE)
(Optimizado para desarrollo doméstico: Podman Rootless + KVM/Libvirt + UFW)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)    Configura UFW (Cockpit, KDE Connect, mDNS, Podman, KVM) y aplica
                      parámetros sysctl esenciales para desarrollo sin privilegios ni bloqueos.
  --status, -s        Muestra el diagnóstico de UFW, interfaces virtuales y sysctl.
  --dev-ports, -d     Abre en UFW los puertos locales de desarrollo (Vite: 5173, Next.js: 3000,
                      FastAPI: 8000, Contenedores Web: 8080).
  --help, -h          Muestra este mensaje de ayuda.

Características configuradas:
  • UFW (Nativo):     Cortafuegos por defecto en Golden Dog Linux con reglas para Cockpit,
                      KDE Connect (1714-1764 TCP/UDP), mDNS (5353/UDP) y SSH (si aplica).
  • Podman & KVM:     Reglas de paso y enrutamiento para 'virbr0' y 'podman0' en UFW.
  • Sysctl Dev:       IP forwarding (IPv4/IPv6 con accept_ra=2 para preservar SLAAC),
                      puertos sin privilegios a partir de 80 y user namespaces elevados (262144).
EOF
}

show_status() {
    echo "================================================================="
    echo "🔍 ESTADO DE SEGURIDAD Y RED DE DESARROLLO - GOLDEN DOG LINUX"
    echo "================================================================="

    local ufw_status="inactivo"
    if systemctl is-active --quiet ufw 2>/dev/null; then
        ufw_status="activo"
    fi
    echo "• UFW (systemd):              $([ "$ufw_status" = "activo" ] && echo "✅ activo" || echo "❌ inactivo")"

    if command -v ufw &>/dev/null; then
        if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
            echo "-----------------------------------------------------------------"
            $SUDO ufw status verbose 2>/dev/null || true
        else
            echo "  ℹ️ Ejecuta con sudo para ver el detalle completo de reglas UFW."
        fi
    fi

    echo "-----------------------------------------------------------------"
    echo "⚙️ Parámetros de Kernel (Sysctl para Podman & KVM):"
    echo "  • Reenvío IPv4 (ip_forward):                $(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 'n/a') (Requerido: 1)"
    echo "  • Reenvío IPv6 (forwarding):                $(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || echo 'n/a') (Requerido: 1)"
    echo "  • IPv6 Router Advertisements (accept_ra):   $(cat /proc/sys/net/ipv6/conf/all/accept_ra 2>/dev/null || echo 'n/a') (Requerido: 2 si forwarding=1)"
    echo "  • Puerto inicio sin privilegios (Podman):   $(cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || echo 'n/a') (Recomendado: 80)"
    echo "  • Rango grupos ping (Podman rootless):      $(cat /proc/sys/net/ipv4/ping_group_range 2>/dev/null || echo 'n/a')"
    echo "  • User namespaces (max_user_namespaces):    $(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo 'n/a') (Recomendado: >= 123343)"
    echo "  • Restricción AppArmor Userns (Debian):     $(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null || echo 'n/a') (0=libre para rootless, 1=restringido)"

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

open_dev_ports() {
    echo "================================================================="
    echo "🌐 HABILITANDO PUERTOS DE DESARROLLO LOCAL EN UFW"
    echo "================================================================="
    if ! command -v ufw &>/dev/null; then
        echo "❌ UFW no está instalado. Ejecuta primero: $0"
        exit 1
    fi

    if ! $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "⚡ Activando UFW..."
        $SUDO ufw --force enable
    fi

    for port in 5173/tcp 3000/tcp 8000/tcp 8080/tcp; do
        $SUDO ufw allow "$port" comment 'Local Dev Server' >/dev/null 2>&1 || true
    done
    $SUDO ufw reload >/dev/null 2>&1 || true

    echo "  ✅ Puertos abiertos en UFW:"
    echo "     • 5173/tcp (Vite / Astro / Frontend)"
    echo "     • 3000/tcp (Next.js / Node.js / React)"
    echo "     • 8000/tcp (FastAPI / Uvicorn / Django)"
    echo "     • 8080/tcp (Servicios y contenedores HTTP locales)"
    echo "================================================================="
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
    --dev-ports|-d|dev-ports)
        open_dev_ports
        exit 0
        ;;
esac

echo "================================================================="
echo "🛡️ CONFIGURANDO SEGURIDAD Y RED DE DESARROLLO (GOLDEN DOG LINUX)"
echo "================================================================="

# 1. Verificar UFW (preinstalado en Golden Dog Linux)
echo "🔥 [1/4] Verificando e integrando UFW (Uncomplicated Firewall)..."
if ! command -v ufw &>/dev/null; then
    echo "📦 Instalando UFW vía APT..."
    export DEBIAN_FRONTEND=noninteractive
    $SUDO apt-get update -qq
    $SUDO apt-get install -y ufw
fi

$SUDO systemctl enable --now ufw 2>/dev/null || true
if ! $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
    $SUDO ufw default deny incoming >/dev/null 2>&1 || true
    $SUDO ufw default allow outgoing >/dev/null 2>&1 || true
    $SUDO ufw --force enable >/dev/null 2>&1 || true
fi

# 2. Reglas de red para Golden Dog Linux (Cockpit, KDE Connect, mDNS, KVM, Podman)
echo "🌐 [2/4] Aplicando reglas de red en UFW..."
$SUDO ufw allow 9090/tcp comment 'Cockpit Web Console' >/dev/null 2>&1 || true
$SUDO ufw allow 1714:1764/tcp comment 'KDE Connect TCP' >/dev/null 2>&1 || true
$SUDO ufw allow 1714:1764/udp comment 'KDE Connect UDP' >/dev/null 2>&1 || true
$SUDO ufw allow 5353/udp comment 'mDNS / Avahi' >/dev/null 2>&1 || true

# Reglas para puentes virtuales KVM/Libvirt y Podman
$SUDO ufw allow in on virbr0 >/dev/null 2>&1 || true
$SUDO ufw route allow in on virbr0 >/dev/null 2>&1 || true
$SUDO ufw route allow out on virbr0 >/dev/null 2>&1 || true
$SUDO ufw allow in on podman0 >/dev/null 2>&1 || true
$SUDO ufw route allow in on podman0 >/dev/null 2>&1 || true

if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    $SUDO ufw allow ssh >/dev/null 2>&1 || true
fi

$SUDO ufw reload >/dev/null 2>&1 || true
echo "  ✅ Reglas de UFW configuradas (Cockpit 9090, KDE Connect, mDNS, virbr0, podman0)."

# 3. Parámetros de Kernel (Sysctl) para Podman Rootless & KVM
echo "⚙️ [3/4] Aplicando parámetros sysctl de red y namespaces..."
$SUDO tee /etc/sysctl.d/99-dev-network.conf > /dev/null <<'EOF'
# Habilitar IP forwarding para contenedores Podman y máquinas virtuales KVM/Libvirt
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
# Preservar Router Advertisements (SLAAC) cuando forwarding IPv6 está activo
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2

# Permitir puertos sin privilegios desde el puerto 80 (Podman Rootless / Traefik)
net.ipv4.ip_unprivileged_port_start = 80

# Permitir ICMP ping en contenedores rootless
net.ipv4.ping_group_range = 0 2147483647

# Incrementar límite de namespaces de usuario
user.max_user_namespaces = 262144
EOF
$SUDO sysctl --system >/dev/null 2>&1 || true
echo "  ✅ Parámetros sysctl aplicados en /etc/sysctl.d/99-dev-network.conf."

# 4. Verificación de privacidad en LAN doméstica
echo "🏠 [4/4] Verificando estabilidad DHCP en red local..."
if [ -f /etc/NetworkManager/conf.d/00-macrandomize.conf ]; then
    echo "  ⚠️ Detectada configuración de MAC Randomization; conservada por seguridad del usuario."
else
    echo "  ✅ Sin MAC Randomization disruptiva (reservas DHCP e IP estable preservadas)."
fi

echo "================================================================="
echo "✅ Configuración de seguridad y red (UFW) completada."
echo "================================================================="

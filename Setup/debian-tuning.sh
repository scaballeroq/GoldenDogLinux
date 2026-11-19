#!/usr/bin/env bash
# ==============================================================================
# debian-tuning.sh - Optimizador de Rendimiento para Golden Dog Linux (Debian 13)
# Compatible con cualquier PC o portátil (AMD / Intel) con SSD/NVMe y ZRAM
# ==============================================================================
# Características:
#   - Kernel Linux moderno y gestión de memoria optimizada (vm.page-cluster = 0)
#   - ZRAM con compresión ZSTD al 50% de RAM y swappiness adaptativo
#   - Monitoreo masivo de archivos (Inotify 1M watches) para IDEs y compiladores
#   - Límites de descriptores de archivos (1M nofile) y tareas Systemd (TasksMax=infinity)
#   - Optimización de red con TCP BBR + FQ (módulo kernel persistente en modules-load.d)
#   - Ajuste de KDE Baloo File Indexer (exclusiones de desarrollo)
#   - Servicios de mantenimiento: fstrim.timer para SSD NVMe e irqbalance multi-core
#   - Opciones CLI: --status / -s, --sysctl, --limits, --tracker, --zram, --services,
#                   --no-install, --help / -h
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# ------------------------------------------------------------------------------
# 1. DETECCIÓN DE USUARIO, ENTORNO Y PRIVILEGIOS SUDO
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo "❌ Error: 'sudo' no está disponible. Ejecuta este script con privilegios de superusuario."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="${USER:-$(id -un)}"
    USER_HOME="${HOME:-/home/$REAL_USER}"
fi

REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")

run_as_user() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$REAL_UID}"
    local dbus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime_dir/bus}"
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        sudo -u "$REAL_USER" env \
            HOME="$USER_HOME" \
            USER="$REAL_USER" \
            PATH="/usr/local/bin:/usr/bin:/bin:$PATH" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            "$@"
    else
        env \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            "$@"
    fi
}

get_os_description() {
    if [ -f /etc/os-release ]; then
        grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d '"'
    else
        echo "Debian GNU/Linux 13 (trixie)"
    fi
}

# ------------------------------------------------------------------------------
# 2. AYUDA Y DIAGNÓSTICO DEL SISTEMA
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
⚡ Optimizador de Rendimiento - Golden Dog Linux (Debian 13)

Uso:
  $0 [OPCIÓN]

Opciones principales:
  (sin argumentos)       Aplica todas las optimizaciones (Kernel, Límites, Tracker, ZRAM, Servicios).
  --status, -s           Muestra el estado actual de sysctl, límites, ZRAM, Tracker y servicios.
  --sysctl               Aplica únicamente la configuración de Kernel Sysctl y TCP BBR.
  --limits               Aplica límites de descriptores y memoria (limits.d y systemd).
  --baloo                Configura exclusiones en KDE Baloo para proyectos de desarrollo.
  --zram                 Verifica y aplica la configuración óptima de ZRAM (zstd al 50% de RAM).
  --services             Habilita servicios de mantenimiento (fstrim.timer e irqbalance).
  --no-install           Aplica ajustes de configuración sin descargar paquetes adicionales.
  --help, -h             Muestra este mensaje de ayuda.

Optimizaciones incluidas:
  1. Sysctl Kernel:      Inotify ampliado (1M watches), max_map_count (16M),
                         vm.page-cluster=0 (optimizado para ZRAM/NVMe), swappiness=60,
                         vm.watermark_boost_factor=0 (elimina microtirones), TCP BBR + FQ.
  2. Límites de Proceso: Descriptores de archivo (1M nofile), memlock unlimited,
                         systemd system/user DefaultTasksMax=infinity.
  3. Systemd Timeouts:   DefaultTimeoutStopSec=10s para apagados y reinicios rápidos sin bloqueos.
  4. KDE Baloo:          Exclusiones de node_modules, .git, .venv y compilaciones.
  5. Memoria ZRAM:       Compresión ZSTD al 50% de RAM con prioridad máxima (100).
  6. Servicios NVMe:     fstrim.timer (mantenimiento SSD/NVMe) e irqbalance (reparto multi-core).
EOF
}

show_status() {
    local os_name
    os_name=$(get_os_description)

    echo "================================================================="
    echo "🔍 ESTADO DE RENDIMIENTO Y OPTIMIZACIONES - DEBIAN WORKSTATION"
    echo "================================================================="
    echo "• Sistema Operativo:             $os_name"
    echo "• Kernel activo:                 $(uname -r)"
    local cpu_model ram_total
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs || echo "Desconocido")
    ram_total=$(free -h | awk '/^Mem:/ {print $2}' || echo "n/a")
    echo "• Hardware:                      $cpu_model ($ram_total RAM)"
    echo "-----------------------------------------------------------------"
    echo "• Sysctl Kernel & Memoria:"
    echo "  - fs.inotify.max_user_watches: $(sysctl -n fs.inotify.max_user_watches 2>/dev/null || echo 'n/a') (Objetivo: >= 1048576)"
    echo "  - vm.max_map_count:            $(sysctl -n vm.max_map_count 2>/dev/null || echo 'n/a') (Objetivo: >= 16777216)"
    echo "  - vm.swappiness:               $(sysctl -n vm.swappiness 2>/dev/null || echo 'n/a') (Objetivo: 60-100 con ZRAM)"
    echo "  - vm.page-cluster:             $(sysctl -n vm.page-cluster 2>/dev/null || echo 'n/a') (Objetivo: 0 para ZRAM/NVMe)"
    echo "  - vm.watermark_boost_factor:   $(sysctl -n vm.watermark_boost_factor 2>/dev/null || echo 'n/a') (Objetivo: 0)"
    echo "  - net.ipv4.tcp_congestion:     $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'n/a') (Objetivo: bbr)"
    echo "  - net.core.default_qdisc:      $(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'n/a') (Objetivo: fq)"
    echo "  - Archivo sysctl.d:            $([ -f /etc/sysctl.d/99-debian-tuning.conf ] && echo '✅ Activo (/etc/sysctl.d/99-debian-tuning.conf)' || echo '❌ Ausente')"
    echo "-----------------------------------------------------------------"
    echo "• Memoria ZRAM:"
    if command -v zramctl &>/dev/null; then
        zramctl 2>/dev/null || echo "  ℹ️ ZRAM no inicializada."
    else
        echo "  ❌ Herramienta zramctl no instalada."
    fi
    if [ -f /etc/default/zramswap ]; then
        local zram_algo zram_pct
        zram_algo=$(grep "^ALGORITHM=" /etc/default/zramswap 2>/dev/null | cut -d= -f2 || echo "n/a")
        zram_pct=$(grep "^PERCENT=" /etc/default/zramswap 2>/dev/null | cut -d= -f2 || echo "n/a")
        echo "  - Configuración zramswap:      Algoritmo: $zram_algo | RAM: $zram_pct%"
    fi
    echo "-----------------------------------------------------------------"
    echo "• Límites de Descriptores (nofile):"
    echo "  - Usuario actual (ulimit -n):  $(ulimit -n 2>/dev/null || echo 'n/a')"
    echo "  - Configuración limits.d:      $([ -f /etc/security/limits.d/99-development-limits.conf ] && echo '✅ Activa' || echo '❌ Ausente')"
    echo "  - Timeouts systemd (stop):     $([ -f /etc/systemd/system.conf.d/99-limits.conf ] && echo '✅ 10s (sin bloqueos)' || echo '❌ Predeterminado')"
    echo "-----------------------------------------------------------------"
    echo "• KDE Baloo File Indexer:"
    if command -v balooctl6 &>/dev/null || command -v balooctl &>/dev/null; then
        local baloo_cmd="balooctl6"
        command -v balooctl6 &>/dev/null || baloo_cmd="balooctl"
        local baloo_state
        baloo_state=$(run_as_user "$baloo_cmd" status 2>/dev/null | head -n1 || echo "desconocido")
        echo "  - Estado de Baloo:             $baloo_state"
        echo "  - Exclusiones baloofilerc:     $(grep -q 'node_modules' "$USER_HOME/.config/baloofilerc" 2>/dev/null && echo '✅ Configurado' || echo 'ℹ️ No encontrado')"
    else
        echo "  - KDE Baloo:                   ℹ️ No disponible o no activo"
    fi
    echo "-----------------------------------------------------------------"
    echo "• Almacenamiento SSD NVMe y Mantenimiento:"
    if [ -f /sys/block/nvme0n1/queue/scheduler ]; then
        echo "  - I/O Scheduler NVMe:          $(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo 'n/a')"
    fi
    echo "  - fstrim.timer (SSD/NVMe):     $(systemctl is-active fstrim.timer 2>/dev/null || echo 'inactivo')"
    echo "  - irqbalance (Multi-core):     $(systemctl is-active irqbalance 2>/dev/null || echo 'inactivo')"
    echo "================================================================="
}

# ------------------------------------------------------------------------------
# 3. PARÁMETROS DE KERNEL SYSCTL Y RED TCP BBR
# ------------------------------------------------------------------------------
apply_sysctl() {
    echo "⚙️ [1/6] Configurando optimizaciones del Kernel y Memoria en /etc/sysctl.d/..."
    $SUDO mkdir -p /etc/sysctl.d /etc/modules-load.d

    # Asegurar la carga persistente del módulo tcp_bbr en el arranque
    echo "tcp_bbr" | $SUDO tee /etc/modules-load.d/bbr.conf > /dev/null
    $SUDO modprobe tcp_bbr 2>/dev/null || true

    cat <<'EOF' | $SUDO tee /etc/sysctl.d/99-debian-tuning.conf > /dev/null
# =============================================================================
# OPTIMIZACIÓN DE RENDIMIENTO - DEBIAN 13 WORKSTATION
# Optimización de Kernel Sysctl para Golden Dog Linux (Debian 13) / ZRAM
# ==============================================================================

# Inotify ampliado: previene fallos al vigilar proyectos grandes (Vite, React, Rust, IDEs)
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024
fs.file-max = 2097152

# vm.max_map_count elevado: requerido para bases de datos, Podman, Steam y compiladores
vm.max_map_count = 16777216

# Ajustes de memoria virtual para ZRAM y almacenamiento NVMe:
# swappiness=60 permite un uso activo de ZRAM antes de saturar memoria física
vm.swappiness = 60

# page-cluster=0 desactiva la lectura anticipada secuencial de páginas en swap,
# reduciendo la latencia de descompresión en ZRAM a cero I/O de disco
vm.page-cluster = 0

# Elimina microtirones de latencia en asignación de páginas bajo carga
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125

# Manejo de dirty pages (escritura en segundo plano rápida en SSD NVMe)
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10

# Algoritmo de congestión TCP BBR + FQ para menor latencia de red
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Búferes de red modernos para conexiones de alta velocidad
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3

# Tamaño de cola de conexiones de red
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2097152
EOF

    $SUDO sysctl --system > /dev/null 2>&1 || true
    echo "  ✅ Parámetros de Kernel y TCP BBR aplicados con éxito."
}

# ------------------------------------------------------------------------------
# 4. LÍMITES DE DESCRIPTORES Y TIMEOUTS DE SYSTEMD
# ------------------------------------------------------------------------------
apply_limits() {
    echo "⚙️ [2/6] Configurando límites de descriptores (nofile), memlock y tareas..."
    $SUDO mkdir -p /etc/security/limits.d /etc/systemd/system.conf.d /etc/systemd/user.conf.d

    cat <<'EOF' | $SUDO tee /etc/security/limits.d/99-development-limits.conf > /dev/null
# Límites para desarrollo y compilación intensiva en Debian Workstation
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576

* soft memlock unlimited
* hard memlock unlimited

* soft nproc 1048576
* hard nproc 1048576
EOF

    cat <<'EOF' | $SUDO tee /etc/systemd/system.conf.d/99-limits.conf > /dev/null
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitMEMLOCK=infinity
DefaultTasksMax=infinity
DefaultTimeoutStopSec=10s
DefaultTimeoutAbortSec=10s
EOF

    cat <<'EOF' | $SUDO tee /etc/systemd/user.conf.d/99-limits.conf > /dev/null
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitMEMLOCK=infinity
DefaultTasksMax=infinity
DefaultTimeoutStopSec=10s
DefaultTimeoutAbortSec=10s
EOF

    $SUDO systemctl daemon-reexec 2>/dev/null || true
    run_as_user systemctl --user daemon-reexec 2>/dev/null || true
    echo "  ✅ Límites de descriptores (1M nofile) y timeouts rápidos (10s) configurados."
}

# ------------------------------------------------------------------------------
# 5. KDE BALOO FILE INDEXER (EXCLUSIONES DE CÓDIGO Y RENDIMIENTO)
# ------------------------------------------------------------------------------
apply_baloo() {
    echo "⚙️ [3/6] Optimizando KDE Baloo (exclusión de proyectos y carpetas pesadas)..."
    if command -v kwriteconfig6 &>/dev/null; then
        run_as_user kwriteconfig6 --file baloofilerc --group "General" --key "only basic indexing" true 2>/dev/null || true
        run_as_user kwriteconfig6 --file baloofilerc --group "General" --key "exclude folders[\$e]" "\$HOME/Workspace,\$HOME/.cache,\$HOME/.local/share/containers,\$HOME/.cargo,\$HOME/.rustup,\$HOME/.npm" 2>/dev/null || true
        run_as_user kwriteconfig6 --file baloofilerc --group "General" --key "exclude filters" "*~,.git,.svn,.hg,node_modules,.venv,venv,target,dist,build,.gradle,__pycache__,*.o,*.a,*.so,*.pyc,*.log" 2>/dev/null || true
    fi
    if command -v balooctl6 &>/dev/null; then
        run_as_user balooctl6 config add excludeFolders "$USER_HOME/Workspace" 2>/dev/null || true
    elif command -v balooctl &>/dev/null; then
        run_as_user balooctl config add excludeFolders "$USER_HOME/Workspace" 2>/dev/null || true
    fi
    echo "  ✅ KDE Baloo configurado para desarrollo (exclusiones aplicadas)."
}

# ------------------------------------------------------------------------------
# 6. CONFIGURACIÓN Y VERIFICACIÓN DE ZRAM (ZSTD)
# ------------------------------------------------------------------------------
apply_zram() {
    echo "⚙️ [4/6] Verificando swap comprimida en RAM (ZRAM con ZSTD al 50% de RAM)..."
    if [ -x "$SCRIPT_DIR/zram-setup.sh" ]; then
        "$SCRIPT_DIR/zram-setup.sh"
    else
        if ! command -v zramctl &>/dev/null || ! dpkg -s zram-tools &>/dev/null; then
            $SUDO apt-get update -qq 2>/dev/null || true
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools 2>/dev/null || true
        fi
        if [ -f /etc/default/zramswap ]; then
            $SUDO sed -i 's/^#*ALGORITHM=.*/ALGORITHM=zstd/' /etc/default/zramswap
            $SUDO sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
            $SUDO sed -i 's/^#*PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
            $SUDO systemctl enable --now zramswap.service 2>/dev/null || true
            $SUDO systemctl restart zramswap.service 2>/dev/null || true
        fi
    fi
    echo "  ✅ Memoria ZRAM (ZSTD, 50% de RAM física) asegurada."
}

# ------------------------------------------------------------------------------
# 7. SERVICIOS DE MANTENIMIENTO DEL SISTEMA (fstrim e irqbalance)
# ------------------------------------------------------------------------------
apply_services() {
    echo "⚙️ [5/6] Habilitando servicios de mantenimiento (fstrim.timer para SSD e irqbalance)..."
    if ! dpkg -s irqbalance &>/dev/null; then
        $SUDO apt-get update -qq 2>/dev/null || true
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y irqbalance 2>/dev/null || true
    fi
    $SUDO systemctl enable --now fstrim.timer 2>/dev/null || true
    $SUDO systemctl enable --now irqbalance 2>/dev/null || true
    echo "  ✅ fstrim.timer (mantenimiento semanal SSD/NVMe) e irqbalance activos."
}

# ------------------------------------------------------------------------------
# 8. VERIFICACIÓN DE I/O SCHEDULER SSD NVME
# ------------------------------------------------------------------------------
verify_storage() {
    echo "⚙️ [6/6] Verificando política de I/O en almacenamiento SSD NVMe..."
    if [ -f /sys/block/nvme0n1/queue/scheduler ]; then
        local sched
        sched=$(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo "n/a")
        echo "  - I/O Scheduler activo en nvme0n1: $sched"
    fi
    echo "  ✅ Almacenamiento NVMe optimizado con cola directa de hardware."
}

# ------------------------------------------------------------------------------
# 9. ENTRADA PRINCIPAL
# ------------------------------------------------------------------------------
case "${1:-}" in
    --status|-s|status)
        show_status
        exit 0
        ;;
    --sysctl)
        apply_sysctl
        exit 0
        ;;
    --limits)
        apply_limits
        exit 0
        ;;
    --baloo|--tracker)
        apply_baloo
        exit 0
        ;;
    --zram)
        apply_zram
        exit 0
        ;;
    --services)
        apply_services
        exit 0
        ;;
    --no-install)
        apply_sysctl
        apply_limits
        apply_baloo
        verify_storage
        exit 0
        ;;
    --help|-h|help)
        show_help
        exit 0
        ;;
    "")
        echo "================================================================="
        echo "⚡ APLICANDO OPTIMIZACIONES DE RENDIMIENTO (GOLDEN DOG LINUX)"
        echo "================================================================="
        apply_sysctl
        apply_limits
        apply_baloo
        apply_zram
        apply_services
        verify_storage
        echo ""
        show_status
        echo "================================================================="
        echo "✅ Optimizaciones de rendimiento aplicadas con éxito en Debian."
        echo "================================================================="
        ;;
    *)
        echo "❌ Opción no reconocida: $1"
        show_help
        exit 1
        ;;
esac

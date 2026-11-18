#!/usr/bin/env bash
# ==============================================================================
# amd-setup.sh - Configuración independiente de hardware AMD (CPU + GPU)
# Sistema: Golden Dog Linux (Debian 13 Trixie) | Entorno: KDE Plasma (Wayland)
# ==============================================================================
# Características:
#   - Microcódigo oficial AMD (amd64-microcode) y firmware (firmware-amd-graphics)
#   - Stack gráfico Mesa AMD (RADV Vulkan, RadeonSI VA-API/VDPAU, radeontop)
#   - Soporte Vulkan/OpenGL 32-bit (i386) si multiarch está habilitado
#   - Variables de sesión Wayland (~/.config/environment.d/90-gpu-hardware.conf)
#   - Optimización KVM para procesadores AMD (/etc/modprobe.d/kvm_amd.conf)
#   - Opciones CLI: --status / -s, --env, --kvm, --help / -h
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo "❌ Error: 'sudo' no está disponible."
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

run_as_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" USER="$REAL_USER" "$@"
    else
        "$@"
    fi
}

show_help() {
    cat <<EOF
🔴 Configurador Independiente de Hardware AMD - Golden Dog Linux (Debian)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)    Instala microcódigo AMD, firmware, drivers Mesa (RADV/RadeonSI),
                      variables de entorno Wayland/VA-API y tuning KVM AMD.
  --env               Configura únicamente las variables de entorno GPU en ~/.config/environment.d/.
  --kvm               Configura únicamente el módulo KVM para AMD (/etc/modprobe.d/kvm_amd.conf).
  --status, -s        Muestra el estado del hardware, drivers AMD, VA-API, Vulkan y KVM.
  --help, -h          Muestra este mensaje de ayuda.
EOF
}

configure_env() {
    local env_dir="$USER_HOME/.config/environment.d"
    echo "⚙️ Configurando variables de entorno Wayland para GPU AMD (RadeonSI / RADV)..."
    run_as_user mkdir -p "$env_dir"
    cat <<'EOF' | run_as_user tee "$env_dir/90-gpu-hardware.conf" > /dev/null
# Aceleración por hardware AMD (VA-API RadeonSI / Vulkan RADV) en Wayland
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
AMD_VULKAN_ICD=RADV
EOF
    echo "  ✅ Variables AMD aplicadas en $env_dir/90-gpu-hardware.conf"
}

configure_kvm() {
    echo "⚙️ Configurando módulo KVM para procesadores AMD (/etc/modprobe.d/kvm_amd.conf)..."
    $SUDO mkdir -p /etc/modprobe.d
    cat <<'EOF' | $SUDO tee /etc/modprobe.d/kvm_amd.conf > /dev/null
# Configuración KVM para procesadores AMD (Virtualización anidada, AVIC y NPT)
options kvm_amd nested=1 avic=1 npt=1
EOF
    if lsmod | grep -q '^kvm_amd '; then
        if $SUDO modprobe -r kvm_amd kvm 2>/dev/null; then
            $SUDO modprobe kvm_amd 2>/dev/null || true
            echo "  ✅ Módulo kvm_amd recargado con nested=1, avic=1, npt=1."
        else
            echo "  ℹ️ kvm_amd está en uso; los nuevos parámetros se activarán al reiniciar."
        fi
    else
        $SUDO modprobe kvm_amd 2>/dev/null || true
        echo "  ✅ Parámetros kvm_amd configurados."
    fi
}

install_amd_stack() {
    echo "ℹ️ [1/3] Instalando microcódigo AMD y firmware oficial..."
    $SUDO apt-get update -qq
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
        amd64-microcode \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-amd-graphics \
        firmware-misc-nonfree 2>/dev/null || \
        $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y amd64-microcode firmware-linux-nonfree 2>/dev/null || true

    echo "ℹ️ [2/3] Instalando stack gráfico AMD Mesa (RADV / RadeonSI / VA-API / Vulkan)..."
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        mesa-vulkan-drivers \
        libva-wayland2 \
        vulkan-tools \
        vainfo \
        radeontop \
        mesa-utils \
        libgl1-mesa-dri 2>/dev/null || \
        $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y mesa-va-drivers mesa-vulkan-drivers vainfo || true

    if dpkg --print-foreign-architectures 2>/dev/null | grep -q "i386"; then
        echo "ℹ️ Arquitectura i386 detectada: Instalando drivers Mesa Vulkan/DRI 32-bit..."
        $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
            mesa-vulkan-drivers:i386 \
            libgl1-mesa-dri:i386 \
            libglx-mesa0:i386 2>/dev/null || true
    fi

    echo "ℹ️ [3/3] Aplicando variables de entorno y parámetros KVM AMD..."
    configure_env
    local cpu_vendor
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}' || true)
    if [ "$cpu_vendor" = "AuthenticAMD" ]; then
        configure_kvm
    fi
}

show_status() {
    local cpu_model gpu_info
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs || echo "Desconocido")
    gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -i 'amd\|ati' | head -n1 | cut -d: -f3 | xargs || echo "No detectada")

    echo "================================================================="
    echo "🔍 ESTADO DE HARDWARE Y DRIVERS AMD - GOLDEN DOG LINUX"
    echo "================================================================="
    echo "• CPU:                  $cpu_model"
    echo "• GPU AMD:              $gpu_info"
    echo "• amd64-microcode:      $(if dpkg -s amd64-microcode &>/dev/null; then echo '✅ Instalado'; else echo '❌ No instalado'; fi)"
    echo "• firmware-amd-graphics:$(if dpkg -s firmware-amd-graphics &>/dev/null; then echo '✅ Instalado'; else echo '⚠️ No instalado'; fi)"
    echo "• Mesa Vulkan (RADV):   $(if dpkg -s mesa-vulkan-drivers &>/dev/null; then echo '✅ Instalado'; else echo '❌ No instalado'; fi)"
    echo "• Mesa VA-API:          $(if dpkg -s mesa-va-drivers &>/dev/null; then echo '✅ Instalado'; else echo '❌ No instalado'; fi)"
    echo "• radeontop:            $(if command -v radeontop &>/dev/null; then echo '✅ Instalado'; else echo 'ℹ️ No instalado'; fi)"
    echo "• Entorno Wayland AMD:  $(if [ -f "$USER_HOME/.config/environment.d/90-gpu-hardware.conf" ]; then echo '✅ Configurado (radeonsi / RADV)'; else echo 'ℹ️ Automático por Mesa'; fi)"
    echo "• KVM AMD (modprobe):   $(if [ -f /etc/modprobe.d/kvm_amd.conf ]; then echo '✅ Configurado (nested, avic, npt)'; else echo 'ℹ️ Sin configurar'; fi)"
    if command -v vainfo &>/dev/null; then
        local va_driver
        va_driver=$(vainfo 2>&1 | grep "Driver version:" | sed 's/.*Driver version: //' || echo "n/a")
        echo "• VA-API activo:        $va_driver"
    fi
    echo "================================================================="
}

case "${1:-}" in
    --status|-s|status)
        show_status
        ;;
    --env)
        configure_env
        ;;
    --kvm)
        configure_kvm
        ;;
    --help|-h|help)
        show_help
        ;;
    "")
        echo "================================================================="
        echo "🔴 CONFIGURANDO HARDWARE AMD (CPU + GPU) - GOLDEN DOG LINUX"
        echo "================================================================="
        install_amd_stack
        echo "================================================================="
        echo "✅ Configuración AMD completada."
        echo "================================================================="
        ;;
    *)
        echo "❌ Opción no reconocida: $1"
        show_help
        exit 1
        ;;
esac

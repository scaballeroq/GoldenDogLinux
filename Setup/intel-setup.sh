#!/usr/bin/env bash
# ==============================================================================
# intel-setup.sh - Configuración independiente de hardware Intel (CPU + GPU)
# Sistema: Golden Dog Linux (Debian 13 Trixie) | Entorno: KDE Plasma (Wayland)
# ==============================================================================
# Características:
#   - Microcódigo oficial Intel (intel-microcode) y firmware Linux
#   - Stack gráfico Intel (intel-media-va-driver / i965-va-driver, Mesa ANV Vulkan)
#   - Herramientas de diagnóstico Intel (intel-gpu-tools, vainfo, vulkan-tools)
#   - Soporte Vulkan/OpenGL 32-bit (i386) si multiarch está habilitado
#   - Variables de sesión Wayland (~/.config/environment.d/90-gpu-hardware.conf)
#   - Optimización KVM para procesadores Intel (/etc/modprobe.d/kvm_intel.conf)
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
🔵 Configurador Independiente de Hardware Intel - Golden Dog Linux (Debian)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)    Instala microcódigo Intel, firmware, drivers VA-API (iHD/i965),
                      Mesa Vulkan (ANV), variables Wayland y tuning KVM Intel.
  --env               Configura únicamente las variables de entorno GPU en ~/.config/environment.d/.
  --kvm               Configura únicamente el módulo KVM para Intel (/etc/modprobe.d/kvm_intel.conf).
  --status, -s        Muestra el estado del hardware, drivers Intel, VA-API, Vulkan y KVM.
  --help, -h          Muestra este mensaje de ayuda.
EOF
}

detect_intel_va_driver() {
    # Si vainfo reporta iHD o si el hardware es Intel Gen 8+ (Broadwell en adelante), usar iHD; si es legacy, i965.
    if command -v vainfo &>/dev/null; then
        if vainfo 2>&1 | grep -qi "iHD"; then
            echo "iHD"
            return
        elif vainfo 2>&1 | grep -qi "i965"; then
            echo "i965"
            return
        fi
    fi
    echo "iHD"
}

configure_env() {
    local env_dir="$USER_HOME/.config/environment.d"
    local va_driver
    va_driver=$(detect_intel_va_driver)
    echo "⚙️ Configurando variables de entorno Wayland para GPU Intel (VA-API: $va_driver)..."
    run_as_user mkdir -p "$env_dir"
    cat <<EOF | run_as_user tee "$env_dir/90-gpu-hardware.conf" > /dev/null
# Aceleración por hardware Intel (VA-API $va_driver / Vulkan Mesa ANV) en Wayland
LIBVA_DRIVER_NAME=$va_driver
EOF
    echo "  ✅ Variables Intel aplicadas en $env_dir/90-gpu-hardware.conf"
}

configure_kvm() {
    echo "⚙️ Configurando módulo KVM para procesadores Intel (/etc/modprobe.d/kvm_intel.conf)..."
    $SUDO mkdir -p /etc/modprobe.d
    cat <<'EOF' | $SUDO tee /etc/modprobe.d/kvm_intel.conf > /dev/null
# Configuración KVM para procesadores Intel Core / Xeon (Nested, EPT, VPID, PML)
options kvm_intel nested=1 ept=1 vpid=1 pml=1
EOF
    if lsmod | grep -q '^kvm_intel '; then
        if $SUDO modprobe -r kvm_intel kvm 2>/dev/null; then
            $SUDO modprobe kvm_intel 2>/dev/null || true
            echo "  ✅ Módulo kvm_intel recargado con nested=1, ept=1, vpid=1, pml=1."
        else
            echo "  ℹ️ kvm_intel está en uso; los nuevos parámetros se activarán al reiniciar."
        fi
    else
        $SUDO modprobe kvm_intel 2>/dev/null || true
        echo "  ✅ Parámetros kvm_intel configurados."
    fi
}

install_intel_stack() {
    echo "ℹ️ [1/3] Instalando microcódigo Intel y firmware oficial..."
    $SUDO apt-get update -qq
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
        intel-microcode \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree 2>/dev/null || \
        $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y intel-microcode firmware-linux-nonfree 2>/dev/null || true

    echo "ℹ️ [2/3] Instalando stack gráfico Intel (iHD/i965 VA-API, Mesa ANV Vulkan)..."
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
        intel-media-va-driver \
        i965-va-driver \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        mesa-vulkan-drivers \
        libva-wayland2 \
        vulkan-tools \
        vainfo \
        intel-gpu-tools \
        mesa-utils \
        libgl1-mesa-dri 2>/dev/null || \
        $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y intel-media-va-driver i965-va-driver mesa-va-drivers vainfo || true

    # Driver propietario opcional para codecs/transcoding Intel si está disponible en non-free
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y intel-media-va-driver-non-free 2>/dev/null || true

    if dpkg --print-foreign-architectures 2>/dev/null | grep -q "i386"; then
        echo "ℹ️ Arquitectura i386 detectada: Instalando drivers Mesa Vulkan/DRI 32-bit..."
        $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
            mesa-vulkan-drivers:i386 \
            libgl1-mesa-dri:i386 \
            libglx-mesa0:i386 2>/dev/null || true
    fi

    echo "ℹ️ [3/3] Aplicando variables de entorno y parámetros KVM Intel..."
    configure_env
    local cpu_vendor
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}' || true)
    if [ "$cpu_vendor" = "GenuineIntel" ]; then
        configure_kvm
    fi
}

show_status() {
    local cpu_model gpu_info
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs || echo "Desconocido")
    gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -i 'intel' | head -n1 | cut -d: -f3 | xargs || echo "No detectada")

    echo "================================================================="
    echo "🔍 ESTADO DE HARDWARE Y DRIVERS INTEL - GOLDEN DOG LINUX"
    echo "================================================================="
    echo "• CPU:                    $cpu_model"
    echo "• GPU Intel:              $gpu_info"
    echo "• intel-microcode:        $(if dpkg -s intel-microcode &>/dev/null; then echo '✅ Instalado'; else echo '❌ No instalado'; fi)"
    echo "• intel-media-va-driver:  $(if dpkg -s intel-media-va-driver &>/dev/null || dpkg -s intel-media-va-driver-non-free &>/dev/null; then echo '✅ Instalado (iHD)'; else echo '⚠️ No instalado'; fi)"
    echo "• i965-va-driver:         $(if dpkg -s i965-va-driver &>/dev/null; then echo '✅ Instalado (Legacy)'; else echo 'ℹ️ No instalado'; fi)"
    echo "• Mesa Vulkan (ANV):      $(if dpkg -s mesa-vulkan-drivers &>/dev/null; then echo '✅ Instalado'; else echo '❌ No instalado'; fi)"
    echo "• intel-gpu-tools:        $(if command -v intel_gpu_top &>/dev/null; then echo '✅ Instalado'; else echo 'ℹ️ No instalado'; fi)"
    echo "• Entorno Wayland Intel:  $(if [ -f "$USER_HOME/.config/environment.d/90-gpu-hardware.conf" ]; then echo '✅ Configurado'; else echo 'ℹ️ Automático por Mesa'; fi)"
    echo "• KVM Intel (modprobe):   $(if [ -f /etc/modprobe.d/kvm_intel.conf ]; then echo '✅ Configurado (nested, ept, vpid, pml)'; else echo 'ℹ️ Sin configurar'; fi)"
    if command -v vainfo &>/dev/null; then
        local va_driver
        va_driver=$(vainfo 2>&1 | grep "Driver version:" | sed 's/.*Driver version: //' || echo "n/a")
        echo "• VA-API activo:          $va_driver"
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
        echo "🔵 CONFIGURANDO HARDWARE INTEL (CPU + GPU) - GOLDEN DOG LINUX"
        echo "================================================================="
        install_intel_stack
        echo "================================================================="
        echo "✅ Configuración Intel completada."
        echo "================================================================="
        ;;
    *)
        echo "❌ Opción no reconocida: $1"
        show_help
        exit 1
        ;;
esac

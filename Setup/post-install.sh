#!/bin/bash
# ==============================================================================
# post-install.sh - Despachador inteligente de post-instalación para Debian
# Detecta automáticamente el hardware (AMD vs Intel) para cualquier PC o portátil
# Nota: Gráficas Nvidia excluidas (solo soporte oficial para AMD e Intel)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat <<EOF
🚀 Despachador de Post-Instalación para Golden Dog Linux (Debian 13 KDE Plasma Wayland)
Compatible con cualquier ordenador de sobremesa o portátil (AMD o Intel; Nvidia excluido).

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)   Auto-detecta el procesador/GPU (AMD o Intel) y ejecuta el instalador correspondiente.
  --amd, -a          Ejecuta la configuración independiente para AMD (post-install-amd.sh + amd-setup.sh).
  --intel, -i        Ejecuta la configuración independiente para Intel (post-install-intel.sh + intel-setup.sh).
  --help, -h         Muestra este mensaje de ayuda.

Scripts independientes disponibles:
  • Setup/post-install-amd.sh   -> Post-instalación completa AMD (llama a Setup/amd-setup.sh)
  • Setup/post-install-intel.sh -> Post-instalación completa Intel (llama a Setup/intel-setup.sh)
  • Setup/amd-setup.sh          -> Drivers, microcódigo, Mesa RADV/VA-API y KVM específicos de AMD
  • Setup/intel-setup.sh        -> Drivers, microcódigo, VA-API iHD/i965, ANV y KVM específicos de Intel
EOF
}

if [ $# -gt 0 ]; then
    case "$1" in
        --amd|-a|amd)
            echo "🔴 Opción manual seleccionada: AMD"
            exec "$SCRIPT_DIR/post-install-amd.sh"
            ;;
        --intel|-i|intel)
            echo "🔵 Opción manual seleccionada: Intel"
            exec "$SCRIPT_DIR/post-install-intel.sh"
            ;;
        --help|-h|help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Opción no reconocida: $1"
            show_help
            exit 1
            ;;
    esac
fi

echo "🔍 Analizando procesador y tarjeta gráfica del sistema..."
CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}' || true)
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs || echo "Desconocido")

echo "💻 CPU Detectado: $CPU_MODEL (Vendor: ${CPU_VENDOR:-Desconocido})"

if command -v lspci &>/dev/null; then
    if lspci | grep -iE 'vga|3d|display' | grep -qi 'nvidia'; then
        echo "⚠️ Aviso: Se detectó una GPU Nvidia. Este repositorio excluye drivers Nvidia y soporta únicamente gráficos AMD e Intel."
    fi
fi

if [ "$CPU_VENDOR" == "AuthenticAMD" ]; then
    echo "✅ Hardware AMD detectado. Ejecutando post-install-amd.sh..."
    exec "$SCRIPT_DIR/post-install-amd.sh"
elif [ "$CPU_VENDOR" == "GenuineIntel" ]; then
    echo "✅ Hardware Intel detectado. Ejecutando post-install-intel.sh..."
    exec "$SCRIPT_DIR/post-install-intel.sh"
else
    echo "⚠️ No se pudo determinar automáticamente el fabricante del procesador."
    echo "¿Qué configuración deseas aplicar?"
    echo "1) AMD (CPU/GPU AMD)"
    echo "2) Intel (CPU/GPU Intel)"
    read -rp "Selecciona una opción (1 o 2): " CHOICE
    case "$CHOICE" in
        1)
            exec "$SCRIPT_DIR/post-install-amd.sh"
            ;;
        2)
            exec "$SCRIPT_DIR/post-install-intel.sh"
            ;;
        *)
            echo "❌ Selección inválida. Abortando."
            exit 1
            ;;
    esac
fi

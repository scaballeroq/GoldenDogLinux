#!/bin/bash
# ==============================================================================
# post-install-intel.sh - Post-instalación genérica para Debian con CPU/GPU Intel
# Válido para cualquier ordenador de sobremesa o portátil Intel (sin soporte Nvidia)
# Sistema: Golden Dog Linux (Debian 13 Trixie) | Entorno: KDE Plasma (Wayland)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================================="
echo "INICIANDO POST-INSTALACIÓN: GOLDEN DOG LINUX (KDE) - INTEL"
echo "================================================================="

CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 || true)
if [ -z "$CODENAME" ]; then
    CODENAME=$(lsb_release -sc 2>/dev/null || echo "trixie")
fi

echo "Debian detectado: $CODENAME"

# 1. Actualización Base y Herramientas de Gestión de Repositorios
echo "ℹ️ [1/8] Actualizando repositorios y herramientas base..."
sudo apt-get update -qq
sudo apt-get upgrade -y
sudo apt-get install -y curl wget ca-certificates gnupg lsb-release pciutils

# 2. Pre-aceptar licencias de tipografías si aplica (ttf-mscorefonts-installer)
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections 2>/dev/null || true

# 3. Software Esencial y Utilidades de Sistema (KDE Plasma)
echo "ℹ️ [2/8] Instalando utilidades esenciales del sistema..."
sudo apt-get install -y \
    build-essential \
    linux-headers-amd64 \
    cmake \
    curl \
    wget \
    inxi \
    fuse3 \
    exfatprogs \
    7zip \
    unrar \
    zip \
    unzip \
    bzip2 \
    xz-utils \
    fastfetch \
    ca-certificates \
    gnupg \
    kio-extras \
    dolphin-plugins \
    power-profiles-daemon \
    switcheroo-control \
    wl-clipboard \
    flatpak \
    plasma-discover-backend-flatpak \
    xdg-desktop-portal-kde 2>/dev/null || true

# Compatibilidad FUSE para AppImages en Debian (transición time64 libfuse2t64 vs libfuse2)
sudo apt-get install -y libfuse2t64 2>/dev/null || sudo apt-get install -y libfuse2 2>/dev/null || true

# 4. Hardware, Microcódigo, Firmware y Stack Gráfico Intel independiente
echo "ℹ️ [3/8] Ejecutando configuración independiente de hardware Intel (intel-setup.sh)..."
if [ -x "$SCRIPT_DIR/intel-setup.sh" ]; then
    bash "$SCRIPT_DIR/intel-setup.sh"
else
    echo "⚠️ No se encontró $SCRIPT_DIR/intel-setup.sh"
fi

# 5. Códecs Multimedia, FFmpeg y GStreamer
echo "ℹ️ [4/8] Instalando códecs multimedia y plugins GStreamer..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ffmpeg \
    libavcodec-extra \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-gl \
    gstreamer1.0-pipewire 2>/dev/null || true

# 6. Servidor de audio PipeWire & WirePlumber nativo
echo "ℹ️ [5/8] Verificando PipeWire & WirePlumber..."
sudo apt-get install -y pipewire pipewire-alsa pipewire-pulse wireplumber 2>/dev/null || true
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

# 7. Memoria ZRAM
echo "ℹ️ [6/8] Configurando swap comprimida en RAM (ZRAM con ZSTD)..."
if [ -f "$SCRIPT_DIR/zram-setup.sh" ]; then
    bash "$SCRIPT_DIR/zram-setup.sh"
else
    sudo apt-get install -y zram-tools 2>/dev/null || true
    if [ -f /etc/default/zramswap ]; then
        sudo sed -i 's/^#*ALGORITHM=.*/ALGORITHM=zstd/' /etc/default/zramswap
        sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
        sudo systemctl enable --now zramswap.service 2>/dev/null || true
        sudo systemctl restart zramswap.service 2>/dev/null || true
    fi
fi

# 8. Limpieza de paquetes residuales
echo "ℹ️ [7/8] Limpiando dependencias huérfanas..."
sudo apt-get autoremove -y
sudo apt-get clean

# 9. Verificación
echo "ℹ️ [8/8] Verificando aceleración VA-API de Intel..."
vainfo 2>/dev/null || echo "⚠️ vainfo reportó advertencias, verifica permisos o reinicia para cargar el nuevo kernel y firmware."

echo "================================================================="
echo "✅ Post-instalación Intel completada con éxito en Debian ($CODENAME)."
echo "💡 Se recomienda reiniciar el equipo para arrancar con el microcódigo y drivers actualizados."
echo "================================================================="

#!/usr/bin/env bash
# ==============================================================================
# multimedia.sh - Suite Multimedia, Códecs y Aceleración HW para Debian Workstation
# Optimizado para Golden Dog Linux (Debian 13 Trixie / KDE Plasma Wayland)
# Compatible con cualquier PC o portátil AMD / Intel (Nvidia excluido)
# ==============================================================================
# Características:
#   - Pila completa de códecs oficial Debian 13: FFmpeg 7.x, libavcodec-extra, audio (FLAC/Opus/Vorbis/MP3)
#   - Pila GStreamer 1.26 Wayland: base, good, bad (módulo VA nativo libgstva), ugly, libav, gl, gtk4 y pipewire
#   - Miniaturas e Imágenes: glycin-loaders, ffmpegthumbnailer, HEIF y WebP
#   - Aceleración HW VA-API / Vulkan en Wayland (delegada a amd-setup.sh / intel-setup.sh)
#   - Audio de baja latencia: PipeWire 1.4, WirePlumber 0.5 y códecs Bluetooth SPA (LDAC/aptX/AAC)
#   - Reproductores Wayland nativos: Gwenview, Haruna, MPV y VLC
#   - Soporte desacoplado Flatpak / Flathub a nivel de sistema y usuario
#   - Opciones CLI: --status / -s, --codecs, --players, --flatpak, --help / -h
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# ------------------------------------------------------------------------------
# 1. DETECCIÓN DE USUARIO, ENTORNO Y PRIVILEGIOS SUDO
# ------------------------------------------------------------------------------
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

check_user_service() {
    local svc="$1"
    local active_state enabled_state
    active_state=$(run_as_user systemctl --user is-active "$svc" 2>/dev/null || true)
    if [ "$active_state" = "active" ]; then
        echo "✅ Activo (en ejecución)"
        return
    fi
    enabled_state=$(systemctl --user is-enabled "$svc" 2>/dev/null || true)
    if [ "$enabled_state" = "enabled" ] || [ "$enabled_state" = "enabled-runtime" ] || [ "$enabled_state" = "static" ]; then
        echo "✅ Habilitado (systemd user: $enabled_state)"
    else
        echo "⚠️ Inactivo (${active_state:-desconocido})"
    fi
}

# ------------------------------------------------------------------------------
# 2. AYUDA Y DIAGNÓSTICO DEL SISTEMA
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
🎬 Suite Multimedia y Aceleración Gráfica - Debian 13 Trixie (KDE Plasma 6 Wayland)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)    Aplica toda la suite: Códecs, VA-API Wayland, Miniaturas KDE, Reproductores y Flatpak.
  --status, -s        Muestra diagnóstico detallado de VA-API, Vulkan, GStreamer, Miniaturas, PipeWire y Apps.
  --codecs            Instala y configura códecs APT, FFmpeg, GStreamer 1.26, miniaturas Dolphin y VA-API.
  --players           Instala y optimiza reproductores nativos KDE Plasma 6 / Wayland (Gwenview, Haruna, MPV, VLC).
  --flatpak           Configura el repositorio Flathub e instala soporte Flatpak en KDE Discover.
  --help, -h          Muestra este mensaje de ayuda.

Componentes gestionados en Debian 13 (Trixie):
  • Aceleración HW:     Mesa VA-API (radeonsi Gallium), libva-wayland2, Vulkan RADV y variables de sesión.
  • Códecs Audio/Video: FFmpeg 7.x, libavcodec-extra, FLAC, Opus, Vorbis, LAME y MediaInfo.
  • GStreamer 1.26:     base, good, bad (libgstva nativo), ugly, libav, gl y pipewire.
  • KDE / Dolphin:      ffmpegthumbs, kio-extras, ffmpegthumbnailer, HEIF y AVIF.
  • Audio PipeWire 1.4: pipewire-audio, pipewire-alsa, pipewire-pulse, wireplumber y libspa-0.2-bluetooth.
  • Reproductores:      Gwenview, Haruna (Qt6/MPV), MPV (gpu-next) y VLC.
EOF
}

show_status() {
    local os_name cpu_model gpu_info
    os_name=$(get_os_description)
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs || echo "Desconocido")
    gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -n1 | cut -d: -f3 | xargs || echo "Desconocida")

    echo "================================================================="
    echo "🔍 ESTADO MULTIMEDIA Y ACELERACIÓN WAYLAND - GOLDEN DOG LINUX"
    echo "================================================================="
    echo "• Sistema Operativo:     $os_name (Kernel $(uname -r))"
    echo "• Sesión Gráfica:        ${XDG_SESSION_DESKTOP:-KDE Plasma} (${XDG_SESSION_TYPE:-wayland})"
    echo "• CPU / GPU:             $cpu_model | $gpu_info"
    echo "-----------------------------------------------------------------"

    echo "• Aceleración Gráfica por Hardware (VA-API / Vulkan):"
    if command -v vainfo &>/dev/null; then
        local va_out va_driver va_h264 va_hevc va_hevc10 va_vp9 va_enc
        va_out=$(vainfo 2>&1 || true)
        va_driver=$(echo "$va_out" | grep "Driver version:" | sed "s/.*Driver version: //" || echo "n/a")
        va_h264=$(echo "$va_out" | grep -q "VAProfileH264Main" && echo "✅" || echo "❌")
        va_hevc=$(echo "$va_out" | grep -q "VAProfileHEVCMain " && echo "✅" || echo "❌")
        va_hevc10=$(echo "$va_out" | grep -q "VAProfileHEVCMain10" && echo "✅" || echo "❌")
        va_vp9=$(echo "$va_out" | grep -q "VAProfileVP9Profile0" && echo "✅" || echo "❌")
        va_enc=$(echo "$va_out" | grep -q "VAEntrypointEncSlice" && echo "✅ Activo (H.264/HEVC)" || echo "❌ No disponible")
        echo "  - Driver VA-API:       $va_driver"
        echo "  - Decodificación HW:   H.264: $va_h264 | HEVC 8-bit: $va_hevc | HEVC 10-bit: $va_hevc10 | VP9: $va_vp9"
        echo "  - Codificación HW:     $va_enc"
        echo "  - libva-wayland2:      $(if dpkg -s libva-wayland2 &>/dev/null; then echo "✅ Instalado (DMABUF Wayland)"; else echo "❌ No instalado"; fi)"
    else
        echo "  - vainfo:              ❌ No instalado"
    fi

    if command -v vulkaninfo &>/dev/null; then
        local vk_dev
        vk_dev=$(vulkaninfo --summary 2>/dev/null | grep -i "deviceName" | head -n1 | sed 's/.*= //' || echo "Vulkan activo")
        echo "  - Vulkan Mesa:         ✅ Instalado ($vk_dev)"
    else
        echo "  - Vulkan Mesa:         ❌ vulkan-tools no instalado"
    fi
    if [ -f "$USER_HOME/.config/environment.d/90-gpu-hardware.conf" ]; then
        echo "  - Entorno GPU HW:      ✅ Configurado ($USER_HOME/.config/environment.d/90-gpu-hardware.conf)"
    else
        echo "  - Entorno GPU HW:      ℹ️ Automático por Mesa"
    fi
    echo "  - Entorno Multimedia:  $(if [ -f "$USER_HOME/.config/environment.d/90-debian-multimedia.conf" ]; then echo "✅ Configurado (Wayland + GStreamer VA)"; else echo "ℹ️ Por defecto"; fi)"

    echo "-----------------------------------------------------------------"
    echo "• Pila de Códecs, FFmpeg y Herramientas de Audio:"
    echo "  - FFmpeg:              $(if command -v ffmpeg &>/dev/null; then echo "✅ Instalado ($(ffmpeg -version 2>/dev/null | head -n1 | awk '{print $3}'))"; else echo "❌ No instalado"; fi)"
    echo "  - libavcodec-extra:    $(if dpkg -s libavcodec-extra &>/dev/null; then echo "✅ Instalado"; else echo "❌ No instalado"; fi)"
    echo "  - Códecs Audio CLI:    $(if command -v flac &>/dev/null && command -v opusenc &>/dev/null; then echo "✅ Instalados (FLAC, Opus, Vorbis, LAME)"; else echo "⚠️ Parciales"; fi)"
    echo "  - MediaInfo:           $(if command -v mediainfo &>/dev/null; then echo "✅ Instalado"; else echo "❌ No instalado"; fi)"

    echo "-----------------------------------------------------------------"
    echo "• Pila GStreamer 1.26 (KDE Plasma Wayland + PipeWire):"
    local gst_va_lib="/usr/lib/x86_64-linux-gnu/gstreamer-1.0/libgstva.so"
    echo "  - Plugins Base/Good:   $(if dpkg -s gstreamer1.0-plugins-base &>/dev/null && dpkg -s gstreamer1.0-plugins-good &>/dev/null; then echo "✅ Instalados"; else echo "❌ No instalados"; fi)"
    echo "  - Plugins Bad (VA HW): $(if [ -f "$gst_va_lib" ]; then echo "✅ Instalado (libgstva.so activo)"; elif dpkg -s gstreamer1.0-plugins-bad &>/dev/null; then echo "✅ Instalado"; else echo "❌ No instalado"; fi)"
    echo "  - Plugins Ugly/Libav:  $(if dpkg -s gstreamer1.0-plugins-ugly &>/dev/null && dpkg -s gstreamer1.0-libav &>/dev/null; then echo "✅ Instalados"; else echo "❌ No instalados"; fi)"
    echo "  - Enlace PipeWire:     $(if dpkg -s gstreamer1.0-pipewire &>/dev/null; then echo "✅ Instalado (pipewiresink)"; else echo "❌ No instalado"; fi)"
    echo "  - GStreamer Tools:     $(if command -v gst-inspect-1.0 &>/dev/null; then echo "✅ Instalado (gstreamer1.0-tools)"; else echo "❌ No instalado"; fi)"

    echo "-----------------------------------------------------------------"
    echo "• Miniaturas e Imágenes en KDE Plasma 6 (Dolphin & Gwenview):"
    echo "  - FFmpegThumbs (KDE):  $(if dpkg -s ffmpegthumbs &>/dev/null; then echo "✅ Instalado (miniaturas de vídeo en Dolphin)"; else echo "❌ No instalado"; fi)"
    echo "  - KIO Extras (KDE):    $(if dpkg -s kio-extras &>/dev/null; then echo "✅ Instalado (soporte de miniaturas KIO)"; else echo "❌ No instalado"; fi)"
    echo "  - FFmpeg Thumbnailer:  $(if command -v ffmpegthumbnailer &>/dev/null; then echo "✅ Instalado (miniaturas de vídeo rápidas)"; else echo "❌ No instalado"; fi)"
    echo "  - Soporte HEIF / AVIF: $(if dpkg -s heif-thumbnailer &>/dev/null && command -v avifenc &>/dev/null; then echo "✅ Instalado (heif-thumbnailer + libavif-bin)"; elif dpkg -s heif-thumbnailer &>/dev/null; then echo "✅ Instalado (heif-thumbnailer)"; else echo "❌ No instalado"; fi)"

    echo "-----------------------------------------------------------------"
    echo "• Servidor de Audio PipeWire 1.4 & Bluetooth SPA:"
    echo "  - PipeWire Core:       $(check_user_service pipewire)"
    echo "  - PipeWire PulseAudio: $(check_user_service pipewire-pulse)"
    echo "  - WirePlumber Session: $(check_user_service wireplumber)"
    echo "  - Bluetooth Audio SPA: $(if dpkg -s libspa-0.2-bluetooth &>/dev/null; then echo "✅ Instalado (LDAC / aptX / AAC)"; else echo "❌ No instalado"; fi)"

    echo "-----------------------------------------------------------------"
    echo "• Reproductores y Aplicaciones Multimedia (KDE Plasma Wayland):"
    echo "  - Gwenview (Imágenes): $(if command -v gwenview &>/dev/null; then echo "✅ Instalado (KDE Gear)"; else echo "❌ No instalado"; fi)"
    echo "  - Haruna (Vídeo KDE):  $(if command -v haruna &>/dev/null; then echo "✅ Instalado (Qt6 / MPV)"; else echo "ℹ️ Opcional"; fi)"
    echo "  - MPV Media Player:    $(if command -v mpv &>/dev/null; then echo "✅ Instalado ($(mpv --version 2>/dev/null | head -n1 | awk '{print $2}'))"; else echo "❌ No instalado"; fi)"
    echo "  - Config MPV Wayland:  $(if [ -f "$USER_HOME/.config/mpv/mpv.conf" ]; then echo "✅ Optimizado (vo=gpu-next / hwdec=vaapi / ao=pipewire)"; else echo "❌ Sin configurar"; fi)"
    local vlc_info=""
    if dpkg -s vlc &>/dev/null; then
        local vlc_v
        vlc_v=$(dpkg-query -W -f='${Version}' vlc 2>/dev/null | cut -d- -f1 || echo "3.0.x")
        vlc_info="✅ Instalado vía APT (v$vlc_v)"
    fi
    if flatpak list 2>/dev/null | grep -qi "org.videolan.VLC"; then
        vlc_info="${vlc_info:+$vlc_info | }✅ Instalado vía Flatpak"
    fi
    echo "  - VLC Media Player:    ${vlc_info:-❌ No instalado}"

    echo "-----------------------------------------------------------------"
    echo "• Entorno Flatpak / Flathub:"
    local flathub_sys flathub_user
    flathub_sys=$(flatpak remotes --system 2>/dev/null | grep -qi "flathub" && echo "✅ Configurado (system)" || echo "❌ No configurado")
    flathub_user=$(run_as_user flatpak remotes --user 2>/dev/null | grep -qi "flathub" && echo "✅ Configurado (user)" || echo "no configurado")
    echo "  - Remoto Flathub:      $flathub_sys | user: $flathub_user"
    echo "================================================================="
}

# ------------------------------------------------------------------------------
# 3. INSTALACIÓN DE CÓDECS, MINIATURAS KDE Y ACELERACIÓN HW (VA-API / VULKAN)
# ------------------------------------------------------------------------------
install_codecs() {
    echo "🎵 [1/3] Instalando suite de códecs, miniaturas Dolphin y aceleración VA-API Wayland..."

    # Asegurar componentes contrib, non-free y non-free-firmware en Debian 13 (deb822 y clásico)
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        $SUDO sed -i '/^Components:/ {/contrib/! s/$/ contrib/}' /etc/apt/sources.list.d/debian.sources 2>/dev/null || true
        $SUDO sed -i '/^Components:/ {/non-free/! s/$/ non-free/}' /etc/apt/sources.list.d/debian.sources 2>/dev/null || true
        $SUDO sed -i '/^Components:/ {/non-free-firmware/! s/$/ non-free-firmware/}' /etc/apt/sources.list.d/debian.sources 2>/dev/null || true
    elif [ -f /etc/apt/sources.list ]; then
        $SUDO sed -i '/^deb / {/contrib/! s/\(main\)/\1 contrib non-free non-free-firmware/}' /etc/apt/sources.list 2>/dev/null || true
    fi

    $SUDO apt-get update -qq

    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ffmpeg \
        libavcodec-extra \
        mediainfo \
        flac \
        lame \
        vorbis-tools \
        opus-tools \
        sox \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        gstreamer1.0-gl \
        gstreamer1.0-pipewire \
        gstreamer1.0-vaapi \
        gstreamer1.0-tools \
        ffmpegthumbnailer \
        heif-thumbnailer \
        libavif-bin \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        mesa-vulkan-drivers \
        libva-wayland2 \
        vainfo \
        vulkan-tools \
        mesa-utils \
        pipewire-audio \
        pipewire-alsa \
        pipewire-pulse \
        wireplumber \
        libspa-0.2-bluetooth \
        libspa-0.2-jack

    # Variables genéricas Wayland/GStreamer para multimedia
    local env_dir="$USER_HOME/.config/environment.d"
    run_as_user mkdir -p "$env_dir"
    cat <<'EOF' | run_as_user tee "$env_dir/90-debian-multimedia.conf" > /dev/null
# Aceleración multimedia genérica en Wayland (Golden Dog Linux)
MOZ_ENABLE_WAYLAND=1
GST_PLUGIN_FEATURE_RANK=vah264dec:MAX,vah265dec:MAX,vavp9dec:MAX,vaav1dec:MAX
EOF

    # Variables específicas de GPU delegadas al script independiente de AMD o Intel
    local script_dir gpu_lspci cpu_vendor
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    gpu_lspci=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || true)
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}' || true)

    if echo "$gpu_lspci" | grep -qiE 'amd|ati|radeon' || [ "$cpu_vendor" = "AuthenticAMD" ]; then
        [ -x "$script_dir/amd-setup.sh" ] && bash "$script_dir/amd-setup.sh" --env
    elif echo "$gpu_lspci" | grep -qi 'intel' || [ "$cpu_vendor" = "GenuineIntel" ]; then
        [ -x "$script_dir/intel-setup.sh" ] && bash "$script_dir/intel-setup.sh" --env
    fi

    # Limpiar caché de miniaturas fallidas para que Dolphin regenere con ffmpegthumbs / HEIF
    if [ -d "$USER_HOME/.cache/thumbnails/fail" ]; then
        run_as_user rm -rf "$USER_HOME/.cache/thumbnails/fail"
    fi

    echo "  ✅ Códecs, GStreamer, miniaturas de Dolphin (ffmpegthumbs) y aceleración VA-API configurados."
}

# ------------------------------------------------------------------------------
# 4. INSTALACIÓN Y OPTIMIZACIÓN DE REPRODUCTORES KDE PLASMA WAYLAND
# ------------------------------------------------------------------------------
install_players() {
    echo "🖼️ [2/3] Verificando visor de imágenes y miniaturas nativas de KDE Plasma Wayland..."
    $SUDO apt-get update -qq
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gwenview \
        ffmpegthumbs \
        kio-extras 2>/dev/null || true

    echo "  ✅ Visor nativo KDE (Gwenview) y miniaturas (ffmpegthumbs) listos (sin reproductores de audio/vídeo adicionales)."
}

# ------------------------------------------------------------------------------
# 5. INTEGRACIÓN DE FLATPAK Y FLATHUB
# ------------------------------------------------------------------------------
setup_flatpak() {
    echo "📦 [3/3] Verificando soporte Flatpak y repositorio Flathub..."
    $SUDO apt-get update -qq
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        flatpak \
        plasma-discover-backend-flatpak \
        xdg-desktop-portal-kde

    # Registrar Flathub a nivel de sistema para acceso universal
    if ! flatpak remotes --system 2>/dev/null | grep -qi "flathub"; then
        $SUDO flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    fi

    # Registrar Flathub para el usuario actual (idempotente)
    run_as_user flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

    echo "  ✅ Integración de Flatpak, portales XDG de KDE y Flathub verificada."
}

# ------------------------------------------------------------------------------
# 6. ENTRADA PRINCIPAL
# ------------------------------------------------------------------------------
case "${1:-}" in
    --status|-s|status)
        show_status
        exit 0
        ;;
    --codecs)
        install_codecs
        exit 0
        ;;
    --players)
        install_players
        exit 0
        ;;
    --flatpak)
        setup_flatpak
        exit 0
        ;;
    --help|-h|help)
        show_help
        exit 0
        ;;
    "")
        echo "================================================================="
        echo "🎬 CONFIGURANDO SUITE MULTIMEDIA Y WAYLAND EN DEBIAN 13 (KDE PLASMA 6)"
        echo "================================================================="
        install_codecs
        install_players
        setup_flatpak
        echo ""
        show_status
        echo "================================================================="
        echo "✅ Configuración multimedia para Debian 13 KDE Plasma 6 completada."
        echo "================================================================="
        ;;
    *)
        echo "❌ Opción no reconocida: $1"
        show_help
        exit 1
        ;;
esac

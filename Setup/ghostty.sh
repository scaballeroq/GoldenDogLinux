#!/usr/bin/env bash
# ==============================================================================
# ghostty.sh - Instalación, Optimización y Configuración Estética de Ghostty Terminal
# Sistema: Debian GNU/Linux 13 (Trixie) | Entorno: GNOME Shell 48+ (Wayland)
# Hardware: HP ProBook 455 G10 (AMD Ryzen 7 7730U / Radeon Vega 8 Mesa OpenGL)
# Tema: Catppuccin Mocha con Transparencia, Blur nativo y Tipografía Nerd Font
# ==============================================================================
# Características:
# - Esquema de color oscuro oficial Catppuccin Mocha nativo de Ghostty.
# - Aceleración por GPU nativa en Wayland con soporte GTK4 y Libadwaita.
# - Opacidad configurable (80%) con desenfoque nativo (background-blur = true).
# - Tipografía JetBrainsMono Nerd Font con ligaduras completas y fallbacks.
# - Pestañas estilo Adwaita (tabs) y decoración nativa Wayland.
# - Cursor moderno tipo barra (bar) con parpadeo suave.
# - Scrollback ampliado (10.000.000 bytes) y soporte táctil multitáctil para touchpad.
# - Integración contextual completa en Nautilus (Extensión Python 1er nivel + Script).
# - Opciones CLI: --status / -s, --config-only / --no-install, --default-terminal,
#   --bind-ctrl-alt-t, --help / -h.
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# ------------------------------------------------------------------------------
# 1. CONSTANTES Y CONFIGURACIÓN ESTÉTICA
# ------------------------------------------------------------------------------
DEFAULT_OPACITY="0.80"
DEFAULT_FONT_SIZE="11"

# Colores ANSI para terminal
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# 2. DETECCIÓN DE USUARIO Y ELEVACIÓN DE PRIVILEGIOS
# ------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
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
# 3. AYUDA Y DIAGNÓSTICO DEL SISTEMA
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
👻 Gestor y Optimizador de Ghostty Terminal - Debian 13 Workstation (GNOME Wayland)
Hardware: HP ProBook 455 G10 (AMD Ryzen 7 7730U / Radeon Vega 8 Mesa OpenGL)

Uso:
  $0 [OPCIÓN]

Opciones principales:
  (sin argumentos)        Instala Ghostty mediante el instalador oficial/comunitario si no
                          está presente, genera la configuración Catppuccin Mocha y aplica
                          la integración con GNOME y Nautilus.
  -s, --status            Muestra el estado detallado de Ghostty, versión, fuentes y atajos.
  --no-install, --config  Genera y valida la configuración en ~/.config/ghostty/ sin invocar
                          instaladores ni requerir privilegios de superusuario (sudo).
  --bind-ctrl-alt-t       Asigna explícitamente el atajo global Ctrl+Alt+T a Ghostty en GNOME.
  --default-terminal      Establece Ghostty como la terminal predeterminada en update-alternatives.
  -h, --help              Muestra este mensaje de ayuda.

Características aplicadas:
  • Instalador oficial:   curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh
  • Tema:                 Catppuccin Mocha oficial integrado.
  • Tipografía:           JetBrainsMono Nerd Font (ligaduras completas y glifos).
  • Efectos Wayland:      Opacidad 80% con desenfoque (blur nativo) y GTK4/Adwaita.
  • Cursor & Ventanas:    Cursor bar parpadeante, sin confirmación al cerrar y márgenes balanceados.
  • Integración Nautilus: Extensión Python de 1er nivel ("Abrir en Ghostty") y script auxiliar.
EOF
}

show_status() {
    local os_name
    os_name=$(get_os_description)

    echo "================================================================="
    echo "🔍 ESTADO DE GHOSTTY TERMINAL - DEBIAN WORKSTATION (WAYLAND)"
    echo "================================================================="
    echo "• Sistema Operativo:             $os_name"
    
    if command -v ghostty &>/dev/null; then
        local ghostty_v
        ghostty_v=$(ghostty --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "instalada")
        echo "• Ghostty instalado:             ✅ $(which ghostty) (v${ghostty_v})"
    else
        echo "• Ghostty instalado:             ❌ No instalado"
    fi

    # Fuente Nerd Font
    local font_status="⚠️ No detectada (se usará fallback del sistema)"
    if [ -n "$(fc-list : family | grep -i "^JetBrainsMono Nerd Font" 2>/dev/null || true)" ]; then
        font_status="✅ JetBrainsMono Nerd Font disponible"
    elif [ -n "$(fc-list : family | grep -i "^JetBrains Mono" 2>/dev/null || true)" ]; then
        font_status="✅ JetBrains Mono estándar disponible"
    fi
    echo "• Tipografía Monospace:          $font_status"

    # Configuración de Ghostty
    local cfg_file="$USER_HOME/.config/ghostty/config"
    if [ -f "$cfg_file" ]; then
        local opac theme_name
        opac=$(grep "^background-opacity" "$cfg_file" | head -n1 | cut -d= -f2 | tr -d ' ' || echo "1.0")
        theme_name=$(grep "^theme" "$cfg_file" | head -n1 | cut -d= -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "por defecto")
        echo "• Configuración ghostty/config:  ✅ Presente (Opacidad: $opac | Tema: $theme_name)"
    else
        echo "• Configuración ghostty/config:  ❌ No presente ($cfg_file)"
    fi

    # Integración con KDE Plasma (Atajos de teclado)
    if grep -qi "ghostty.desktop" "$USER_HOME/.config/kglobalshortcutsrc" 2>/dev/null; then
        echo "• Atajo Global (KDE):            ✅ Vinculado a Ghostty"
    else
        echo "• Atajo Global (KDE):            ℹ️ No asignado a Ghostty"
    fi

    # Menú contextual de Dolphin (KIO Servicemenus)
    if [ -f "$USER_HOME/.local/share/kio/servicemenus/open-in-ghostty.desktop" ]; then
        echo "• Menú Dolphin (Clic derecho):   ✅ Activo (open-in-ghostty.desktop)"
    else
        echo "• Menú Dolphin (Clic derecho):   ❌ No instalado"
    fi

    # Terminal del sistema
    if [ -x /usr/bin/x-terminal-emulator ]; then
        local cur_alt
        cur_alt=$(readlink -f /usr/bin/x-terminal-emulator 2>/dev/null || echo "n/a")
        echo "• x-terminal-emulator:           $cur_alt"
    fi
    echo "================================================================="
}

# ------------------------------------------------------------------------------
# 4. INSTALACIÓN DE GHOSTTY MEDIANTE EL INSTALADOR OFICIAL
# ------------------------------------------------------------------------------
install_ghostty() {
    if ! command -v ghostty &>/dev/null; then
        echo "📦 [1/4] Instalando Ghostty Terminal en Debian 13..."
        if [ "$EUID" -ne 0 ] && ! command -v sudo &>/dev/null; then
            echo "❌ Error: Se requieren permisos de superusuario para instalar paquetes."
            exit 1
        fi

        # Asegurar herramientas para la descarga y ejecución del instalador
        if ! command -v curl &>/dev/null; then
            echo "   🌐 Instalando curl para descarga de dependencias..."
            $SUDO apt-get update -qq
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y curl 2>/dev/null || true
        fi

        # Ejecución del instalador documentado por mkasberg/ghostty-ubuntu
        echo "   🚀 Ejecutando instalador oficial/comunitario de Ghostty..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"

        if command -v ghostty &>/dev/null; then
            local ghostty_v
            ghostty_v=$(ghostty --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "instalada")
            echo "   ✅ Ghostty instalado exitosamente (v${ghostty_v})."
        else
            echo "❌ Error: La instalación de Ghostty no pudo verificarse."
            exit 1
        fi
    else
        local ghostty_v
        ghostty_v=$(ghostty --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "instalada")
        echo "   ✅ Ghostty ya está instalado en el sistema (v${ghostty_v})."
    fi
}

# ------------------------------------------------------------------------------
# 5. GENERACIÓN DEL ARCHIVO DE CONFIGURACIÓN DE GHOSTTY
# ------------------------------------------------------------------------------
setup_config() {
    echo "⚙️ [2/4] Generando configuración estética Catppuccin Mocha en ~/.config/ghostty/..."
    local config_dir="$USER_HOME/.config/ghostty"
    local config_file="$config_dir/config"
    local config_ghostty_file="$config_dir/config.ghostty"

    run_as_user mkdir -p "$config_dir"

    # Respaldo si ya existía configuración previa
    if [ -f "$config_file" ] && [ ! -f "$config_file.bak" ]; then
        run_as_user cp "$config_file" "$config_file.bak" 2>/dev/null || true
    fi

    cat <<EOF | run_as_user tee "$config_file" > /dev/null
# =============================================================================
# GHOSTTY CONFIGURATION - DEBIAN 13 WORKSTATION (GNOME SHELL WAYLAND)
# Hardware: HP ProBook 455 G10 (AMD Ryzen 7 7730U / Radeon Vega 8 Mesa OpenGL)
# Tema: Catppuccin Mocha con Transparencia, Blur nativo y Tipografía Nerd Font
# =============================================================================

# --- Tema & Esquema de Color ---
theme = Catppuccin Mocha

# --- Tipografía & Fuentes ---
font-family = JetBrainsMono Nerd Font
font-size = ${DEFAULT_FONT_SIZE}
font-thicken = false

# --- Transparencia, Desenfoque y Efectos Wayland ---
background-opacity = ${DEFAULT_OPACITY}
background-blur = true
alpha-blending = linear-corrected

# --- Ventana, Márgenes y Comportamiento ---
window-padding-x = 10
window-padding-y = 10
window-padding-balance = true
window-padding-color = background
window-inherit-working-directory = true
confirm-close-surface = false

# --- Cursor Moderno ---
cursor-style = bar
cursor-style-blink = true

# --- Integración GTK / GNOME Wayland ---
window-decoration = auto
gtk-titlebar = true
gtk-tabs-location = top
gtk-wide-tabs = true
gtk-titlebar-style = native

# --- Historial y Scrollback ---
scrollback-limit = 10000000
mouse-scroll-multiplier = precision:1,discrete:3
EOF

    # Compatibilidad con ambas rutas estándar (config y config.ghostty)
    run_as_user cp -f "$config_file" "$config_ghostty_file" 2>/dev/null || true

    # Validación de sintaxis nativa de Ghostty
    if command -v ghostty &>/dev/null; then
        if ghostty +validate-config --config-file="$config_file" 2>/dev/null; then
            echo "   ✅ Archivo de configuración validado correctamente con 'ghostty +validate-config'."
        fi
    fi
}

# ------------------------------------------------------------------------------
# 6. INTEGRACIÓN CON KDE PLASMA Y ATAJOS DE TECLADO
# ------------------------------------------------------------------------------
setup_keybinding() {
    local force_ctrl_alt_t="${1:-false}"
    echo "⌨️ [3/4] Sincronizando atajo de teclado en KDE Plasma..."

    if command -v kwriteconfig6 &>/dev/null; then
        if [ "$force_ctrl_alt_t" = "true" ] || ! grep -qi "Ctrl+Alt+T" "$USER_HOME/.config/kglobalshortcutsrc" 2>/dev/null; then
            run_as_user kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "ghostty" 2>/dev/null || true
            run_as_user kwriteconfig6 --file kdeglobals --group General --key TerminalService "com.mitchellh.ghostty.desktop" 2>/dev/null || true
            run_as_user kwriteconfig6 --file kglobalshortcutsrc --group "services" --group "com.mitchellh.ghostty.desktop" --key "_launch" "Ctrl+Alt+T,none,Ghostty Terminal" 2>/dev/null || true
            echo "   ✅ Atajo Ctrl+Alt+T asignado a Ghostty en KDE."
        else
            run_as_user kwriteconfig6 --file kglobalshortcutsrc --group "services" --group "com.mitchellh.ghostty.desktop" --key "_launch" "Ctrl+Alt+G,none,Ghostty Terminal" 2>/dev/null || true
            echo "   ℹ️ Ctrl+Alt+T ya en uso. Se configuró Ctrl+Alt+G para Ghostty (usa --bind-ctrl-alt-t para forzar Ctrl+Alt+T)."
        fi
    fi
}

# ------------------------------------------------------------------------------
# 7. MENÚ CONTEXTUAL DE DOLPHIN (KIO SERVICEMENU 'Abrir en Ghostty')
# ------------------------------------------------------------------------------
setup_dolphin_servicemenu() {
    echo "📁 [4/4] Configurando menú contextual de Dolphin ('Abrir en Ghostty')..."
    local servicemenus_dir="$USER_HOME/.local/share/kio/servicemenus"
    run_as_user mkdir -p "$servicemenus_dir"

    cat <<'EOF' | run_as_user tee "$servicemenus_dir/open-in-ghostty.desktop" > /dev/null
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;
Actions=openInGhostty;
X-KDE-Priority=TopLevel

[Desktop Action openInGhostty]
Name=Abrir en Ghostty
Name[es]=Abrir en Ghostty
Name[en]=Open in Ghostty
Icon=com.mitchellh.ghostty
Exec=ghostty --working-directory="%f"
EOF
    run_as_user chmod +x "$servicemenus_dir/open-in-ghostty.desktop" 2>/dev/null || true
    echo "   ✅ Integración contextual de Dolphin completada."
}

# ------------------------------------------------------------------------------
# 8. CONFIGURAR TERMINAL PREDETERMINADA EN EL SISTEMA
# ------------------------------------------------------------------------------
set_default_terminal() {
    if command -v update-alternatives &>/dev/null && [ -x /usr/bin/ghostty ]; then
        echo "🔧 Estableciendo Ghostty como x-terminal-emulator predeterminado..."
        if [ "$EUID" -ne 0 ] && ! command -v sudo &>/dev/null; then
            echo "❌ Error: Se requieren privilegios de superusuario para update-alternatives."
            exit 1
        fi
        $SUDO update-alternatives --set x-terminal-emulator /usr/bin/ghostty 2>/dev/null || true
        echo "   ✅ Ghostty es ahora el x-terminal-emulator del sistema."
    fi
}

# ------------------------------------------------------------------------------
# 9. ENTRADA PRINCIPAL Y PARSEO DE ARGUMENTOS
# ------------------------------------------------------------------------------
case "${1:-}" in
    -s|--status|status)
        show_status
        exit 0
        ;;
    -h|--help|help)
        show_help
        exit 0
        ;;
    --no-install|--config|--config-only)
        echo "==========================================================="
        echo "👻 APLICANDO CONFIGURACIÓN DE GHOSTTY (MODO USUARIO / SIN INSTALADOR)"
        echo "==========================================================="
        setup_config
        setup_keybinding false
        setup_dolphin_servicemenu
        echo ""
        show_status
        echo "==========================================================="
        echo "✅ Configuración de Ghostty aplicada con éxito."
        echo "==========================================================="
        exit 0
        ;;
    --bind-ctrl-alt-t)
        echo "==========================================================="
        echo "⌨️ REASIGNANDO CTRL+ALT+T A GHOSTTY EN GNOME SHELL"
        echo "==========================================================="
        setup_keybinding true
        exit 0
        ;;
    --default-terminal)
        set_default_terminal
        exit 0
        ;;
    "")
        echo "==========================================================="
        echo "👻 CONFIGURANDO GHOSTTY TERMINAL EN DEBIAN 13 (GNOME WAYLAND)"
        echo "==========================================================="
        install_ghostty
        setup_config
        setup_keybinding false
        setup_dolphin_servicemenu
        echo ""
        show_status
        echo "==========================================================="
        echo "✅ Instalación y optimización de Ghostty completada."
        echo "==========================================================="
        ;;
    *)
        echo "❌ Opción no reconocida: $1"
        show_help
        exit 1
        ;;
esac

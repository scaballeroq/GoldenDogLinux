#!/usr/bin/env bash
# ==============================================================================
# kde-settings.sh - Optimización Funcional de KDE Plasma 6 (Sin Alterar Apariencia)
# Golden Dog Linux (Debian 13 Trixie + KDE Plasma Wayland)
# ==============================================================================
# Diseñado para preservar al 100% la personalización visual de Golden Dog Linux
# (temas, colores, iconos, cursores, paneles y decoración de ventanas intactos),
# optimizando únicamente productividad funcional: paquetes KDE Gear, Dolphin,
# miniaturas multimedia, atajo global Ctrl+Alt+T y menús contextuales KIO.
# ==============================================================================

set -euo pipefail

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

REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")

run_as_user() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$REAL_UID}"
    local dbus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime_dir/bus}"
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        sudo -u "$REAL_USER" env \
            HOME="$USER_HOME" \
            USER="$REAL_USER" \
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

detect_preferred_terminal() {
    if command -v kitty &>/dev/null; then
        echo "kitty"
    elif command -v konsole &>/dev/null; then
        echo "konsole"
    else
        echo "kitty"
    fi
}

show_help() {
    cat <<EOF
⚙️ Optimizador Funcional de KDE Plasma 6 - Golden Dog Linux (Debian 13)
(Preserva íntegramente la apariencia visual nativa de Golden Dog Linux)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)    Instala utilidades KDE Gear esenciales y aplica mejoras funcionales
                      en Dolphin, terminal predeterminada, Ctrl+Alt+T y servicemenus KIO.
  --no-install        Aplica únicamente la configuración de usuario (sin invocar APT/sudo).
  --status, -s        Muestra el estado de componentes funcionales y atajos en Plasma 6.
  --help, -h          Muestra este mensaje de ayuda.

Acciones que realiza este script (sin tocar temas ni apariencia):
  • Paquetes KDE Gear: Instala utilidades oficiales (Dolphin, Kate, Spectacle, Okular,
                       Gwenview, Ark, kio-extras, dolphin-plugins, ffmpegthumbs, wl-clipboard).
  • Productividad:     Dolphin en modo detallado con vista previa de miniaturas multimedia.
  • Terminal & Atajos: Configura la terminal preferida (Kitty/Konsole) y Ctrl+Alt+T.
  • Menú contextual:   Acciones de clic derecho en Dolphin (Abrir en Kitty, Antigravity, IDE).
EOF
}

show_status() {
    local terminal
    terminal=$(run_as_user kreadconfig6 --file kdeglobals --group General --key TerminalApplication 2>/dev/null || echo "konsole")

    echo "================================================================="
    echo "🔍 ESTADO FUNCIONAL DE KDE PLASMA 6 - GOLDEN DOG LINUX"
    echo "================================================================="
    echo "• Entorno de escritorio:  ${XDG_CURRENT_DESKTOP:-KDE} (${XDG_SESSION_TYPE:-wayland})"
    echo "• Versión de Plasma:      $(plasmashell --version 2>/dev/null || echo 'Plasma 6')"
    echo "• Versión de KWin:        $(kwin_wayland --version 2>/dev/null || echo 'KWin 6')"
    echo "-----------------------------------------------------------------"
    echo "• Terminal configurada:   $terminal"
    echo "• Atajo KDE (Ctrl+Alt+T): $(if grep -qi "Ctrl+Alt+T" "$USER_HOME/.config/kglobalshortcutsrc" 2>/dev/null; then echo "✅ Configurado"; else echo "❌ No configurado"; fi)"
    echo "• Servicemenus Dolphin:   $(if [ -f "$USER_HOME/.local/share/kio/servicemenus/open-in-kitty.desktop" ]; then echo "✅ Kitty / Antigravity instalados"; else echo "❌ No instalados"; fi)"
    echo "• Apariencia Golden Dog:  ✅ Intacta (no modificada por este script)"
    echo "================================================================="
}

NO_INSTALL=false
case "${1:-}" in
    --help|-h|help)
        show_help
        exit 0
        ;;
    --status|-s|status)
        show_status
        exit 0
        ;;
    --no-install|--config-only)
        NO_INSTALL=true
        ;;
esac

echo "================================================================="
echo "⚙️ OPTIMIZANDO KDE PLASMA 6 (PRESERVANDO APARIENCIA GOLDEN DOG)"
echo "================================================================="

if [ "$NO_INSTALL" = false ]; then
    echo "📦 [1/3] Verificando aplicaciones esenciales del ecosistema KDE Gear..."
    export DEBIAN_FRONTEND=noninteractive
    $SUDO apt-get update -qq
    $SUDO apt-get install -y \
        dolphin \
        kate \
        spectacle \
        kcalc \
        ark \
        gwenview \
        okular \
        plasma-systemmonitor \
        kio-extras \
        dolphin-plugins \
        ffmpegthumbs \
        wl-clipboard 2>/dev/null || true
else
    echo "⏭️ [1/3] Omitiendo instalación APT (--no-install)."
fi

echo "📂 [2/3] Optimizando Dolphin para desarrollo y productividad..."
run_as_user kwriteconfig6 --file dolphinrc --group "General" --key "ViewMode" 1 2>/dev/null || true
run_as_user kwriteconfig6 --file dolphinrc --group "PreviewSettings" --key "Plugins" "audiothumbnail,comicbookthumbnail,djvuthumbnail,dvrthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraimagethumbnail,svgthumbnail,videothumbnail" 2>/dev/null || true

PREFERRED_TERM=$(detect_preferred_terminal)
echo "🔗 [3/3] Configurando atajo Ctrl+Alt+T ($PREFERRED_TERM) y menús contextuales en Dolphin..."
run_as_user kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "$PREFERRED_TERM" 2>/dev/null || true
run_as_user kwriteconfig6 --file kdeglobals --group General --key TerminalService "${PREFERRED_TERM}.desktop" 2>/dev/null || true
run_as_user kwriteconfig6 --file kglobalshortcutsrc --group "services" --group "${PREFERRED_TERM}.desktop" --key "_launch" "Ctrl+Alt+T,none,${PREFERRED_TERM^} Terminal" 2>/dev/null || true

SERVICEMENUS_DIR="$USER_HOME/.local/share/kio/servicemenus"
run_as_user mkdir -p "$SERVICEMENUS_DIR"

cat <<'EOF' | run_as_user tee "$SERVICEMENUS_DIR/open-in-kitty.desktop" > /dev/null
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;
Actions=openInKitty;
X-KDE-Priority=TopLevel

[Desktop Action openInKitty]
Name=Abrir en Kitty
Name[es]=Abrir en Kitty
Name[en]=Open in Kitty
Icon=kitty
Exec=kitty --directory "%f"
EOF

cat <<'EOF' | run_as_user tee "$SERVICEMENUS_DIR/open-in-antigravity.desktop" > /dev/null
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;
Actions=openInAntigravity;
X-KDE-Priority=TopLevel

[Desktop Action openInAntigravity]
Name=Abrir con Antigravity
Name[es]=Abrir con Antigravity
Name[en]=Open in Antigravity
Icon=antigravity
Exec=antigravity "%f"
EOF

cat <<'EOF' | run_as_user tee "$SERVICEMENUS_DIR/open-in-antigravity-ide.desktop" > /dev/null
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;
Actions=openInAntigravityIde;
X-KDE-Priority=TopLevel

[Desktop Action openInAntigravityIde]
Name=Abrir con Antigravity IDE
Name[es]=Abrir con Antigravity IDE
Name[en]=Open in Antigravity IDE
Icon=antigravity-ide
Exec=antigravity-ide "%f"
EOF

run_as_user chmod +x "$SERVICEMENUS_DIR"/*.desktop 2>/dev/null || true

echo "================================================================="
echo "✅ Optimización funcional de KDE Plasma 6 completada."
echo "   • Apariencia de Golden Dog Linux preservada al 100%."
echo "   • Dolphin optimizado en modo detalles con miniaturas multimedia."
echo "   • Atajo global Ctrl+Alt+T para $PREFERRED_TERM configurado."
echo "   • Acciones de clic derecho en Dolphin (Kitty, Antigravity) listas."
echo "================================================================="

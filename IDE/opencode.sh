#!/usr/bin/env bash
# ==============================================================================
# opencode.sh - Gestor e Instalador de OpenCode AI CLI vía Mise
# Sistema: Golden Dog Linux (Debian 13) | Escritorio: KDE Plasma 6 (Wayland)
# ==============================================================================
# Características:
# - Despliegue 100% rootless en espacio de usuario gestionado por Mise.
# - Instalación de la última versión oficial o una versión específica (--version).
# - Limpieza automática de instalaciones heredadas (~/.opencode/bin) para evitar
#   conflictos de PATH con los shims de Mise.
# - Integración nativa con KDE Plasma 6 vía systemd environment.d y propagación D-Bus.
# - Comandos CLI: --status, --update, --version, --force, --uninstall, --help.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. CONSTANTES Y DETECCIÓN DE USUARIO
# ------------------------------------------------------------------------------
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="${USER:-$(id -un)}"
    USER_HOME="${HOME:-/home/$REAL_USER}"
fi

REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISE_SCRIPT="$SCRIPT_DIR/../ProgrammingLanguages/mise.sh"

MISE_SHIMS_DIR="$USER_HOME/.local/share/mise/shims"
LOCAL_BIN_DIR="$USER_HOME/.local/bin"
LEGACY_OPENCODE_DIR="$USER_HOME/.opencode"
LEGACY_OPENCODE_BIN="$LEGACY_OPENCODE_DIR/bin/opencode"
ENV_DIR="$USER_HOME/.config/environment.d"
ENV_FILE="$ENV_DIR/10-opencode.conf"
LEGACY_BASHRC_FILE="$USER_HOME/.bashrc.d/opencode.sh"
LEGACY_ZSHRC_FILE="$USER_HOME/.zshrc.d/opencode.zsh"

export PATH="$MISE_SHIMS_DIR:$LOCAL_BIN_DIR:/usr/local/bin:/usr/bin:/bin:$PATH"

run_as_user() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$REAL_UID}"
    local dbus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime_dir/bus}"
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        sudo -u "$REAL_USER" env \
            HOME="$USER_HOME" \
            USER="$REAL_USER" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            PATH="$MISE_SHIMS_DIR:$LOCAL_BIN_DIR:/usr/local/bin:/usr/bin:/bin" \
            "$@"
    else
        env \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            PATH="$MISE_SHIMS_DIR:$LOCAL_BIN_DIR:$PATH" \
            "$@"
    fi
}

# ------------------------------------------------------------------------------
# 2. DETECCIÓN DE MISE Y ESTADO
# ------------------------------------------------------------------------------
get_mise_bin() {
    if [ -x "$LOCAL_BIN_DIR/mise" ]; then
        echo "$LOCAL_BIN_DIR/mise"
    elif command -v mise &>/dev/null; then
        command -v mise
    else
        echo ""
    fi
}

ensure_mise() {
    local mise_bin
    mise_bin=$(get_mise_bin)
    if [ -z "$mise_bin" ]; then
        if [ -f "$MISE_SCRIPT" ]; then
            echo -e "${BLUE}ℹ️ Mise no encontrado. Ejecutando instalador $MISE_SCRIPT...${NC}"
            bash "$MISE_SCRIPT"
        else
            echo -e "${RED}❌ Error:${NC} 'mise' no está instalado y no se encontró $MISE_SCRIPT." >&2
            exit 1
        fi
    fi
}

get_opencode_bin() {
    local mise_bin
    mise_bin=$(get_mise_bin)
    if [ -n "$mise_bin" ]; then
        local resolved
        resolved=$(run_as_user "$mise_bin" which opencode 2>/dev/null || true)
        if [ -n "$resolved" ] && [ -x "$resolved" ]; then
            echo "$resolved"
            return 0
        fi
    fi
    if [ -x "$MISE_SHIMS_DIR/opencode" ]; then
        echo "$MISE_SHIMS_DIR/opencode"
    else
        echo ""
    fi
}

get_opencode_version() {
    local mise_bin
    mise_bin=$(get_mise_bin)
    if [ -n "$mise_bin" ]; then
        local ver
        ver=$(run_as_user "$mise_bin" exec opencode -- opencode --version 2>/dev/null | head -n1 || true)
        if [ -n "$ver" ]; then
            echo "$ver"
            return 0
        fi
    fi
    echo "No instalado"
}

show_help() {
    echo -e "${BOLD}🤖 Gestor de OpenCode AI CLI (vía Mise) - Golden Dog Linux${NC}

${BOLD}Uso:${NC}
  $0 [OPCIÓN]

${BOLD}Opciones:${NC}
  (sin argumentos)       Instala OpenCode (última versión) vía Mise y configura KDE/Shims.
  -i, --install          Comprueba e instala OpenCode si no está presente.
  -v, --version <ver>    Instala una versión específica de OpenCode (ej: --version 1.18.13).
  -f, --force            Fuerza la reinstalación aunque OpenCode ya esté instalado.
  -u, --update           Actualiza OpenCode a la última versión disponible vía Mise.
  -s, --status           Muestra el diagnóstico completo de Mise, OpenCode y KDE.
  -r, --uninstall        Desinstala OpenCode de Mise y elimina su integración.
  -h, --help             Muestra este mensaje de ayuda.

${BOLD}Ejemplos:${NC}
  $0                     # Instalación estándar idempotente
  $0 --status            # Ver estado y versión instalada
  $0 --update            # Actualizar a la última versión
  $0 --version 1.18.13   # Instalar una versión concreta"
}

show_status() {
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${BOLD}🔍 ESTADO DE OPENCODE AI CLI (MISE + KDE PLASMA 6)${NC}"
    echo -e "${CYAN}=================================================================${NC}"

    local mise_bin mise_status bin ver
    mise_bin=$(get_mise_bin)
    if [ -n "$mise_bin" ]; then
        local mise_ver
        mise_ver=$(run_as_user "$mise_bin" --version 2>/dev/null | head -n1 || echo "Instalado")
        mise_status="${GREEN}✅ Activo${NC} ($mise_ver)"
    else
        mise_status="${RED}❌ No instalado${NC}"
    fi

    echo -e "• ${BOLD}Gestor Mise:${NC}          $mise_status"

    bin=$(get_opencode_bin)
    if [ -n "$bin" ] && [ -x "$bin" ]; then
        ver=$(get_opencode_version)
        echo -e "• ${BOLD}Estado OpenCode:${NC}      ${GREEN}✅ Instalado${NC}"
        echo -e "• ${BOLD}Binario (Mise):${NC}       $bin"
        echo -e "• ${BOLD}Shim de Mise:${NC}         $MISE_SHIMS_DIR/opencode"
        echo -e "• ${BOLD}Versión:${NC}              $ver"
    else
        echo -e "• ${BOLD}Estado OpenCode:${NC}      ${RED}❌ No instalado en Mise${NC}"
    fi

    if [ -x "$LEGACY_OPENCODE_BIN" ] || [ -x "$LOCAL_BIN_DIR/opencode" ]; then
        echo -e "• ${BOLD}Binario heredado:${NC}     ${YELLOW}⚠️ Detectado fuera de Mise (puede causar conflicto de PATH)${NC}"
    fi

    if [ -f "$ENV_FILE" ]; then
        echo -e "• ${BOLD}Sesión KDE / GUI:${NC}     ${GREEN}✅ Configurada${NC} ($ENV_FILE)"
    else
        echo -e "• ${BOLD}Sesión KDE / GUI:${NC}     ${YELLOW}⚠️ No configurada${NC} ($ENV_FILE)"
    fi

    echo -e "${CYAN}=================================================================${NC}"
}

# ------------------------------------------------------------------------------
# 3. INSTALACIÓN, ACTUALIZACIÓN Y DESINSTALACIÓN VÍA MISE
# ------------------------------------------------------------------------------
cleanup_legacy_install() {
    local removed=false
    for path in "$LEGACY_OPENCODE_BIN" "$LOCAL_BIN_DIR/opencode" "$LEGACY_BASHRC_FILE" "$LEGACY_ZSHRC_FILE"; do
        if [ -e "$path" ]; then
            run_as_user rm -f "$path"
            removed=true
        fi
    done
    if [ "$removed" = true ]; then
        echo -e "${BLUE}🧹 Limpiados binarios/scripts heredados de OpenCode fuera de Mise.${NC}"
    fi
}

configure_environment() {
    echo -e "${BLUE}⚙️ Configurando integración de shims de Mise con KDE Plasma 6...${NC}"
    run_as_user mkdir -p "$ENV_DIR"

    cat << EOF | run_as_user tee "$ENV_FILE" > /dev/null
# OpenCode AI CLI via Mise Environment (KDE Plasma 6 + Wayland)
PATH=$MISE_SHIMS_DIR:$LOCAL_BIN_DIR:\${PATH}
EOF

    if command -v systemctl &>/dev/null; then
        run_as_user systemctl --user import-environment PATH 2>/dev/null || true
    fi
    if command -v dbus-update-activation-environment &>/dev/null; then
        run_as_user dbus-update-activation-environment --systemd PATH 2>/dev/null || true
    fi

    echo -e "${GREEN}✔${NC} Integración en KDE Plasma 6 completada."
}

install_opencode() {
    local target_version="${1:-}"
    local force="${2:-false}"

    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${BOLD}🤖 INSTALADOR DE OPENCODE AI CLI (MISE) - GOLDEN DOG LINUX${NC}"
    echo -e "${CYAN}=================================================================${NC}"

    ensure_mise
    local mise_bin
    mise_bin=$(get_mise_bin)

    local existing_bin
    existing_bin=$(get_opencode_bin)

    if [ -n "$existing_bin" ] && [ "$force" != "true" ] && [ -z "$target_version" ]; then
        echo -e "${GREEN}✔${NC} OpenCode ya está instalado en Mise ($(get_opencode_version))."
        echo -e "   Para actualizar a la última versión, ejecuta: ${BOLD}$0 --update${NC}"
    else
        local spec="opencode@${target_version#v}"
        if [ -z "$target_version" ]; then
            spec="opencode@latest"
        fi

        echo -e "${BLUE}⬇️ Instalando $spec vía Mise...${NC}"
        if [ "$force" = "true" ]; then
            run_as_user "$mise_bin" install --force "$spec"
        fi
        run_as_user "$mise_bin" use --global "$spec"
        run_as_user "$mise_bin" reshim 2>/dev/null || true
    fi

    cleanup_legacy_install
    configure_environment
    echo ""
    show_status
}

update_opencode() {
    echo -e "${BLUE}🔄 Actualizando OpenCode AI CLI vía Mise...${NC}"
    ensure_mise
    local mise_bin
    mise_bin=$(get_mise_bin)

    run_as_user "$mise_bin" upgrade opencode 2>/dev/null || \
        run_as_user "$mise_bin" use --global opencode@latest
    run_as_user "$mise_bin" reshim 2>/dev/null || true

    cleanup_legacy_install
    configure_environment
    echo -e "${GREEN}✔${NC} OpenCode actualizado con éxito."
    show_status
}

uninstall_opencode() {
    echo -e "${YELLOW}🗑️ Desinstalando OpenCode AI CLI de Mise y limpiando integraciones...${NC}"
    local mise_bin
    mise_bin=$(get_mise_bin)

    if [ -n "$mise_bin" ]; then
        run_as_user "$mise_bin" unuse --global opencode 2>/dev/null || true
        run_as_user "$mise_bin" uninstall opencode 2>/dev/null || true
        run_as_user "$mise_bin" reshim 2>/dev/null || true
    fi

    cleanup_legacy_install
    run_as_user rm -f "$ENV_FILE"

    echo -e "${GREEN}✔${NC} OpenCode e integraciones eliminados."
    echo -e "${CYAN}ℹ️ Nota:${NC} La configuración de usuario en ~/.config/opencode y ~/.local/share/opencode se ha conservado."
}

# ------------------------------------------------------------------------------
# 4. PROCESAMIENTO DE ARGUMENTOS CLI
# ------------------------------------------------------------------------------
TARGET_VERSION=""
FORCE_INSTALL="false"
ACTION="install"

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help|help)
            show_help
            exit 0
            ;;
        -s|--status|status)
            show_status
            exit 0
            ;;
        -u|--update|update)
            ACTION="update"
            shift
            ;;
        -r|--uninstall|uninstall)
            ACTION="uninstall"
            shift
            ;;
        -i|--install|install)
            ACTION="install"
            shift
            ;;
        -f|--force)
            FORCE_INSTALL="true"
            shift
            ;;
        -v|--version)
            if [ -z "${2:-}" ]; then
                echo -e "${RED}❌ Error:${NC} Falta especificar la versión tras $1." >&2
                exit 1
            fi
            TARGET_VERSION="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}❌ Opción desconocida:${NC} $1" >&2
            show_help
            exit 1
            ;;
        *)
            # Compatibilidad con argumento posicional de versión (ej: ./opencode.sh 1.18.13)
            TARGET_VERSION="$1"
            shift
            ;;
    esac
done

case "$ACTION" in
    install)
        install_opencode "$TARGET_VERSION" "$FORCE_INSTALL"
        ;;
    update)
        update_opencode
        ;;
    uninstall)
        uninstall_opencode
        ;;
esac

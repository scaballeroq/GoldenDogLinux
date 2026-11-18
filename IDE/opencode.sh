#!/usr/bin/env bash
# ==============================================================================
# opencode.sh - Gestor e Instalador de OpenCode AI CLI
# Sistema: Golden Dog Linux (Debian 13) | Escritorio: KDE Plasma 6 (Wayland)
# ==============================================================================
# Características:
# - Despliegue 100% rootless en espacio de usuario (~/.opencode/bin/opencode).
# - Instalación de la última versión oficial o una versión específica (--version).
# - Detección idempotente de dependencias (curl) sin llamadas innecesarias a sudo.
# - Integración nativa con KDE Plasma 6 vía systemd environment.d y propagación D-Bus.
# - Integración modular para Bash (~/.bashrc.d) y Zsh (~/.zshrc.d).
# - Comandos CLI: --status, --update, --version, --force, --uninstall, --help.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. CONSTANTES Y DETECCIÓN DE USUARIO
# ------------------------------------------------------------------------------
INSTALLER_URL="https://opencode.ai/install"

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

OPENCODE_BIN_DIR="$USER_HOME/.opencode/bin"
LOCAL_BIN_DIR="$USER_HOME/.local/bin"
ENV_DIR="$USER_HOME/.config/environment.d"
ENV_FILE="$ENV_DIR/10-opencode.conf"
BASHRC_D="$USER_HOME/.bashrc.d"
BASHRC_FILE="$BASHRC_D/opencode.sh"
ZSHRC_D="$USER_HOME/.zshrc.d"
ZSHRC_FILE="$ZSHRC_D/opencode.zsh"

export PATH="$OPENCODE_BIN_DIR:$LOCAL_BIN_DIR:/usr/local/bin:/usr/bin:/bin:$PATH"

if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

run_as_user() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$REAL_UID}"
    local dbus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime_dir/bus}"
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        sudo -u "$REAL_USER" env \
            HOME="$USER_HOME" \
            USER="$REAL_USER" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            PATH="$OPENCODE_BIN_DIR:$LOCAL_BIN_DIR:/usr/local/bin:/usr/bin:/bin" \
            "$@"
    else
        env \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            PATH="$OPENCODE_BIN_DIR:$LOCAL_BIN_DIR:$PATH" \
            "$@"
    fi
}

# ------------------------------------------------------------------------------
# 2. DETECCIÓN Y ESTADO
# ------------------------------------------------------------------------------
get_opencode_bin() {
    if [ -x "$OPENCODE_BIN_DIR/opencode" ]; then
        echo "$OPENCODE_BIN_DIR/opencode"
    elif [ -x "$LOCAL_BIN_DIR/opencode" ]; then
        echo "$LOCAL_BIN_DIR/opencode"
    elif command -v opencode &>/dev/null; then
        command -v opencode
    else
        echo ""
    fi
}

get_opencode_version() {
    local bin
    bin=$(get_opencode_bin)
    if [ -n "$bin" ] && [ -x "$bin" ]; then
        run_as_user "$bin" --version 2>/dev/null | head -n1 || echo "Instalado"
    else
        echo "No instalado"
    fi
}

show_help() {
    echo -e "${BOLD}🤖 Gestor de OpenCode AI CLI - Golden Dog Linux (Debian 13 / KDE Plasma 6)${NC}

${BOLD}Uso:${NC}
  $0 [OPCIÓN]

${BOLD}Opciones:${NC}
  (sin argumentos)       Instala OpenCode (última versión) de forma idempotente y configura KDE/Shells.
  -i, --install          Comprueba e instala OpenCode si no está presente.
  -v, --version <ver>    Instala una versión específica de OpenCode (ej: --version 1.18.13).
  -f, --force            Fuerza la reinstalación aunque OpenCode ya esté instalado.
  -u, --update           Actualiza OpenCode a la última versión disponible.
  -s, --status           Muestra el diagnóstico completo de OpenCode y su integración en KDE/Shells.
  -r, --uninstall        Desinstala el binario de OpenCode y sus archivos de integración.
  -h, --help             Muestra este mensaje de ayuda.

${BOLD}Ejemplos:${NC}
  $0                     # Instalación estándar idempotente
  $0 --status            # Ver estado y versión instalada
  $0 --update            # Actualizar a la última versión
  $0 --version 1.18.13   # Instalar una versión concreta"
}

show_status() {
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${BOLD}🔍 ESTADO DE OPENCODE AI CLI - DEBIAN WORKSTATION (KDE PLASMA 6)${NC}"
    echo -e "${CYAN}=================================================================${NC}"

    local bin ver
    bin=$(get_opencode_bin)

    if [ -n "$bin" ] && [ -x "$bin" ]; then
        ver=$(get_opencode_version)
        echo -e "• ${BOLD}Estado:${NC}               ${GREEN}✅ Instalado${NC}"
        echo -e "• ${BOLD}Binario:${NC}              $bin"
        echo -e "• ${BOLD}Versión:${NC}              $ver"
    else
        echo -e "• ${BOLD}Estado:${NC}               ${RED}❌ No instalado${NC}"
    fi

    if [ -f "$ENV_FILE" ]; then
        echo -e "• ${BOLD}Sesión KDE / GUI:${NC}     ${GREEN}✅ Configurada${NC} ($ENV_FILE)"
    else
        echo -e "• ${BOLD}Sesión KDE / GUI:${NC}     ${YELLOW}⚠️ No configurada${NC} ($ENV_FILE)"
    fi

    if [ -f "$BASHRC_FILE" ]; then
        echo -e "• ${BOLD}Integración Bash:${NC}     ${GREEN}✅ Activa${NC} ($BASHRC_FILE)"
    else
        echo -e "• ${BOLD}Integración Bash:${NC}     ${YELLOW}⚠️ Inactiva${NC}"
    fi

    if [ -f "$USER_HOME/.zshrc" ]; then
        if [ -f "$ZSHRC_FILE" ]; then
            echo -e "• ${BOLD}Integración Zsh:${NC}      ${GREEN}✅ Activa${NC} ($ZSHRC_FILE)"
        else
            echo -e "• ${BOLD}Integración Zsh:${NC}      ${YELLOW}⚠️ Inactiva${NC}"
        fi
    fi

    echo -e "${CYAN}=================================================================${NC}"
}

# ------------------------------------------------------------------------------
# 3. DEPENDENCIAS, INSTALACIÓN E INTEGRACIÓN
# ------------------------------------------------------------------------------
ensure_dependencies() {
    if ! command -v curl &>/dev/null; then
        echo -e "${BLUE}📦 Instalando dependencia requerida (curl) vía APT...${NC}"
        if [ "$EUID" -ne 0 ] && ! command -v sudo &>/dev/null; then
            echo -e "${RED}❌ Error:${NC} Se requiere 'curl' y privilegios de administrador ('sudo')." >&2
            exit 1
        fi
        $SUDO apt-get update -qq
        $SUDO apt-get install -y curl
    fi
}

run_official_installer() {
    local target_version="${1:-}"
    ensure_dependencies

    local tmp_installer
    tmp_installer=$(mktemp /tmp/opencode-install-XXXXXX.sh)

    echo -e "${BLUE}⬇️ Descargando instalador oficial de OpenCode...${NC}"
    if ! curl -fsSL "$INSTALLER_URL" -o "$tmp_installer"; then
        rm -f "$tmp_installer"
        echo -e "${RED}❌ Error:${NC} No se pudo descargar el instalador desde $INSTALLER_URL." >&2
        exit 1
    fi

    if [ -n "$target_version" ]; then
        echo -e "${BLUE}⚙️ Instalando OpenCode v${target_version} en modo usuario...${NC}"
        run_as_user env VERSION="$target_version" bash "$tmp_installer" --no-modify-path || \
            run_as_user env VERSION="$target_version" bash "$tmp_installer"
    else
        echo -e "${BLUE}⚙️ Instalando última versión de OpenCode en modo usuario...${NC}"
        run_as_user bash "$tmp_installer" --no-modify-path || \
            run_as_user bash "$tmp_installer"
    fi

    rm -f "$tmp_installer"
}

configure_environment() {
    echo -e "${BLUE}⚙️ Configurando integración con KDE Plasma 6 y Shells...${NC}"
    run_as_user mkdir -p "$ENV_DIR" "$BASHRC_D"

    cat << EOF | run_as_user tee "$ENV_FILE" > /dev/null
# OpenCode AI CLI Environment (KDE Plasma 6 + Wayland)
PATH=$OPENCODE_BIN_DIR:$LOCAL_BIN_DIR:\${PATH}
EOF

    if command -v systemctl &>/dev/null; then
        run_as_user systemctl --user import-environment PATH 2>/dev/null || true
    fi
    if command -v dbus-update-activation-environment &>/dev/null; then
        run_as_user dbus-update-activation-environment --systemd PATH 2>/dev/null || true
    fi

    cat << EOF | run_as_user tee "$BASHRC_FILE" > /dev/null
# OpenCode AI CLI (Bash)
if [ -d "$OPENCODE_BIN_DIR" ] && [[ ":\$PATH:" != *":$OPENCODE_BIN_DIR:"* ]]; then
    export PATH="$OPENCODE_BIN_DIR:\$PATH"
fi
EOF

    if [ -f "$USER_HOME/.zshrc" ]; then
        run_as_user mkdir -p "$ZSHRC_D"
        cat << EOF | run_as_user tee "$ZSHRC_FILE" > /dev/null
# OpenCode AI CLI (Zsh)
if [ -d "$OPENCODE_BIN_DIR" ] && [[ ":\$PATH:" != *":$OPENCODE_BIN_DIR:"* ]]; then
    export PATH="$OPENCODE_BIN_DIR:\$PATH"
fi
EOF
    fi

    echo -e "${GREEN}✔${NC} Integración en KDE Plasma 6 y terminales completada."
}

install_opencode() {
    local target_version="${1:-}"
    local force="${2:-false}"

    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${BOLD}🤖 INSTALADOR DE OPENCODE AI CLI - GOLDEN DOG LINUX${NC}"
    echo -e "${CYAN}=================================================================${NC}"

    local existing_bin
    existing_bin=$(get_opencode_bin)

    if [ -n "$existing_bin" ] && [ "$force" != "true" ] && [ -z "$target_version" ]; then
        echo -e "${GREEN}✔${NC} OpenCode ya está instalado ($(get_opencode_version)) en $existing_bin."
        echo -e "   Para actualizar a la última versión, ejecuta: ${BOLD}$0 --update${NC}"
    else
        run_official_installer "$target_version"
    fi

    configure_environment
    echo ""
    show_status
}

update_opencode() {
    echo -e "${BLUE}🔄 Actualizando OpenCode AI CLI...${NC}"
    local bin
    bin=$(get_opencode_bin)

    if [ -n "$bin" ] && [ -x "$bin" ]; then
        if ! run_as_user "$bin" upgrade 2>/dev/null; then
            run_official_installer ""
        fi
    else
        run_official_installer ""
    fi

    configure_environment
    echo -e "${GREEN}✔${NC} OpenCode actualizado con éxito."
    show_status
}

uninstall_opencode() {
    echo -e "${YELLOW}🗑️ Desinstalando OpenCode AI CLI y su integración...${NC}"

    run_as_user rm -f \
        "$OPENCODE_BIN_DIR/opencode" \
        "$LOCAL_BIN_DIR/opencode" \
        "$ENV_FILE" \
        "$BASHRC_FILE" \
        "$ZSHRC_FILE"

    echo -e "${GREEN}✔${NC} Binario e integraciones eliminados."
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

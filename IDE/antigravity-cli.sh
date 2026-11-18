#!/usr/bin/env bash
# ==============================================================================
# antigravity-cli.sh - Gestor e Instalador de Google Antigravity CLI (agy)
# Optimizado para Debian Workstation (KDE Plasma 6 Wayland)
# ==============================================================================
# Características:
#  - Instalación y gestión 100% rootless en ~/.local/bin/agy.
#  - Comprobación de estado (--status) e inspección de versión instantánea.
#  - Consulta directa al manifiesto oficial con timeouts y parseo seguro.
#  - Prevención de descargas redundantes si la versión local ya está al día.
#  - Fallback automático al instalador oficial si el manifiesto no responde.
#  - Integración idempotente en ~/.bashrc.d/ y ~/.config/environment.d/.
#  - Opciones completas de CLI: --status, --check, --update, --force, --uninstall y --help.
# ==============================================================================

set -euo pipefail

# Colores de salida
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

# Detección de usuario real
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    REAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6 || true)
    USER_HOME="${USER_HOME:-/home/$REAL_USER}"
else
    REAL_USER="${USER:-$(id -un)}"
    USER_HOME="${HOME:-/home/$REAL_USER}"
fi

LOCAL_BIN="$USER_HOME/.local/bin"
AGY_BIN="$LOCAL_BIN/agy"
HELPER_PATH="$LOCAL_BIN/update-antigravity-cli"
MARKER_FILE="$LOCAL_BIN/.linuxcapable-antigravity-cli"
MARKER_VALUE="google-antigravity-cli-v1"
BASHRC_D="$USER_HOME/.bashrc.d"
BASHRC_FILE="$BASHRC_D/antigravity-cli.sh"
ENV_D="$USER_HOME/.config/environment.d"
ENV_FILE="$ENV_D/10-antigravity-cli.conf"

MANIFEST_BASE_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
OFFICIAL_INSTALLER_URL="https://antigravity.google/cli/install.sh"

_TMP_DIR=""
cleanup_tmp() {
    if [[ -n "${_TMP_DIR:-}" && -d "$_TMP_DIR" ]]; then
        rm -rf "$_TMP_DIR"
    fi
}
trap cleanup_tmp EXIT

case "$(uname -m)" in
x86_64 | amd64)
    ARCH="amd64"
    PLATFORM="linux_amd64"
    ;;
aarch64 | arm64)
    ARCH="arm64"
    PLATFORM="linux_arm64"
    ;;
*)
    echo -e "${RED}❌ Arquitectura no soportada: $(uname -m)${NC}" >&2
    exit 1
    ;;
esac

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ Dependencia requerida no encontrada: $cmd${NC}" >&2
        exit 1
    fi
}

run_as_user() {
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" "$@"
    else
        "$@"
    fi
}

extract_semver() {
    grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)+' <<<"$1" | head -n1 || true
}

versions_match() {
    local local_raw="$1"
    local remote_raw="$2"
    local local_ver remote_ver

    [[ -n "$local_raw" && -n "$remote_raw" ]] || return 1

    local_ver=$(extract_semver "$local_raw")
    remote_ver=$(extract_semver "$remote_raw")

    if [[ -n "$local_ver" && -n "$remote_ver" ]]; then
        [[ "$local_ver" == "$remote_ver" ]]
    else
        [[ "$local_raw" == "$remote_raw" ]]
    fi
}

get_installed_version() {
    if [[ -x "$AGY_BIN" ]]; then
        run_as_user "$AGY_BIN" --version 2>/dev/null || true
    elif command -v agy &>/dev/null; then
        run_as_user agy --version 2>/dev/null || true
    fi
}

get_remote_version() {
    require_cmd curl
    local manifest_url="$MANIFEST_BASE_URL/manifests/$PLATFORM.json"
    local json version

    json=$(curl -fsSL --connect-timeout 5 --max-time 15 --retry 2 "$manifest_url" 2>/dev/null || true)
    [[ -n "$json" ]] || return 0

    if command -v jq &>/dev/null; then
        version=$(jq -r '.version // empty' <<<"$json" 2>/dev/null || true)
    else
        version=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$json" | head -n1 | cut -d'"' -f4 || true)
    fi

    echo "$version"
}

validate_agy() {
    local bin="$1"
    [[ -x "$bin" ]] && run_as_user "$bin" --version &>/dev/null
}

write_if_changed() {
    local target="$1"
    local content="$2"
    if [[ -f "$target" ]] && [[ "$(cat "$target")" == "$content" ]]; then
        return 0
    fi
    printf '%s\n' "$content" | run_as_user tee "$target" >/dev/null
}

ensure_integration() {
    run_as_user mkdir -p "$BASHRC_D" "$ENV_D"

    local env_content bashrc_content
    env_content='# Google Antigravity CLI Environment Integration
PATH="$HOME/.local/bin:$PATH"'

    bashrc_content='# Google Antigravity CLI Integration
if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi'

    write_if_changed "$ENV_FILE" "$env_content"
    write_if_changed "$BASHRC_FILE" "$bashrc_content"
}

show_status() {
    local installed_ver remote_ver
    installed_ver=$(get_installed_version)

    echo -e "${BOLD}${CYAN}=================================================================${NC}"
    echo -e "${BOLD}🔍 ESTADO DE GOOGLE ANTIGRAVITY CLI (agy) - DEBIAN WORKSTATION${NC}"
    echo -e "${BOLD}${CYAN}=================================================================${NC}"
    echo -e "• Ubicación del binario:     ${AGY_BIN}"
    if [[ -n "$installed_ver" ]]; then
        echo -e "• Estado local:              ${GREEN}✅ Instalado${NC} (Versión: ${BOLD}${installed_ver}${NC})"
        if [[ -f "$MARKER_FILE" ]]; then
            echo -e "• Gestión de instalación:    ${GREEN}✅ Gestionado por script (v1)${NC}"
        fi
    else
        echo -e "• Estado local:              ${YELLOW}❌ No instalado o fuera de PATH${NC}"
    fi

    echo -e "• Plataforma / Arch:         ${BLUE}${PLATFORM}${NC} (${ARCH})"
    echo -n "• Consulta versión remota:   "
    remote_ver=$(get_remote_version)
    if [[ -n "$remote_ver" ]]; then
        echo -e "${GREEN}v${remote_ver}${NC}"
        if [[ -n "$installed_ver" ]]; then
            if versions_match "$installed_ver" "$remote_ver"; then
                echo -e "• Sincronización:            ${GREEN}✅ La versión instalada coincide con la última versión remota.${NC}"
            else
                echo -e "• Sincronización:            ${YELLOW}⚡ Hay una actualización disponible: v${remote_ver}${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}No disponible (sin conexión o error de manifiesto)${NC}"
    fi

    echo -e "• Integración de entorno:    $(if [[ -f "$ENV_FILE" ]]; then echo -e "${GREEN}✅ environment.d activo${NC}"; else echo -e "${YELLOW}No configurado${NC}"; fi)"
    echo -e "• Integración en Shell:      $(if [[ -f "$BASHRC_FILE" ]]; then echo -e "${GREEN}✅ ~/.bashrc.d activo${NC}"; else echo -e "${YELLOW}No configurado${NC}"; fi)"
    echo -e "${BOLD}${CYAN}=================================================================${NC}"
}

show_help() {
    cat <<EOF
Uso: $0 [OPCIÓN]

Gestor e Instalador de Google Antigravity CLI (agy) para Debian.

Opciones:
  (sin argumentos)    Comprueba la versión instalada y descarga/instala sólo si hay una versión nueva.
  --status, -s        Muestra diagnóstico completo de agy, versión local y remota.
  --check, -c         Comprueba silenciosamente si hay actualizaciones (exit 0 si al día, 1 si pendiente, 2 si error remoto).
  --update, -u        Fuerza la comprobación y actualización a la última versión disponible.
  --force, -f         Reinstala forzosamente la última versión independientemente del estado actual.
  --uninstall         Elimina el binario agy y sus archivos de configuración de entorno.
  --help, -h          Muestra este mensaje de ayuda.
EOF
}

install_from_official_script() {
    echo -e "${YELLOW}⚠️ Descarga por manifiesto directo no disponible. Utilizando instalador oficial...${NC}"
    curl -fsSL --connect-timeout 5 --max-time 60 "$OFFICIAL_INSTALLER_URL" | run_as_user bash
}

install_agy() {
    local force="${1:-false}"
    local installed_ver remote_ver

    require_cmd curl
    require_cmd tar

    installed_ver=$(get_installed_version)

    echo -e "${BOLD}${BLUE}==> Comprobando versiones de Google Antigravity CLI...${NC}"
    remote_ver=$(get_remote_version)

    if [[ "$force" != "true" && -n "$installed_ver" && -n "$remote_ver" ]]; then
        if versions_match "$installed_ver" "$remote_ver"; then
            ensure_integration
            echo -e "${GREEN}✅ Antigravity CLI ya está en la última versión ($installed_ver). Nada que hacer.${NC}"
            exit 0
        fi
    fi

    echo -e "${BLUE}==> Descargando e instalando Google Antigravity CLI (${remote_ver:-última versión})...${NC}"
    run_as_user mkdir -p "$LOCAL_BIN"

    if [[ -n "$remote_ver" ]]; then
        local download_url="$MANIFEST_BASE_URL/downloads/antigravity-$PLATFORM-$remote_ver.tar.gz"
        _TMP_DIR=$(run_as_user mktemp -d "/tmp/agy-install-XXXXXX")

        if curl -fsSL --connect-timeout 5 --max-time 120 --retry 3 "$download_url" -o "$_TMP_DIR/agy.tar.gz" 2>/dev/null; then
            tar -xzf "$_TMP_DIR/agy.tar.gz" -C "$_TMP_DIR"
            local extracted_bin
            extracted_bin=$(find "$_TMP_DIR" -type f -name "agy" | head -n1)
            if [[ -n "$extracted_bin" ]]; then
                run_as_user install -m 755 "$extracted_bin" "$AGY_BIN"
            else
                echo -e "${RED}❌ Error: no se encontró el binario 'agy' en el paquete descargado.${NC}" >&2
                exit 1
            fi
        else
            install_from_official_script
        fi
    else
        install_from_official_script
    fi

    if validate_agy "$AGY_BIN"; then
        printf '%s\n' "$MARKER_VALUE" | run_as_user tee "$MARKER_FILE" >/dev/null
        echo -e "${GREEN}✅ Binario instalado y validado con éxito: $(run_as_user "$AGY_BIN" --version 2>/dev/null || echo "${remote_ver:-OK}")${NC}"
    else
        echo -e "${RED}❌ Error de validación del binario 'agy'.${NC}" >&2
        exit 1
    fi

    ensure_integration
    echo -e "${GREEN}✅ Integración en ~/.bashrc.d y ~/.config/environment.d completada.${NC}"
}

uninstall_agy() {
    echo -e "${YELLOW}==> Desinstalando Google Antigravity CLI...${NC}"
    run_as_user rm -f "$AGY_BIN" "$MARKER_FILE" "$HELPER_PATH" "$BASHRC_FILE" "$ENV_FILE"
    echo -e "${GREEN}✅ Desinstalación completada.${NC}"
}

case "${1:-}" in
--status | -s)
    show_status
    ;;
--help | -h)
    show_help
    ;;
--check | -c)
    local_v=$(get_installed_version)
    remote_v=$(get_remote_version)
    if [[ -z "$remote_v" ]]; then
        exit 2
    elif versions_match "$local_v" "$remote_v"; then
        exit 0
    else
        exit 1
    fi
    ;;
--update | -u)
    install_agy false
    ;;
--force | -f)
    install_agy true
    ;;
--uninstall)
    uninstall_agy
    ;;
"")
    install_agy false
    ;;
*)
    echo -e "${RED}❌ Opción no reconocida: $1${NC}" >&2
    show_help
    exit 1
    ;;
esac

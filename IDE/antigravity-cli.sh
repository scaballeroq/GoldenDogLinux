#!/usr/bin/env bash
# ==============================================================================
# antigravity-cli.sh - Gestor e Instalador de Google Antigravity CLI (agy)
# Sistema: Golden Dog Linux (Debian 13 Trixie) | Escritorio: KDE Plasma 6 Wayland
# ==============================================================================
# Características:
#  - Instalación y gestión 100% rootless en ~/.local/bin/agy.
#  - Validación atómica del binario antes de reemplazar versiones previas.
#  - Comprobación de estado (--status) e inspección de versión instantánea.
#  - Consulta directa al manifiesto oficial con timeouts y parseo seguro.
#  - Prevención de descargas redundantes si la versión local ya está al día.
#  - Fallback seguro al instalador oficial o URL directa (--url).
#  - Integración idempotente en ~/.bashrc.d/, ~/.zshrc.d/ y ~/.config/environment.d/.
#  - Enlace ~/.local/bin/update-antigravity-cli para actualizar desde cualquier ruta.
#  - Opciones completas de CLI: --status, --check, --update, --force, --url, --uninstall y --help.
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

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
ZSHRC_D="$USER_HOME/.zshrc.d"
ZSHRC_FILE="$ZSHRC_D/antigravity-cli.zsh"
ENV_D="$USER_HOME/.config/environment.d"
ENV_FILE="$ENV_D/10-antigravity-cli.conf"
CLI_SETTINGS_FILE="$USER_HOME/.gemini/antigravity-cli/settings.json"

MANIFEST_BASE_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
OFFICIAL_INSTALLER_URL="https://antigravity.google/cli/install.sh"
TARGET_URL=""

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

ensure_dependencies() {
    local missing=()
    for cmd_pkg in "curl:curl" "tar:tar"; do
        local cmd="${cmd_pkg%%:*}"
        local pkg="${cmd_pkg##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$pkg")
        fi
    done
    if ! dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null | grep -q "install ok installed"; then
        missing+=("ca-certificates")
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "ℹ️  ${YELLOW}Instalando dependencias requeridas (${missing[*]})...${NC}"
        if [[ "$EUID" -ne 0 ]]; then
            if command -v sudo &>/dev/null; then
                sudo apt-get update -qq
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
            else
                echo -e "${RED}❌ Faltan dependencias (${missing[*]}) y 'sudo' no está disponible.${NC}" >&2
                exit 1
            fi
        else
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
        fi
    fi
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        ensure_dependencies
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}❌ Dependencia requerida no encontrada: $cmd${NC}" >&2
            exit 1
        fi
    fi
}

run_as_user() {
    if [[ "$EUID" -eq 0 && "$REAL_USER" != "root" ]]; then
        sudo -u "$REAL_USER" env HOME="$USER_HOME" USER="$REAL_USER" PATH="$LOCAL_BIN:$PATH" "$@"
    else
        env PATH="$LOCAL_BIN:$PATH" "$@"
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
    run_as_user mkdir -p "$LOCAL_BIN" "$BASHRC_D" "$ENV_D"

    local env_content bashrc_content
    env_content='# Google Antigravity CLI Environment Integration
PATH="$HOME/.local/bin:$PATH"'

    bashrc_content='# Google Antigravity CLI Integration
if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi'

    write_if_changed "$ENV_FILE" "$env_content"
    write_if_changed "$BASHRC_FILE" "$bashrc_content"

    if [[ -f "$USER_HOME/.zshrc" || -d "$ZSHRC_D" ]]; then
        run_as_user mkdir -p "$ZSHRC_D"
        write_if_changed "$ZSHRC_FILE" "$bashrc_content"
    fi

    if [[ -x "$SCRIPT_PATH" ]]; then
        run_as_user ln -sfn "$SCRIPT_PATH" "$HELPER_PATH"
    fi
}

show_status() {
    local installed_ver remote_ver distro_pretty distro_codename active_bin
    installed_ver=$(get_installed_version)
    distro_pretty=$(grep -oP '^PRETTY_NAME="\K[^"]+' /etc/os-release 2>/dev/null || echo "Debian GNU/Linux")
    distro_codename=$(grep -oP '^VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null || echo "trixie")
    if [[ -x "$AGY_BIN" ]]; then
        active_bin="$AGY_BIN"
    elif command -v agy &>/dev/null; then
        active_bin=$(command -v agy)
    else
        active_bin="$AGY_BIN"
    fi

    echo -e "${BOLD}${CYAN}=================================================================${NC}"
    echo -e "${BOLD}🔍 ESTADO DE GOOGLE ANTIGRAVITY CLI (agy) - DEBIAN WORKSTATION${NC}"
    echo -e "${BOLD}${CYAN}=================================================================${NC}"
    echo -e "• Sistema:                   ${distro_pretty} [Debian ${distro_codename}] (${XDG_SESSION_TYPE:-wayland})"
    echo -e "• Usuario objetivo:          ${REAL_USER} (${USER_HOME})"
    echo -e "• Ubicación del binario:     ${active_bin}"
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

    echo -e "• Configuración CLI:         $(if [[ -f "$CLI_SETTINGS_FILE" ]]; then echo -e "${GREEN}✅ $CLI_SETTINGS_FILE${NC}"; else echo -e "ℹ️ Por defecto (se creará al iniciar agy)"; fi)"
    echo -e "• Integración de entorno:    $(if [[ -f "$ENV_FILE" ]]; then echo -e "${GREEN}✅ environment.d activo${NC}"; else echo -e "${YELLOW}No configurado${NC}"; fi)"
    echo -e "• Integración en Bash:       $(if [[ -f "$BASHRC_FILE" ]]; then echo -e "${GREEN}✅ ~/.bashrc.d activo${NC}"; else echo -e "${YELLOW}No configurado${NC}"; fi)"
    if [[ -f "$USER_HOME/.zshrc" || -d "$ZSHRC_D" ]]; then
        echo -e "• Integración en Zsh:        $(if [[ -f "$ZSHRC_FILE" ]]; then echo -e "${GREEN}✅ ~/.zshrc.d activo${NC}"; else echo -e "${YELLOW}No configurado${NC}"; fi)"
    fi
    echo -e "• Helper actualización:      $(if [[ -L "$HELPER_PATH" || -x "$HELPER_PATH" ]]; then echo -e "${GREEN}✅ $HELPER_PATH${NC}"; else echo -e "${YELLOW}No configurado${NC}"; fi)"

    local desktop_coex=()
    [[ -L "/usr/local/bin/antigravity" || -x "/opt/antigravity/Antigravity-x64/antigravity" ]] && desktop_coex+=("Antigravity 2.0")
    [[ -L "/usr/local/bin/antigravity-ide" || -x "/opt/antigravity-ide/Antigravity-IDE/antigravity-ide" ]] && desktop_coex+=("Antigravity IDE")
    if [[ ${#desktop_coex[@]} -gt 0 ]]; then
        echo -e "• Coexistencia ecosistema:   ${GREEN}✅ ${desktop_coex[*]}${NC}"
    fi
    echo -e "${BOLD}${CYAN}=================================================================${NC}"
}

show_help() {
    cat <<EOF
Uso: $0 [OPCIÓN]

Gestor e Instalador de Google Antigravity CLI (agy) para Golden Dog Linux (Debian 13).

Opciones:
  (sin argumentos)    Comprueba la versión instalada y descarga/instala sólo si hay una versión nueva.
  --status, -s        Muestra diagnóstico completo de agy, versión local, remota e integraciones.
  --check, -c         Comprueba silenciosamente si hay actualizaciones (exit 0 si al día, 1 si pendiente, 2 si error remoto).
  --update, -u        Comprueba y actualiza a la última versión disponible.
  --force, -f         Reinstala forzosamente la última versión independientemente del estado actual.
  --url <URL>         Instala agy desde una URL directa (.tar.gz oficial).
  --uninstall         Elimina el binario agy y sus archivos de configuración de entorno.
  --help, -h          Muestra este mensaje de ayuda.
EOF
}

install_from_official_script() {
    echo -e "${YELLOW}⚠️ Descarga por manifiesto directo no disponible. Utilizando instalador oficial...${NC}"
    [[ -n "${_TMP_DIR:-}" && -d "$_TMP_DIR" ]] || _TMP_DIR=$(run_as_user mktemp -d "/tmp/agy-install-XXXXXX")
    local installer_script="$_TMP_DIR/install.sh"
    if curl -fsSL --connect-timeout 5 --max-time 60 --retry 2 "$OFFICIAL_INSTALLER_URL" -o "$installer_script" 2>/dev/null && [[ -s "$installer_script" ]]; then
        run_as_user bash "$installer_script"
    else
        echo -e "${RED}❌ Error: no se pudo descargar el instalador oficial desde $OFFICIAL_INSTALLER_URL (verifica tu conexión a Internet).${NC}" >&2
        exit 1
    fi
}

install_from_tarball() {
    local tarball="$1"
    tar -xzf "$tarball" -C "$_TMP_DIR"
    local extracted_bin
    extracted_bin=$(find "$_TMP_DIR" -type f -name "agy" | head -n1 || true)
    if [[ -z "$extracted_bin" ]]; then
        echo -e "${RED}❌ Error: no se encontró el binario 'agy' en el paquete descargado.${NC}" >&2
        return 1
    fi
    chmod 755 "$extracted_bin"
    if ! validate_agy "$extracted_bin"; then
        echo -e "${YELLOW}⚠️ El binario extraído no superó la validación previa.${NC}" >&2
        return 1
    fi
    local staged_bin="$LOCAL_BIN/.agy.new.$$"
    run_as_user install -m 755 "$extracted_bin" "$staged_bin"
    run_as_user mv -f "$staged_bin" "$AGY_BIN"
    return 0
}

install_agy() {
    local force="${1:-false}"
    local installed_ver remote_ver

    require_cmd curl
    require_cmd tar

    installed_ver=$(get_installed_version)

    echo -e "${BOLD}${BLUE}==> Comprobando versiones de Google Antigravity CLI...${NC}"
    if [[ -n "$TARGET_URL" ]]; then
        remote_ver=$(extract_semver "$TARGET_URL")
    else
        remote_ver=$(get_remote_version)
    fi

    if [[ "$force" != "true" && -z "$TARGET_URL" && -n "$installed_ver" && -n "$remote_ver" ]]; then
        if versions_match "$installed_ver" "$remote_ver"; then
            ensure_integration
            echo -e "${GREEN}✅ Antigravity CLI ya está en la última versión ($installed_ver). Nada que hacer.${NC}"
            exit 0
        fi
    fi

    echo -e "${BLUE}==> Descargando e instalando Google Antigravity CLI (${remote_ver:-última versión})...${NC}"
    run_as_user mkdir -p "$LOCAL_BIN"
    _TMP_DIR=$(run_as_user mktemp -d "/tmp/agy-install-XXXXXX")

    if [[ -n "$TARGET_URL" ]]; then
        if curl -fsSL --connect-timeout 5 --max-time 120 --retry 3 "$TARGET_URL" -o "$_TMP_DIR/agy.tar.gz"; then
            install_from_tarball "$_TMP_DIR/agy.tar.gz"
        else
            echo -e "${RED}❌ Error al descargar desde la URL especificada: $TARGET_URL${NC}" >&2
            exit 1
        fi
    elif [[ -n "$remote_ver" ]]; then
        local download_url="$MANIFEST_BASE_URL/downloads/antigravity-$PLATFORM-$remote_ver.tar.gz"
        if curl -fsSL --connect-timeout 5 --max-time 120 --retry 3 "$download_url" -o "$_TMP_DIR/agy.tar.gz" 2>/dev/null; then
            if ! install_from_tarball "$_TMP_DIR/agy.tar.gz"; then
                install_from_official_script
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
    echo -e "${GREEN}✅ Integración en ~/.bashrc.d, ~/.zshrc.d y ~/.config/environment.d completada.${NC}"
}

uninstall_agy() {
    echo -e "${YELLOW}==> Desinstalando Google Antigravity CLI...${NC}"
    run_as_user rm -f "$AGY_BIN" "$MARKER_FILE" "$HELPER_PATH" "$BASHRC_FILE" "$ZSHRC_FILE" "$ENV_FILE"
    echo -e "${GREEN}✅ Desinstalación completada.${NC}"
}

ACTION="install"
FORCE_INSTALL="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status | -s)
            ACTION="status"
            shift
            ;;
        --help | -h)
            show_help
            exit 0
            ;;
        --check | -c)
            ACTION="check"
            shift
            ;;
        --update | -u)
            ACTION="install"
            FORCE_INSTALL="false"
            shift
            ;;
        --force | -f)
            ACTION="install"
            FORCE_INSTALL="true"
            shift
            ;;
        --url)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}❌ Error: --url requiere una URL.${NC}" >&2
                exit 1
            fi
            TARGET_URL="$2"
            shift 2
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        *)
            echo -e "${RED}❌ Opción no reconocida: $1${NC}" >&2
            show_help
            exit 1
            ;;
    esac
done

case "$ACTION" in
    status)
        show_status
        ;;
    check)
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
    uninstall)
        uninstall_agy
        ;;
    install)
        install_agy "$FORCE_INSTALL"
        ;;
esac

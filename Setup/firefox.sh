#!/usr/bin/env bash
# ==============================================================================
# firefox.sh - Instalación, Optimización y Diagnóstico de Mozilla Firefox Nativo
# Sistema: Debian GNU/Linux 13 (Trixie) | Escritorio: KDE Plasma 6 (Wayland)
# Hardware: Genérico AMD / Intel (VA-API Wayland)
# ==============================================================================
# Características:
#   - Instalación del paquete nativo (.deb) desde el repositorio oficial de Mozilla APT.
#   - Gestión idempotente de clave GPG moderna (/etc/apt/keyrings/packages.mozilla.org.asc).
#   - Pinning prioritario en APT (/etc/apt/preferences.d/mozilla) para evitar colisiones con ESR.
#   - Sustitución limpia de Firefox ESR y versiones residuales de Snap.
#   - Paquete de idioma español oficial (firefox-l10n-es-es).
#   - Aceleración por hardware VA-API (Mesa radeonsi) y portales nativos KDE Plasma Wayland.
#   - Políticas empresariales de sistema (/etc/firefox/policies/policies.json).
#   - Opciones CLI: --status / -s, --install / -i, --update / -u, --wayland / -w,
#                   --uninstall / -r, --help / -h.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. CONSTANTES Y CONFIGURACIÓN
# ------------------------------------------------------------------------------
KEYRING_URL="https://packages.mozilla.org/apt/repo-signing-key.gpg"
KEYRING_DIR="/etc/apt/keyrings"
KEYRING_FILE="$KEYRING_DIR/packages.mozilla.org.asc"
SOURCES_FILE="/etc/apt/sources.list.d/mozilla.list"
PREFERENCES_FILE="/etc/apt/preferences.d/mozilla"
POLICIES_DIR="/etc/firefox/policies"
POLICIES_FILE="$POLICIES_DIR/policies.json"
PACKAGE_NAME="firefox"
L10N_PACKAGE="firefox-l10n-es-es"
ENV_FILENAME="90-debian-multimedia.conf"

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
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="${USER:-$(id -un)}"
    USER_HOME="${HOME:-/home/$REAL_USER}"
fi

REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")
USER_ENV_FILE="$USER_HOME/.config/environment.d/$ENV_FILENAME"

if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

require_root() {
    if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo &>/dev/null; then
            echo -e "${RED}❌ Error:${NC} Esta operación requiere privilegios de administrador ('sudo')." >&2
            exit 1
        fi
    fi
}

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

# ------------------------------------------------------------------------------
# 3. AYUDA Y DIAGNÓSTICO DEL SISTEMA
# ------------------------------------------------------------------------------
show_help() {
    echo -e "${BOLD}🌐 Gestor y Optimizador de Mozilla Firefox - Debian 13 Workstation${NC}

${BOLD}Uso:${NC}
  $0 [OPCIÓN]

${BOLD}Opciones:${NC}
  (sin argumentos)    Instala Firefox oficial desde Mozilla, configura repositorios,
                      aplica aceleración VA-API Wayland e idioma español.
  -s, --status        Muestra diagnóstico detallado del repositorio, paquete, Wayland y VA-API.
  -i, --install       Fuerza la configuración del repositorio e instalación del navegador.
  -u, --update        Actualiza Firefox y su localización desde el repositorio oficial de Mozilla.
  -w, --wayland       Aplica políticas de aceleración por GPU (VA-API Radeon) y portales XDG KDE.
  -r, --uninstall     Desinstala Firefox del sistema respetando los perfiles de usuario.
  -h, --help          Muestra este mensaje de ayuda.

${BOLD}Ajustes incluidos en Debian 13 (Trixie / KDE Plasma 6 Wayland):${NC}
  • Repositorio APT:  packages.mozilla.org firmado con clave asc oficial de Mozilla.
  • Pinning APT:      Prioridad 1000 para garantizar versiones Rapid Release nativas sobre ESR.
  • Idioma:           Localización oficial en español (España) instalada e integrada.
  • Wayland nativo:   Integración de portales XDG para selector de archivos nativo de KDE Plasma (Dolphin).
  • Aceleración HW:   VA-API habilitado para GPU AMD/Intel (decodificación 4K fluida)."
}

is_pkg_installed() {
    local status
    status=$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)
    [ "$status" = "install ok installed" ]
}

get_pkg_version() {
    dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true
}

is_firefox_installed() {
    is_pkg_installed "$PACKAGE_NAME"
}

get_firefox_version() {
    if is_firefox_installed; then
        get_pkg_version "$PACKAGE_NAME"
    elif command -v firefox &>/dev/null; then
        firefox --version 2>/dev/null | awk '{print $NF}' || echo "Desconocida"
    else
        echo "No instalado"
    fi
}

get_firefox_origin() {
    if is_firefox_installed; then
        apt-cache policy "$PACKAGE_NAME" 2>/dev/null | awk '/\*\*\*/{getline; origin=$2 " " $3; found=1} END{if (found) print origin; else print "APT local"}'
    else
        echo "n/a"
    fi
}

show_status() {
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${BOLD}🔍 DIAGNÓSTICO DE MOZILLA FIREFOX - DEBIAN WORKSTATION (WAYLAND)${NC}"
    echo -e "${CYAN}=================================================================${NC}"

    # 1. Repositorio Oficial
    if [ -f "$SOURCES_FILE" ]; then
        echo -e "• ${BOLD}Repositorio Mozilla APT:${NC}  ${GREEN}✅ Configurado ($SOURCES_FILE)${NC}"
    else
        echo -e "• ${BOLD}Repositorio Mozilla APT:${NC}  ${RED}❌ No configurado${NC}"
    fi

    # 2. Clave GPG
    if [ -f "$KEYRING_FILE" ] && [ -s "$KEYRING_FILE" ]; then
        echo -e "• ${BOLD}Clave GPG Mozilla:${NC}        ${GREEN}✅ Presente en $KEYRING_FILE${NC}"
    else
        echo -e "• ${BOLD}Clave GPG Mozilla:${NC}        ${RED}❌ No encontrada${NC}"
    fi

    # 3. Pinning APT
    if [ -f "$PREFERENCES_FILE" ]; then
        local pin_prio
        pin_prio=$(awk -F': *' 'tolower($1)=="pin-priority"{prio=$2; found=1} END{if (found) print prio; else print "n/a"}' "$PREFERENCES_FILE" 2>/dev/null || echo "n/a")
        echo -e "• ${BOLD}Prioridad APT (Pinning):${NC}  ${GREEN}✅ Activa (Prioridad: $pin_prio)${NC}"
    else
        echo -e "• ${BOLD}Prioridad APT (Pinning):${NC}  ${YELLOW}⚠️ No configurada${NC}"
    fi

    # 4. Paquete Firefox
    if is_firefox_installed; then
        local ff_ver ff_orig
        ff_ver=$(get_firefox_version)
        ff_orig=$(get_firefox_origin)
        echo -e "• ${BOLD}Paquete Firefox:${NC}          ${GREEN}✅ Instalado (v${ff_ver})${NC}"
        echo -e "  - Origen del paquete:     $ff_orig"
    else
        echo -e "• ${BOLD}Paquete Firefox:${NC}          ${RED}❌ No instalado${NC}"
    fi

    # 5. Idioma Español
    if is_pkg_installed "$L10N_PACKAGE"; then
        echo -e "• ${BOLD}Localización Español:${NC}     ${GREEN}✅ Instalada ($L10N_PACKAGE)${NC}"
    else
        echo -e "• ${BOLD}Localización Español:${NC}     ${YELLOW}⚠️ No instalada${NC}"
    fi

    # 6. Firefox ESR
    if is_pkg_installed firefox-esr; then
        local esr_v
        esr_v=$(get_pkg_version firefox-esr)
        echo -e "• ${BOLD}Firefox ESR:${NC}              ${YELLOW}⚠️ Presente en el sistema (v$esr_v)${NC}"
    else
        echo -e "• ${BOLD}Firefox ESR:${NC}              ${GREEN}✅ No presente (limpio)${NC}"
    fi

    # 7. Políticas de Aceleración y Wayland
    if [ -f "$POLICIES_FILE" ] && grep -qi "media.ffmpeg.vaapi.enabled" "$POLICIES_FILE" 2>/dev/null; then
        echo -e "• ${BOLD}Aceleración VA-API / GPU:${NC} ${GREEN}✅ Activa en $POLICIES_FILE${NC}"
    else
        echo -e "• ${BOLD}Aceleración VA-API / GPU:${NC} ${YELLOW}ℹ️ Predeterminada (ejecuta '$0 --wayland')${NC}"
    fi

    # 8. Variable MOZ_ENABLE_WAYLAND
    if [ -f "$USER_ENV_FILE" ] && grep -qE '^[[:space:]]*MOZ_ENABLE_WAYLAND=1([[:space:]]|$)' "$USER_ENV_FILE" 2>/dev/null; then
        echo -e "• ${BOLD}Entorno Wayland:${NC}          ${GREEN}✅ Configurado (MOZ_ENABLE_WAYLAND=1)${NC}"
    else
        echo -e "• ${BOLD}Entorno Wayland:${NC}          ${GREEN}✅ Nativo Wayland en Firefox moderno${NC}"
    fi

    echo -e "${CYAN}=================================================================${NC}"
}

# ------------------------------------------------------------------------------
# 4. CONFIGURACIÓN DEL REPOSITORIO Y PINNING DE MOZILLA
# ------------------------------------------------------------------------------
setup_repo() {
    require_root
    echo -e "${BLUE}ℹ️ [1/4] Configurando repositorio oficial APT de Mozilla...${NC}"

    # 1. Asegurar directorio de llaveros seguros
    $SUDO install -d -m 755 "$KEYRING_DIR"

    # 2. Descargar de forma atómica, validar e instalar la clave pública de Mozilla
    echo -e "  - Instalando clave de firma oficial de Mozilla..."
    local tmp_key
    tmp_key=$(mktemp)
    if command -v curl &>/dev/null; then
        if ! curl -fsSL "$KEYRING_URL" -o "$tmp_key"; then
            rm -f "$tmp_key"
            echo -e "${RED}❌ Error:${NC} No se pudo descargar la clave GPG de Mozilla desde $KEYRING_URL." >&2
            exit 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -qO "$tmp_key" "$KEYRING_URL"; then
            rm -f "$tmp_key"
            echo -e "${RED}❌ Error:${NC} No se pudo descargar la clave GPG de Mozilla desde $KEYRING_URL." >&2
            exit 1
        fi
    else
        rm -f "$tmp_key"
        echo -e "${RED}❌ Error:${NC} Se requiere 'curl' o 'wget' para descargar la clave GPG." >&2
        exit 1
    fi

    if [ ! -s "$tmp_key" ] || ! grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$tmp_key"; then
        rm -f "$tmp_key"
        echo -e "${RED}❌ Error:${NC} La clave descargada no tiene formato PGP válido." >&2
        exit 1
    fi

    $SUDO install -m 644 "$tmp_key" "$KEYRING_FILE"
    rm -f "$tmp_key"

    # 3. Configurar el archivo de orígenes APT de Mozilla
    echo -e "  - Configurando archivo de orígenes en $SOURCES_FILE..."
    echo "deb [signed-by=$KEYRING_FILE] https://packages.mozilla.org/apt mozilla main" | $SUDO tee "$SOURCES_FILE" > /dev/null
    $SUDO chmod 644 "$SOURCES_FILE"

    # 4. Configurar Pinning prioritario para preferir paquetes oficiales sobre Debian ESR
    echo -e "  - Configurando prioridad APT (Pin-Priority: 1000)..."
    $SUDO install -d -m 755 /etc/apt/preferences.d
    cat <<'EOF' | $SUDO tee "$PREFERENCES_FILE" > /dev/null
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
    $SUDO chmod 644 "$PREFERENCES_FILE"

    echo -e "${GREEN}  ✅ Repositorio oficial y prioridades de Mozilla configurados correctamente.${NC}"
}

# ------------------------------------------------------------------------------
# 5. LIMPIEZA DE VERSIONES PREVIAS (ESR / SNAP)
# ------------------------------------------------------------------------------
remove_legacy() {
    require_root
    echo -e "${BLUE}ℹ️ [2/4] Verificando y limpiando versiones redundantes de Firefox...${NC}"

    # Eliminar paquete Snap si existiera
    if command -v snap &>/dev/null && snap list firefox &>/dev/null; then
        echo -e "  - Eliminando Firefox Snap..."
        $SUDO snap remove firefox || true
    fi

    # Purgar Firefox ESR y sus paquetes de localización (incluidos residuos config-files)
    local esr_pkgs=()
    mapfile -t esr_pkgs < <(dpkg-query -W -f='${Package}\t${Status}\n' 'firefox-esr*' 2>/dev/null | awk -F'\t' '$2 ~ /installed|config-files/{print $1}' || true)
    if [ "${#esr_pkgs[@]}" -gt 0 ]; then
        echo -e "  - Purgando Firefox ESR del sistema (${esr_pkgs[*]})..."
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${esr_pkgs[@]}"
    fi

    echo -e "${GREEN}  ✅ Entorno limpio para Firefox nativo.${NC}"
}

# ------------------------------------------------------------------------------
# 6. ACELERACIÓN VA-API Y POLÍTICAS DE INTEGRACIÓN EN KDE PLASMA WAYLAND
# ------------------------------------------------------------------------------
setup_wayland_vaapi() {
    require_root
    echo -e "${BLUE}ℹ️ Optimizando Firefox para Wayland y aceleración VA-API...${NC}"

    # 1. Crear directorio de políticas de sistema de Firefox
    $SUDO mkdir -p "$POLICIES_DIR"

    # 2. Configurar Enterprise Policies para aceleración de hardware y portales Wayland
    cat <<'EOF' | $SUDO tee "$POLICIES_FILE" > /dev/null
{
  "policies": {
    "DisableAppUpdate": false,
    "Preferences": {
      "media.ffmpeg.vaapi.enabled": {
        "Value": true,
        "Status": "default"
      },
      "media.hardware-video-decoding.enabled": {
        "Value": true,
        "Status": "default"
      },
      "widget.use-xdg-desktop-portal.file-picker": {
        "Value": 1,
        "Status": "default"
      },
      "widget.use-xdg-desktop-portal.mime-handler": {
        "Value": 1,
        "Status": "default"
      },
      "browser.tabs.firefox-view": {
        "Value": false,
        "Status": "default"
      }
    }
  }
}
EOF
    $SUDO chmod 644 "$POLICIES_FILE"

    # 3. Asegurar variable MOZ_ENABLE_WAYLAND en variables de entorno del usuario
    local env_dir
    env_dir=$(dirname "$USER_ENV_FILE")
    run_as_user mkdir -p "$env_dir"
    if [ -f "$USER_ENV_FILE" ]; then
        if ! grep -qE '^[[:space:]]*MOZ_ENABLE_WAYLAND=1([[:space:]]|$)' "$USER_ENV_FILE"; then
            echo "MOZ_ENABLE_WAYLAND=1" | run_as_user tee -a "$USER_ENV_FILE" > /dev/null
        fi
    else
        echo "MOZ_ENABLE_WAYLAND=1" | run_as_user tee "$USER_ENV_FILE" > /dev/null
    fi

    echo -e "${GREEN}  ✅ Políticas de aceleración gráfica VA-API y Wayland aplicadas con éxito.${NC}"
}

# ------------------------------------------------------------------------------
# 7. INSTALACIÓN DE FIREFOX NATIVO
# ------------------------------------------------------------------------------
install_firefox() {
    require_root
    setup_repo
    remove_legacy

    echo -e "${BLUE}ℹ️ [3/4] Actualizando catálogo e instalando Firefox nativo (.deb)...${NC}"
    $SUDO apt-get update -qq

    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "$PACKAGE_NAME" \
        "$L10N_PACKAGE"

    echo -e "${BLUE}ℹ️ [4/4] Aplicando optimizaciones de vídeo por hardware y Wayland...${NC}"
    setup_wayland_vaapi

    echo -e "${GREEN}✅ Mozilla Firefox nativo instalado y optimizado correctamente.${NC}"
}

# ------------------------------------------------------------------------------
# 8. ACTUALIZACIÓN DE FIREFOX
# ------------------------------------------------------------------------------
update_firefox() {
    require_root
    if [ ! -f "$SOURCES_FILE" ] || [ ! -f "$KEYRING_FILE" ] || [ ! -f "$PREFERENCES_FILE" ]; then
        echo -e "${YELLOW}⚠️ El repositorio oficial de Mozilla no está completo. Configurándolo...${NC}"
        setup_repo
    fi

    if ! is_firefox_installed; then
        echo -e "${YELLOW}⚠️ Firefox no está instalado actualmente. Ejecuta '$0 --install' para instalarlo.${NC}"
        return 1
    fi

    echo -e "${BLUE}ℹ️ Buscando actualizaciones de Firefox en packages.mozilla.org...${NC}"
    $SUDO apt-get update -qq

    local pkgs=("$PACKAGE_NAME")
    if is_pkg_installed "$L10N_PACKAGE"; then
        pkgs+=("$L10N_PACKAGE")
    fi

    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y "${pkgs[@]}"

    echo -e "${GREEN}✅ Proceso de actualización completado.${NC}"
}

# ------------------------------------------------------------------------------
# 9. DESINSTALACIÓN DE FIREFOX
# ------------------------------------------------------------------------------
uninstall_firefox() {
    require_root
    echo -e "${YELLOW}⚠️ Desinstalando Mozilla Firefox del sistema...${NC}"

    local pkgs=()
    local pkg status
    for pkg in "$PACKAGE_NAME" "$L10N_PACKAGE"; do
        status=$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)
        if [[ "$status" == *"installed"* || "$status" == *"config-files"* ]]; then
            pkgs+=("$pkg")
        fi
    done

    if [ "${#pkgs[@]}" -gt 0 ]; then
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${pkgs[@]}"
    else
        echo -e "  - No se encontraron paquetes de Firefox instalados."
    fi

    if [ -f "$POLICIES_FILE" ]; then
        $SUDO rm -f "$POLICIES_FILE"
    fi

    echo -e "${GREEN}✅ Firefox ha sido desinstalado. (Los datos de usuario en ~/.mozilla se conservan).${NC}"
}

# ------------------------------------------------------------------------------
# 10. ENTRADA PRINCIPAL
# ------------------------------------------------------------------------------
if [ "$#" -gt 1 ]; then
    echo -e "${RED}❌ Demasiados argumentos:${NC} $*" >&2
    show_help
    exit 1
fi

case "${1:-}" in
    -s|--status|status)
        show_status
        exit 0
        ;;
    -i|--install|install)
        install_firefox
        echo ""
        show_status
        exit 0
        ;;
    -u|--update|update)
        update_firefox
        echo ""
        show_status
        exit 0
        ;;
    -w|--wayland|wayland)
        setup_wayland_vaapi
        echo ""
        show_status
        exit 0
        ;;
    -r|--uninstall|uninstall)
        uninstall_firefox
        exit 0
        ;;
    -h|--help|help)
        show_help
        exit 0
        ;;
    "")
        echo -e "${CYAN}=================================================================${NC}"
        echo -e "${BOLD}🚀 INSTALANDO Y OPTIMIZANDO MOZILLA FIREFOX EN DEBIAN 13 (KDE PLASMA 6)${NC}"
        echo -e "${CYAN}=================================================================${NC}"
        install_firefox
        echo ""
        show_status
        echo -e "${CYAN}=================================================================${NC}"
        echo -e "${GREEN}✅ Instalación y configuración completada con éxito.${NC}"
        echo -e "${CYAN}=================================================================${NC}"
        ;;
    *)
        echo -e "${RED}❌ Opción no reconocida:${NC} $1"
        show_help
        exit 1
        ;;
esac

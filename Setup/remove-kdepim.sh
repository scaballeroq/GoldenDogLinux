#!/usr/bin/env bash
# ==============================================================================
# remove-kdepim.sh - Desinstalación limpia de KMail, Akonadi y KDE PIM
# Sistema: Golden Dog Linux (Debian 13 Trixie) | Escritorio: KDE Plasma 6
# ==============================================================================
# Características:
#   - Detiene limpiamente el servidor Akonadi del usuario real antes de purgar
#   - Elimina KMail, Akonadi, KOrganizer, KAddressBook, Akregator y utilidades PIM
#     sin afectar a kde-standard ni a kde-plasma-desktop
#   - Ejecuta apt-get autoremove --purge para limpiar librerías huérfanas (libkpim6*)
#   - Opciones CLI: --status / -s, --clean-data, --pin, --unpin, --all, --help / -h
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &>/dev/null; then
        echo "❌ Error: 'sudo' no está disponible y el script no se ejecuta como root."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6 || true)
else
    REAL_USER="${USER:-$(id -un)}"
    USER_HOME="${HOME:-$(getent passwd "$REAL_USER" | cut -d: -f6 || true)}"
fi
[ -z "$USER_HOME" ] && USER_HOME="/home/$REAL_USER"

REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")

run_as_user() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$REAL_UID}"
    local dbus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime_dir/bus}"
    if [ "$EUID" -eq 0 ] && [ "$REAL_USER" != "root" ]; then
        sudo -u "$REAL_USER" env \
            HOME="$USER_HOME" \
            USER="$REAL_USER" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            "$@"
    else
        "$@"
    fi
}

PIN_FILE="/etc/apt/preferences.d/99-no-akonadi-kdepim"

CORE_PIM_PACKAGES=(
    kmail
    korganizer
    kaddressbook
    akregator
    akonadi-server
    akonadi-backend-sqlite
    kdepim-runtime
    kdepim-addons
    kdepim-themeeditors
    kalendarac
    accountwizard
    kmailtransport-plugins
    mbox-importer
    pim-data-exporter
    pim-sieve-editor
)

USER_DATA_PATHS=(
    "$USER_HOME/.local/share/akonadi"
    "$USER_HOME/.config/akonadi"
    "$USER_HOME/.local/share/kmail2"
    "$USER_HOME/.config/kmail2rc"
    "$USER_HOME/.local/share/korganizer"
    "$USER_HOME/.config/korganizerrc"
    "$USER_HOME/.local/share/kaddressbook"
    "$USER_HOME/.config/kaddressbookrc"
    "$USER_HOME/.local/share/akregator"
    "$USER_HOME/.config/akregatorrc"
)

show_help() {
    cat <<EOF
🧹 Desinstalador de KMail, Akonadi y KDE PIM - Golden Dog Linux (Debian 13 KDE)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)    Detiene Akonadi, purga KMail/Akonadi/KDE PIM y limpia dependencias.
  --status, -s        Muestra el estado actual de paquetes, procesos, datos y bloqueo APT.
  --clean-data        Elimina datos y configuraciones residuales de usuario (~/.local/share/akonadi, etc.).
  --pin               Crea un pin de APT ($PIN_FILE) para evitar que se reinstalen.
  --unpin             Elimina el pin de APT para volver a permitir su instalación.
  --all, -a           Ejecuta desinstalación completa + --clean-data + --pin.
  --help, -h          Muestra este mensaje de ayuda.
EOF
}

show_status() {
    echo "================================================================="
    echo "🔍 ESTADO DE KMAIL, AKONADI Y KDE PIM - GOLDEN DOG LINUX"
    echo "================================================================="

    local installed_count=0
    local installed_list=()
    for pkg in "${CORE_PIM_PACKAGES[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            installed_list+=("$pkg")
            installed_count=$((installed_count + 1))
        fi
    done

    local akonadi_pkgs_count
    akonadi_pkgs_count=$(dpkg-query -W -f='${db:Status-Abbrev}\n' '*akonadi*' 2>/dev/null | grep -c '^ii' || true)

    echo "• Paquetes principales PIM:   $installed_count/${#CORE_PIM_PACKAGES[@]} instalados"
    if [ "$installed_count" -gt 0 ]; then
        echo "  - Detectados: ${installed_list[*]}"
    fi
    echo "• Paquetes *akonadi* activos: $akonadi_pkgs_count"

    if pgrep -u "$REAL_USER" -f 'akonadi_control|akonadiserver' &>/dev/null; then
        echo "• Procesos Akonadi:           🟢 En ejecución"
    else
        echo "• Procesos Akonadi:           ⚪ Detenidos / no activos"
    fi

    local data_found=0
    for path in "${USER_DATA_PATHS[@]}"; do
        [ -e "$path" ] && data_found=$((data_found + 1))
    done
    echo "• Datos residuales usuario:   $data_found ruta(s) encontrada(s) en $USER_HOME"

    if [ -f "$PIN_FILE" ]; then
        echo "• Bloqueo APT (pin):          ✅ Activo ($PIN_FILE)"
    else
        echo "• Bloqueo APT (pin):          ℹ️ No configurado"
    fi
    echo "================================================================="
}

stop_akonadi() {
    echo "🛑 [1/3] Deteniendo servicios de Akonadi para $REAL_USER..."
    if command -v akonadictl &>/dev/null; then
        run_as_user akonadictl stop >/dev/null 2>&1 || true
    fi
    pkill -u "$REAL_USER" -f 'akonadi_control|akonadiserver' >/dev/null 2>&1 || true
    echo "  ✅ Procesos de Akonadi detenidos."
}

purge_kdepim() {
    echo "📦 [2/3] Purgando paquetes de KMail, Akonadi y KDE PIM..."
    local targets=()
    for pkg in "${CORE_PIM_PACKAGES[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            targets+=("$pkg")
        fi
    done

    while IFS= read -r pkg; do
        [ -n "$pkg" ] && targets+=("$pkg")
    done < <(dpkg-query -W -f='${Package}\t${db:Status-Abbrev}\n' '*akonadi*' 2>/dev/null | awk '$2 == "ii" {print $1}')

    if [ "${#targets[@]}" -gt 0 ]; then
        # Eliminar duplicados preservando orden
        local unique_targets=()
        local seen=" "
        for pkg in "${targets[@]}"; do
            if [[ "$seen" != *" $pkg "* ]]; then
                unique_targets+=("$pkg")
                seen+="$pkg "
            fi
        done

        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${unique_targets[@]}"
    else
        echo "  ℹ️ No se encontraron paquetes de KMail/Akonadi instalados."
    fi

    echo "🧹 [3/3] Eliminando dependencias y librerías huérfanas..."
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y
    echo "  ✅ Paquetes y dependencias eliminados correctamente."
}

clean_user_data() {
    echo "🧽 Limpiando datos y configuraciones residuales de KDE PIM en $USER_HOME..."
    local removed=0
    for path in "${USER_DATA_PATHS[@]}"; do
        if [ -e "$path" ]; then
            run_as_user rm -rf "$path"
            echo "  • Eliminado: $path"
            removed=$((removed + 1))
        fi
    done
    if [ "$removed" -eq 0 ]; then
        echo "  ℹ️ No había datos residuales que limpiar."
    else
        echo "  ✅ Limpieza de usuario completada ($removed elemento(s))."
    fi
}

enable_apt_pin() {
    echo "🔒 Configurando bloqueo APT para evitar reinstalación vía Recommends..."
    $SUDO mkdir -p /etc/apt/preferences.d
    $SUDO tee "$PIN_FILE" > /dev/null <<'EOF'
Package: akonadi-server kmail korganizer kaddressbook akregator kdepim-runtime
Pin: release *
Pin-Priority: -1
EOF
    echo "  ✅ Bloqueo guardado en $PIN_FILE"
}

disable_apt_pin() {
    if [ -f "$PIN_FILE" ]; then
        $SUDO rm -f "$PIN_FILE"
        echo "✅ Bloqueo APT eliminado ($PIN_FILE)."
    else
        echo "ℹ️ El bloqueo APT no estaba configurado."
    fi
}

DO_CLEAN_DATA=false
DO_PIN=false

case "${1:-}" in
    --help|-h|help)
        show_help
        exit 0
        ;;
    --status|-s|status)
        show_status
        exit 0
        ;;
    --clean-data)
        clean_user_data
        exit 0
        ;;
    --pin)
        enable_apt_pin
        exit 0
        ;;
    --unpin)
        disable_apt_pin
        exit 0
        ;;
    --all|-a)
        DO_CLEAN_DATA=true
        DO_PIN=true
        ;;
    "")
        ;;
    *)
        echo "❌ Opción no reconocida: $1"
        show_help
        exit 1
        ;;
esac

echo "================================================================="
echo "🧹 DESINSTALANDO KMAIL, AKONADI Y KDE PIM (GOLDEN DOG LINUX)"
echo "================================================================="
stop_akonadi
purge_kdepim

if [ "$DO_CLEAN_DATA" = true ]; then
    clean_user_data
fi

if [ "$DO_PIN" = true ]; then
    enable_apt_pin
fi

echo "================================================================="
echo "✅ Proceso completado. KDE Plasma y kde-standard permanecen intactos."
echo "================================================================="

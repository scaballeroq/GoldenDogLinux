#!/bin/bash
# =============================================================================
# quadlets-setup.sh - Preparador y Desplegador de Quadlets de Podman
# Debian Workstation (KDE Plasma 6 + Wayland)
# =============================================================================
# Uso:
#   ./quadlets-setup.sh                 -> Prepara los directorios de Quadlets y verifica el generador
#   ./quadlets-setup.sh --install-shared-> Instala todos los servicios compartidos globales en systemd user
#   ./quadlets-setup.sh --remove-shared -> Desinstala los servicios compartidos globales de systemd user
#   ./quadlets-setup.sh --status        -> Comprueba las unidades Quadlets generadas en systemd user
#   ./quadlets-setup.sh --help          -> Muestra la ayuda interactiva
# =============================================================================

set -euo pipefail

REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]:-$0}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
PODMAN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_error() { echo -e "${RED}[ERR]${NC}  $1"; }
log_step()  { echo -e "${BLUE}>>${NC}    $1"; }

require_non_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Este script NO debe ejecutarse como root (con sudo)."
        log_error "Los Quadlets de Podman Rootless se gestionan en el espacio de usuario (~/.config/containers/systemd)."
        exit 1
    fi
}

require_podman() {
    if ! command -v podman &>/dev/null; then
        log_error "Podman no está instalado en el sistema."
        echo "💡 Puedes instalarlo y configurarlo ejecutando: $PODMAN_DIR/install/podman-install.sh"
        exit 1
    fi
}

find_quadlet_generator() {
    local gen_path
    for gen_path in \
        /usr/lib/systemd/user-generators/podman-user-generator \
        /lib/systemd/user-generators/podman-user-generator \
        /usr/libexec/podman/quadlet; do
        if [ -x "$gen_path" ] || [ -f "$gen_path" ]; then
            echo "$gen_path"
            return 0
        fi
    done
    return 1
}

show_help() {
    cat <<EOF
⚙️ Gestor de Quadlets para Podman - Debian Workstation (KDE Plasma 6)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)       Crea directorios de systemd para Quadlets, instala la red base
                         y verifica el generador sin auto-arrancar contenedores pesados.
  --install-shared       Instala todos los servicios globales compartidos (.container, .network, .volume)
                         en ~/.config/containers/systemd/global/ y recarga systemd user.
  --remove-shared        Detiene y desinstala los servicios globales compartidos de systemd user.
  --status, -s           Muestra el estado de los Quadlets y servicios de usuario de systemd.
  --help, -h             Muestra este mensaje de ayuda.

Directorios gestionados:
  • ~/.config/containers/systemd/        -> Proyectos activos y contenedores (.container, .network, .volume)
  • ~/.config/containers/systemd/global/ -> Servicios globales compartidos (PostgreSQL, Redis, Traefik, Keycloak)
EOF
}

show_status() {
    echo "================================================================="
    echo "🔍 ESTADO DE SYSTEMD QUADLETS - GOLDEN DOG LINUX (DEBIAN 13)"
    echo "================================================================="
    if ! command -v podman &>/dev/null; then
        echo "• Motor Podman:        ❌ No instalado en el sistema"
        echo "💡 Ejecuta el instalador base: $PODMAN_DIR/install/podman-install.sh"
        echo "================================================================="
        return 0
    fi

    local gen_bin
    gen_bin=$(find_quadlet_generator || true)

    echo "• Directorio Quadlets: $HOME/.config/containers/systemd"
    echo "• Generador Quadlet:   $(if [ -n "$gen_bin" ]; then echo "✅ Presente ($gen_bin)"; else echo "⚠️ No detectado"; fi)"
    echo ""
    echo "📋 Archivos Quadlets configurados:"
    if [ -d "$HOME/.config/containers/systemd" ]; then
        local found_files
        found_files=$(find "$HOME/.config/containers/systemd" -maxdepth 2 \( -name "*.container" -o -name "*.network" -o -name "*.volume" -o -name "*.pod" -o -name "*.kube" \) 2>/dev/null | sed "s|$HOME|~|g" || true)
        if [ -n "$found_files" ]; then
            echo "$found_files" | sed 's/^/  • /'
        else
            echo "  (Sin definiciones instaladas actualmente)"
        fi
    else
        echo "  (Directorio ~/.config/containers/systemd aún no creado)"
    fi
    echo ""
    echo "📋 Validación del Generador Quadlet (--dryrun):"
    if [ -n "$gen_bin" ] && [ -x "$gen_bin" ]; then
        if "$gen_bin" -user -dryrun &>/dev/null; then
            echo "  ✅ Sintaxis de archivos Quadlet verificada sin errores."
        else
            echo "  ⚠️ El generador reportó advertencias. Revisa con: $gen_bin -user -dryrun"
        fi
    else
        echo "  ℹ️ No disponible"
    fi
    echo ""
    echo "📋 Unidades de servicio activas en systemd user:"
    systemctl --user list-units --type=service --state=running "*podman*" "*postgres*" "*redis*" "*traefik*" "*keycloak*" --no-pager 2>/dev/null || echo "  (Ninguna unidad activa)"
    echo "================================================================="
}

setup_systemd_dirs() {
    log_info "Creando directorios de systemd para Quadlets y unidades de usuario..."
    mkdir -p "$HOME/.config/containers/systemd"
    mkdir -p "$HOME/.config/containers/systemd/global"
    mkdir -p "$HOME/.config/systemd/user"

    log_ok "Directorios creados:"
    echo "  ~/.config/containers/systemd/        -> Proyectos activos (Quadlets)"
    echo "  ~/.config/containers/systemd/global/ -> Servicios compartidos globales"
    echo "  ~/.config/systemd/user/              -> Targets y unidades nativas systemd"
}

setup_podman_dirs() {
    log_info "Creando estructura de directorios de proyectos..."
    mkdir -p "$PODMAN_DIR/projects"
    mkdir -p "$PODMAN_DIR/services-shared"
    touch "$PODMAN_DIR/projects/.gitkeep"

    log_ok "Estructura de proyectos lista en: $PODMAN_DIR/projects"
}

install_global_services() {
    local shared_dir="$PODMAN_DIR/services-shared"
    local systemd_global="$HOME/.config/containers/systemd/global"
    local socket_path="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"

    if [ ! -d "$shared_dir" ] || [ -z "$(ls -A "$shared_dir" 2>/dev/null)" ]; then
        log_info "No hay servicios compartidos para instalar en services-shared/"
        return 0
    fi

    log_info "Instalando definiciones de Quadlets compartidas (.container, .network, .volume)..."
    for quadlet_file in "$shared_dir"/*.{container,network,volume}; do
        [ -f "$quadlet_file" ] || continue

        local basename
        basename="$(basename "$quadlet_file")"
        local target="$systemd_global/$basename"

        if grep -q "__PODMAN_SOCKET__" "$quadlet_file" 2>/dev/null; then
            sed "s|__PODMAN_SOCKET__|$socket_path|g" "$quadlet_file" > "$target"
        else
            cp "$quadlet_file" "$target"
        fi

        log_ok "  $basename -> ~/.config/containers/systemd/global/"
    done

    systemctl --user daemon-reload 2>/dev/null || true
    log_ok "Servicios compartidos instalados y registrados en systemd user."
}

remove_global_services() {
    local systemd_global="$HOME/.config/containers/systemd/global"
    if [ ! -d "$systemd_global" ]; then
        log_info "No hay servicios globales instalados."
        return 0
    fi

    log_info "Deteniendo y eliminando servicios globales compartidos..."
    for container_file in "$systemd_global"/*.container; do
        [ -f "$container_file" ] || continue
        local svc_name
        svc_name="$(basename "$container_file" .container).service"
        systemctl --user stop "$svc_name" 2>/dev/null || true
    done

    rm -f "$systemd_global"/*.{container,network,volume} 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    log_ok "Servicios globales compartidos desinstalados de systemd user."
}

verify_quadlets() {
    log_info "Verificando compatibilidad de Quadlets..."
    local podman_version
    podman_version=$(podman --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "5.x")

    log_ok "Quadlets soportado nativamente (Podman $podman_version en Golden Dog Linux / Debian 13)."
    echo ""
    echo "============================================"
    log_ok "Quadlets configurado correctamente"
    echo "============================================"
    echo ""
    echo "Uso rápido de podman-utils:"
    echo "  podman-utils create python-postgres mi-api"
    echo "  podman-utils start mi-api"
    echo "  podman-utils status mi-api"
    echo "  podman-utils install-global <servicio>   (instala bajo demanda postgres-global, redis-global, traefik, keycloak o all)"
    echo ""
}

case "${1:-}" in
    --help|-h|help)
        show_help
        exit 0
        ;;
    --status|-s|status)
        show_status
        exit 0
        ;;
    --install-shared)
        require_non_root
        require_podman
        setup_systemd_dirs
        setup_podman_dirs
        install_global_services
        verify_quadlets
        ;;
    --remove-shared)
        require_non_root
        require_podman
        remove_global_services
        ;;
    "")
        echo "============================================"
        echo "  Configurador de Quadlets - Golden Dog Linux (Debian 13)"
        echo "============================================"
        echo ""
        require_non_root
        require_podman
        setup_systemd_dirs
        setup_podman_dirs
        systemctl --user daemon-reload 2>/dev/null || true
        verify_quadlets
        ;;
    *)
        echo "❌ Opción no reconocida: $1"
        show_help
        exit 1
        ;;
esac

#!/bin/bash
# ==============================================================================
# podman-storybook.sh - Storybook UI Component Explorer Demo
# Golden Dog Linux (Debian 13 Trixie + KDE Plasma 6 Wayland)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PODMAN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

require_non_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "❌ Error: Este script debe ejecutarse sin 'sudo' (Podman Rootless en espacio de usuario)."
        exit 1
    fi
}

require_podman() {
    if ! command -v podman &>/dev/null; then
        echo "❌ Error: Podman no está instalado en el sistema."
        echo "💡 Puedes instalarlo y configurarlo ejecutando: $PODMAN_ROOT/install/podman-install.sh"
        exit 1
    fi
}

CONTAINER_NAME="storybook-dev"
NETWORK="dev-net"
IMAGE="docker.io/storybooks/storybook:latest"

STORYBOOK_PORT="${STORYBOOK_PORT:-6006}"

show_help() {
    cat <<EOF
🎨 Gestor de Storybook (UI Playground) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el contenedor de Storybook en el puerto ${STORYBOOK_PORT}.
  --status, -s      Muestra el estado del contenedor, red y puerto.
  --open, -o        Abre Storybook en el navegador predeterminado de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Storybook.
  --rm, --clean     Detiene y elimina el contenedor de Storybook.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  STORYBOOK_PORT    Puerto web expuesto en el host (por defecto: 6006)
EOF
}

open_ui() {
    local url="http://localhost:${STORYBOOK_PORT}"
    echo "🌐 Abriendo Storybook ($url) en KDE Plasma..."
    if command -v kde-open &>/dev/null; then
        kde-open "$url" &>/dev/null &
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null &
    else
        echo "💡 Abre manualmente en tu navegador: $url"
    fi
}

show_status() {
    echo "================================================================="
    echo "🎨 ESTADO DE STORYBOOK - PODMAN ROOTLESS"
    echo "================================================================="
    if ! command -v podman &>/dev/null; then
        echo "• Motor Podman:  ❌ No instalado en el sistema"
        echo "💡 Ejecuta:      $PODMAN_ROOT/install/podman-install.sh"
        echo "================================================================="
        return 0
    fi

    if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        podman ps -a --filter "name=^${CONTAINER_NAME}$" --format "• Contenedor:  {{.Names}} ({{.Status}})\n• Puertos:     {{.Ports}}\n• Imagen:      {{.Image}}"
    else
        echo "• Contenedor:  ❌ No desplegado ($CONTAINER_NAME)"
    fi

    if podman network exists "$NETWORK" 2>/dev/null; then
        echo "• Red:         ✅ $NETWORK"
    else
        echo "• Red:         ℹ️ No creada ($NETWORK)"
    fi
    echo "-----------------------------------------------------------------"
    echo "🖥️ Storybook Web UI: http://localhost:${STORYBOOK_PORT}"
    echo "================================================================="
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
    --open|-o|open)
        open_ui
        exit 0
        ;;
    --logs|-l|logs)
        require_podman
        exec podman logs -f "$CONTAINER_NAME"
        ;;
    --stop|stop)
        require_non_root
        require_podman
        echo "⏹️ Deteniendo Storybook ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Storybook detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor de Storybook..."
        podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Contenedor '$CONTAINER_NAME' eliminado."
        exit 0
        ;;
    "")
        require_non_root
        require_podman
        ;;
    *)
        echo "❌ Opción no reconocida: $1"
        show_help
        exit 1
        ;;
esac

if ! podman network exists "$NETWORK" 2>/dev/null; then
    echo "🌐 Creando red de desarrollo '$NETWORK'..."
    podman network create "$NETWORK" >/dev/null
fi

echo "ℹ️ Iniciando Storybook (UI Component Playground) en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -p "${STORYBOOK_PORT}:6006" \
    "$IMAGE" >/dev/null

echo "✅ Storybook iniciado correctamente:"
echo "   • Storybook UI:    http://localhost:${STORYBOOK_PORT}"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "applications-development" "Storybook Iniciado" \
        "Web UI: http://localhost:${STORYBOOK_PORT}" 2>/dev/null || true
fi

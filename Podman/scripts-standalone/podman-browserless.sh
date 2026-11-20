#!/bin/bash
# ==============================================================================
# podman-browserless.sh - Browserless Headless Chrome (con Aceleración GPU)
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

CONTAINER_NAME="browserless-dev"
NETWORK="dev-net"
IMAGE="ghcr.io/browserless/chromium:latest"

BROWSERLESS_PORT="${BROWSERLESS_PORT:-3003}"
BROWSERLESS_TOKEN="${BROWSERLESS_TOKEN:-devtoken}"

show_help() {
    cat <<EOF
🌐 Gestor de Browserless (Headless Chromium + GPU) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea Browserless con aceleración GPU (/dev/dri) si existe.
  --status, -s      Muestra el estado del contenedor, aceleración GPU, red y puerto.
  --open, -o        Abre el panel web de Browserless en el navegador de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Browserless.
  --rm, --clean     Detiene y elimina el contenedor de Browserless.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  BROWSERLESS_PORT   Puerto expuesto en el host (por defecto: 3003)
  BROWSERLESS_TOKEN  Token de acceso a la API/WebSocket (por defecto: devtoken)
EOF
}

open_ui() {
    local url="http://localhost:${BROWSERLESS_PORT}/?token=${BROWSERLESS_TOKEN}"
    echo "🌐 Abriendo Browserless ($url) en KDE Plasma..."
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
    echo "🌐 ESTADO DE BROWSERLESS (HEADLESS CHROMIUM) - PODMAN ROOTLESS"
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

    if [ -e /dev/dri/renderD128 ]; then
        echo "• GPU DRI:     ✅ /dev/dri/renderD128 disponible (AMD/Intel)"
    else
        echo "• GPU DRI:     ℹ️ No detectada (modo renderizado por software)"
    fi

    if podman network exists "$NETWORK" 2>/dev/null; then
        echo "• Red:         ✅ $NETWORK"
    else
        echo "• Red:         ℹ️ No creada ($NETWORK)"
    fi
    echo "-----------------------------------------------------------------"
    echo "🖥️ Endpoint HTTP:    http://localhost:${BROWSERLESS_PORT}?token=${BROWSERLESS_TOKEN}"
    echo "🔌 Endpoint WS CDP:  ws://localhost:${BROWSERLESS_PORT}?token=${BROWSERLESS_TOKEN}"
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
        echo "⏹️ Deteniendo Browserless ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Browserless detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor de Browserless..."
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

GPU_ARGS=()
if [ -e /dev/dri/renderD128 ]; then
    GPU_ARGS=(--device /dev/dri --group-add keep-groups)
fi

echo "ℹ️ Iniciando Browserless (Headless Chromium con soporte GPU) en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    --shm-size 2g \
    "${GPU_ARGS[@]}" \
    -e TOKEN="$BROWSERLESS_TOKEN" \
    -p "${BROWSERLESS_PORT}:3000" \
    "$IMAGE" >/dev/null

echo "✅ Browserless iniciado correctamente:"
echo "   • Endpoint HTTP:   http://localhost:${BROWSERLESS_PORT}?token=${BROWSERLESS_TOKEN}"
echo "   • WebSocket CDP:   ws://localhost:${BROWSERLESS_PORT}?token=${BROWSERLESS_TOKEN}"
echo "   • Host en red:     ${CONTAINER_NAME}:3000 (Red: $NETWORK)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "web-browser" "Browserless Iniciado" \
        "Puerto: localhost:${BROWSERLESS_PORT}\nToken: ${BROWSERLESS_TOKEN}" 2>/dev/null || true
fi

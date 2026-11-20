#!/bin/bash
# ==============================================================================
# podman-dozzle.sh - Dozzle Real-Time Container Log Viewer
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

CONTAINER_NAME="dozzle-dev"
NETWORK="dev-net"
IMAGE="docker.io/amir20/dozzle:latest"

DOZZLE_PORT="${DOZZLE_PORT:-8888}"
PODMAN_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"

show_help() {
    cat <<EOF
📋 Gestor de Dozzle (Visor de Logs en Tiempo Real) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Activa podman.socket e inicia el contenedor de Dozzle.
  --status, -s      Muestra el estado del contenedor, socket de Podman, red y puerto.
  --open, -o        Abre Dozzle en el navegador predeterminado de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Dozzle.
  --rm, --clean     Detiene y elimina el contenedor de Dozzle.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  DOZZLE_PORT       Puerto web expuesto en el host (por defecto: 8888)
EOF
}

open_ui() {
    local url="http://localhost:${DOZZLE_PORT}"
    echo "🌐 Abriendo Dozzle ($url) en KDE Plasma..."
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
    echo "📋 ESTADO DE DOZZLE (VISOR DE LOGS) - PODMAN ROOTLESS"
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

    if [ -S "$PODMAN_SOCK" ]; then
        echo "• Socket API:  ✅ $PODMAN_SOCK"
    else
        echo "• Socket API:  ⚠️ Inactivo (se activará automáticamente al iniciar)"
    fi

    if podman network exists "$NETWORK" 2>/dev/null; then
        echo "• Red:         ✅ $NETWORK"
    else
        echo "• Red:         ℹ️ No creada ($NETWORK)"
    fi
    echo "-----------------------------------------------------------------"
    echo "🖥️ Consola Web UI:   http://localhost:${DOZZLE_PORT}"
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
        echo "⏹️ Deteniendo Dozzle ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Dozzle detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor de Dozzle..."
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

if [ ! -S "$PODMAN_SOCK" ]; then
    echo "🔌 Activando podman.socket de usuario en systemd..."
    systemctl --user enable --now podman.socket >/dev/null 2>&1 || true
fi

if ! podman network exists "$NETWORK" 2>/dev/null; then
    echo "🌐 Creando red de desarrollo '$NETWORK'..."
    podman network create "$NETWORK" >/dev/null
fi

echo "ℹ️ Iniciando Dozzle (Logs Viewer) en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    --security-opt label=disable \
    -v "$PODMAN_SOCK:/var/run/docker.sock:ro" \
    -p "${DOZZLE_PORT}:8080" \
    "$IMAGE" >/dev/null

echo "✅ Dozzle iniciado correctamente:"
echo "   • Consola Web UI:  http://localhost:${DOZZLE_PORT}"
echo "   • Socket montado:  $PODMAN_SOCK (Modo lectura)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "utilities-log-viewer" "Dozzle (Logs) Iniciado" \
        "Web UI: http://localhost:${DOZZLE_PORT}" 2>/dev/null || true
fi

#!/bin/bash
# ==============================================================================
# podman-portainer.sh - Portainer CE Container Management Web UI
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

CONTAINER_NAME="portainer-dev"
VOLUME_NAME="portainer-dev-data"
NETWORK="dev-net"
IMAGE="docker.io/portainer/portainer-ce:latest"

PORTAINER_PORT="${PORTAINER_PORT:-9443}"
PODMAN_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"

show_help() {
    cat <<EOF
🎛️ Gestor de Portainer CE - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Activa podman.socket e inicia Portainer CE con volumen persistente.
  --status, -s      Muestra el estado del contenedor, socket de Podman, volumen y puerto.
  --open, -o        Abre Portainer CE en el navegador predeterminado de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Portainer CE.
  --rm, --clean     Detiene el contenedor y elimina el volumen de configuración.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  PORTAINER_PORT    Puerto HTTPS expuesto en el host (por defecto: 9443)
EOF
}

open_ui() {
    local url="https://localhost:${PORTAINER_PORT}"
    echo "🌐 Abriendo Portainer CE ($url) en KDE Plasma..."
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
    echo "🎛️ ESTADO DE PORTAINER CE - PODMAN ROOTLESS"
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

    if podman volume exists "$VOLUME_NAME" 2>/dev/null; then
        echo "• Volumen:     ✅ $VOLUME_NAME (Persistente)"
    else
        echo "• Volumen:     ℹ️ No creado ($VOLUME_NAME)"
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
    echo "🖥️ Consola Web UI:   https://localhost:${PORTAINER_PORT}"
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
        echo "⏹️ Deteniendo Portainer CE ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Portainer CE detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de Portainer CE..."
        podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
        podman volume rm -f "$VOLUME_NAME" 2>/dev/null || true
        echo "✅ Contenedor '$CONTAINER_NAME' y volumen '$VOLUME_NAME' eliminados."
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

if ! podman volume exists "$VOLUME_NAME" 2>/dev/null; then
    echo "💾 Creando volumen persistente '$VOLUME_NAME'..."
    podman volume create "$VOLUME_NAME" >/dev/null
fi

echo "ℹ️ Iniciando Portainer CE en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    --security-opt label=disable \
    -v "$PODMAN_SOCK:/var/run/docker.sock" \
    -v "$VOLUME_NAME:/data:Z" \
    -p "${PORTAINER_PORT}:9443" \
    "$IMAGE" >/dev/null

echo "✅ Portainer CE iniciado correctamente:"
echo "   • Consola Web UI:  https://localhost:${PORTAINER_PORT}"
echo "   • Socket montado:  $PODMAN_SOCK"
echo "   • Volumen datos:   ${VOLUME_NAME} (/data)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "preferences-system" "Portainer CE Iniciado" \
        "Web UI: https://localhost:${PORTAINER_PORT}" 2>/dev/null || true
fi

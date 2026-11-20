#!/bin/bash
# ==============================================================================
# podman-adminer.sh - Adminer Web Database Manager
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

CONTAINER_NAME="adminer-dev"
NETWORK="dev-net"
IMAGE="docker.io/library/adminer:latest"

ADMINER_PORT="${ADMINER_PORT:-8081}"
DEFAULT_SERVER="${ADMINER_DEFAULT_SERVER:-postgres-dev}"

show_help() {
    cat <<EOF
🗄️ Gestor de Adminer (DB Web Admin) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el contenedor de Adminer en la red '$NETWORK'.
  --status, -s      Muestra el estado del contenedor, red y puerto.
  --open, -o        Abre Adminer en el navegador predeterminado de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Adminer.
  --rm, --clean     Detiene y elimina el contenedor de Adminer.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  ADMINER_PORT            Puerto web en el host (por defecto: 8081)
  ADMINER_DEFAULT_SERVER  Servidor de BD preseleccionado (por defecto: postgres-dev)
EOF
}

open_ui() {
    local url="http://localhost:${ADMINER_PORT}"
    echo "🌐 Abriendo Adminer ($url) en KDE Plasma..."
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
    echo "🗄️ ESTADO DE ADMINER (DB ADMIN) - PODMAN ROOTLESS"
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
    echo "🖥️ Consola Web UI:   http://localhost:${ADMINER_PORT}"
    echo "🔌 Servidores DNS:   postgres-dev (5432), mysql-dev (3306), mongo-dev (27017)"
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
        echo "⏹️ Deteniendo Adminer ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Adminer detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor de Adminer..."
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

echo "ℹ️ Iniciando Adminer (Database Web UI) en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e ADMINER_DEFAULT_SERVER="$DEFAULT_SERVER" \
    -p "${ADMINER_PORT}:8080" \
    "$IMAGE" >/dev/null

echo "✅ Adminer iniciado correctamente:"
echo "   • Consola Web UI:  http://localhost:${ADMINER_PORT}"
echo "   • Hosts en red:    postgres-dev, mysql-dev, mongo-dev (Red: $NETWORK)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "server-database" "Adminer Iniciado" \
        "Web UI: http://localhost:${ADMINER_PORT}\nRed conectada: ${NETWORK}" 2>/dev/null || true
fi

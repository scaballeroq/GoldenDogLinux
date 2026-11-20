#!/bin/bash
# ==============================================================================
# podman-nginx.sh - Nginx Web Server
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

CONTAINER_NAME="nginx-dev"
NETWORK="dev-net"
IMAGE="docker.io/library/nginx:alpine"

NGINX_PORT="${NGINX_PORT:-8082}"
NGINX_WEBROOT="${NGINX_WEBROOT:-}"

show_help() {
    cat <<EOF
🌐 Gestor de Nginx Web Server - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el servidor web Nginx.
  --status, -s      Muestra el estado del contenedor, red y puerto.
  --open, -o        Abre la página servida por Nginx en el navegador de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Nginx.
  --rm, --clean     Detiene y elimina el contenedor de Nginx.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  NGINX_PORT        Puerto HTTP expuesto en el host (por defecto: 8082)
  NGINX_WEBROOT     Directorio local opcional para montar en /usr/share/nginx/html
EOF
}

open_ui() {
    local url="http://localhost:${NGINX_PORT}"
    echo "🌐 Abriendo Nginx ($url) en KDE Plasma..."
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
    echo "🌐 ESTADO DE NGINX WEB SERVER - PODMAN ROOTLESS"
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
    echo "🖥️ URL Servidor Web: http://localhost:${NGINX_PORT}"
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
        echo "⏹️ Deteniendo Nginx ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Nginx detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor de Nginx..."
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

VOLUME_ARGS=()
if [ -n "$NGINX_WEBROOT" ] && [ -d "$NGINX_WEBROOT" ]; then
    VOLUME_ARGS=(-v "$(realpath "$NGINX_WEBROOT"):/usr/share/nginx/html:ro,Z")
fi

echo "ℹ️ Iniciando Nginx en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    "${VOLUME_ARGS[@]}" \
    -p "${NGINX_PORT}:80" \
    "$IMAGE" >/dev/null

echo "✅ Nginx iniciado correctamente:"
echo "   • URL Servidor:    http://localhost:${NGINX_PORT}"
echo "   • Host en red:     ${CONTAINER_NAME}:80 (Red: $NETWORK)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "network-server" "Nginx Iniciado" \
        "URL: http://localhost:${NGINX_PORT}" 2>/dev/null || true
fi

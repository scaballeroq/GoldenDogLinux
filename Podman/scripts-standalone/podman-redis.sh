#!/bin/bash
# ==============================================================================
# podman-redis.sh - Redis In-Memory Data Store
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

CONTAINER_NAME="redis-dev"
VOLUME_NAME="redis-dev-data"
NETWORK="dev-net"
IMAGE="docker.io/library/redis:7-alpine"

REDIS_PORT="${REDIS_PORT:-6379}"

show_help() {
    cat <<EOF
⚡ Gestor de Redis - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el contenedor de Redis con persistencia AOF.
  --status, -s      Muestra el estado del contenedor, volumen, red y puerto.
  --cli, -c         Abre una consola interactiva 'redis-cli' dentro del contenedor.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Redis.
  --rm, --clean     Detiene el contenedor y elimina el volumen de datos persistente.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  REDIS_PORT        Puerto expuesto en el host (por defecto: 6379)
EOF
}

show_status() {
    echo "================================================================="
    echo "⚡ ESTADO DE REDIS - PODMAN ROOTLESS"
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
        echo "• Volumen:     ✅ $VOLUME_NAME (Persistente AOF)"
    else
        echo "• Volumen:     ℹ️ No creado ($VOLUME_NAME)"
    fi

    if podman network exists "$NETWORK" 2>/dev/null; then
        echo "• Red:         ✅ $NETWORK"
    else
        echo "• Red:         ℹ️ No creada ($NETWORK)"
    fi
    echo "-----------------------------------------------------------------"
    echo "🔌 URI Local:        redis://localhost:${REDIS_PORT}"
    echo "🌐 Host en '$NETWORK': ${CONTAINER_NAME}:6379"
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
    --cli|-c|cli)
        require_podman
        exec podman exec -it "$CONTAINER_NAME" redis-cli
        ;;
    --logs|-l|logs)
        require_podman
        exec podman logs -f "$CONTAINER_NAME"
        ;;
    --stop|stop)
        require_non_root
        require_podman
        echo "⏹️ Deteniendo Redis ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Redis detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de Redis..."
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

if ! podman network exists "$NETWORK" 2>/dev/null; then
    echo "🌐 Creando red de desarrollo '$NETWORK'..."
    podman network create "$NETWORK" >/dev/null
fi

if ! podman volume exists "$VOLUME_NAME" 2>/dev/null; then
    echo "💾 Creando volumen persistente '$VOLUME_NAME'..."
    podman volume create "$VOLUME_NAME" >/dev/null
fi

echo "ℹ️ Iniciando Redis 7 en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -v "$VOLUME_NAME:/data:Z" \
    -p "${REDIS_PORT}:6379" \
    --health-cmd "redis-cli ping || exit 1" \
    --health-interval 10s \
    --health-timeout 3s \
    --health-retries 3 \
    --health-start-period 5s \
    "$IMAGE" redis-server --appendonly yes >/dev/null

echo "✅ Redis iniciado correctamente:"
echo "   • URI Conexión:    redis://localhost:${REDIS_PORT}"
echo "   • Host en red:     ${CONTAINER_NAME}:6379 (Red: $NETWORK)"
echo "   • Volumen datos:   ${VOLUME_NAME} (/data - AOF activo)"
echo "   • Consola CLI:     $0 --cli"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "server-database" "Redis Iniciado" \
        "URI: redis://localhost:${REDIS_PORT}\nPersistencia: AOF (${VOLUME_NAME})" 2>/dev/null || true
fi

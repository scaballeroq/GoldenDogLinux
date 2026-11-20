#!/bin/bash
# ==============================================================================
# podman-minio.sh - MinIO Object Storage (Compatible con AWS S3)
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

CONTAINER_NAME="minio-dev"
VOLUME_NAME="minio-dev-data"
NETWORK="dev-net"
IMAGE="quay.io/minio/minio:latest"

MINIO_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_PASS="${MINIO_ROOT_PASSWORD:-minioadmin}"
API_PORT="${MINIO_API_PORT:-9000}"
CONSOLE_PORT="${MINIO_CONSOLE_PORT:-9001}"

show_help() {
    cat <<EOF
📦 Gestor de MinIO (S3 Object Storage) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el contenedor de MinIO con volumen persistente.
  --status, -s      Muestra el estado del contenedor, volumen, red y puertos.
  --open, -o        Abre la consola web de MinIO en el navegador de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de MinIO.
  --rm, --clean     Detiene el contenedor y elimina el volumen de datos persistente.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  MINIO_ROOT_USER      Usuario administrador (por defecto: minioadmin)
  MINIO_ROOT_PASSWORD  Contraseña administrador (por defecto: minioadmin)
  MINIO_API_PORT       Puerto de la API S3 (por defecto: 9000)
  MINIO_CONSOLE_PORT   Puerto de la Consola Web (por defecto: 9001)
EOF
}

open_console() {
    local url="http://localhost:${CONSOLE_PORT}"
    echo "🌐 Abriendo consola de MinIO ($url) en KDE Plasma..."
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
    echo "📦 ESTADO DE MINIO (S3 COMPATIBLE) - PODMAN ROOTLESS"
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

    if podman network exists "$NETWORK" 2>/dev/null; then
        echo "• Red:         ✅ $NETWORK"
    else
        echo "• Red:         ℹ️ No creada ($NETWORK)"
    fi
    echo "-----------------------------------------------------------------"
    echo "🌐 S3 API Endpoint:  http://localhost:${API_PORT} (Interno: http://${CONTAINER_NAME}:9000)"
    echo "🖥️ Consola Web UI:   http://localhost:${CONSOLE_PORT}"
    echo "🔑 Credenciales:     ${MINIO_USER} / ${MINIO_PASS}"
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
        open_console
        exit 0
        ;;
    --logs|-l|logs)
        require_podman
        exec podman logs -f "$CONTAINER_NAME"
        ;;
    --stop|stop)
        require_non_root
        require_podman
        echo "⏹️ Deteniendo MinIO ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ MinIO detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de MinIO..."
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

echo "ℹ️ Iniciando MinIO (S3 Compatible Object Storage) en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e MINIO_ROOT_USER="$MINIO_USER" \
    -e MINIO_ROOT_PASSWORD="$MINIO_PASS" \
    -v "$VOLUME_NAME:/data:Z" \
    -p "${API_PORT}:9000" \
    -p "${CONSOLE_PORT}:9001" \
    --health-cmd "curl -sf http://localhost:9000/minio/health/live || exit 1" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 3 \
    --health-start-period 10s \
    "$IMAGE" server /data --console-address ":9001" >/dev/null

echo "✅ MinIO iniciado correctamente:"
echo "   • S3 API Endpoint: http://localhost:${API_PORT} (DNS en red '$NETWORK': http://${CONTAINER_NAME}:9000)"
echo "   • Consola Web UI:  http://localhost:${CONSOLE_PORT}"
echo "   • Credenciales:    ${MINIO_USER} / ${MINIO_PASS}"
echo "   • Volumen datos:   ${VOLUME_NAME} (/data)"
echo "   • Abrir consola:   $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "folder-cloud" "MinIO (S3) Iniciado" \
        "API: localhost:${API_PORT} | Consola: http://localhost:${CONSOLE_PORT}\nCredenciales: ${MINIO_USER} / ${MINIO_PASS}" 2>/dev/null || true
fi


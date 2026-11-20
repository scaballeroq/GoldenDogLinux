#!/bin/bash
# ==============================================================================
# podman-jaeger.sh - Jaeger Distributed Tracing All-in-One (OpenTelemetry)
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

CONTAINER_NAME="jaeger-dev"
NETWORK="dev-net"
IMAGE="docker.io/jaegertracing/all-in-one:latest"

JAEGER_UI_PORT="${JAEGER_UI_PORT:-16686}"
OTLP_GRPC_PORT="${OTLP_GRPC_PORT:-4317}"
OTLP_HTTP_PORT="${OTLP_HTTP_PORT:-4318}"

show_help() {
    cat <<EOF
🔍 Gestor de Jaeger (Distributed Tracing + OTLP) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea Jaeger All-in-One con soporte OpenTelemetry (OTLP).
  --status, -s      Muestra el estado del contenedor, red y puertos de trazabilidad.
  --open, -o        Abre la interfaz de Jaeger en el navegador de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Jaeger.
  --rm, --clean     Detiene y elimina el contenedor de Jaeger.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  JAEGER_UI_PORT    Puerto de la interfaz web (por defecto: 16686)
  OTLP_GRPC_PORT    Puerto OpenTelemetry gRPC (por defecto: 4317)
  OTLP_HTTP_PORT    Puerto OpenTelemetry HTTP (por defecto: 4318)
EOF
}

open_ui() {
    local url="http://localhost:${JAEGER_UI_PORT}"
    echo "🌐 Abriendo Jaeger UI ($url) en KDE Plasma..."
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
    echo "🔍 ESTADO DE JAEGER (TRACING & OTLP) - PODMAN ROOTLESS"
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
    echo "🖥️ Jaeger Web UI:    http://localhost:${JAEGER_UI_PORT}"
    echo "📡 OTLP Endpoints:   gRPC localhost:${OTLP_GRPC_PORT} | HTTP localhost:${OTLP_HTTP_PORT}"
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
        echo "⏹️ Deteniendo Jaeger ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Jaeger detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor de Jaeger..."
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

echo "ℹ️ Iniciando Jaeger (All-in-One + OpenTelemetry) en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e COLLECTOR_OTLP_ENABLED=true \
    -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
    -p "${JAEGER_UI_PORT}:16686" \
    -p "${OTLP_GRPC_PORT}:4317" \
    -p "${OTLP_HTTP_PORT}:4318" \
    -p 6831:6831/udp -p 6832:6832/udp \
    -p 5778:5778 -p 14268:14268 -p 14250:14250 -p 9411:9411 \
    "$IMAGE" >/dev/null

echo "✅ Jaeger iniciado correctamente:"
echo "   • Jaeger Web UI:   http://localhost:${JAEGER_UI_PORT}"
echo "   • OTLP gRPC/HTTP:  localhost:${OTLP_GRPC_PORT} / localhost:${OTLP_HTTP_PORT}"
echo "   • Host en red:     ${CONTAINER_NAME} (Red: $NETWORK)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "utilities-system-monitor" "Jaeger Tracing Iniciado" \
        "Web UI: http://localhost:${JAEGER_UI_PORT}\nOTLP: ${OTLP_GRPC_PORT} (gRPC) / ${OTLP_HTTP_PORT} (HTTP)" 2>/dev/null || true
fi

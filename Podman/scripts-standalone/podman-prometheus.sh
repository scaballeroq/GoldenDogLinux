#!/bin/bash
# ==============================================================================
# podman-prometheus.sh - Prometheus Monitoring System & Time Series Database
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

CONTAINER_NAME="prometheus-dev"
VOLUME_NAME="prometheus-dev-data"
NETWORK="dev-net"
IMAGE="docker.io/prom/prometheus:latest"

# Nota: En Golden Dog Linux, Cockpit usa 9090 bajo demanda. Si 9090 está ocupado,
# se puede ajustar con PROMETHEUS_PORT=9091 ./podman-prometheus.sh
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"

show_help() {
    cat <<EOF
🔥 Gestor de Prometheus (Time Series Metrics) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el contenedor de Prometheus con volumen persistente.
  --status, -s      Muestra el estado del contenedor, volumen, red y puerto.
  --open, -o        Abre Prometheus en el navegador predeterminado de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Prometheus.
  --rm, --clean     Detiene el contenedor y elimina el volumen de métricas.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  PROMETHEUS_PORT   Puerto expuesto en el host (por defecto: 9090; usa 9091 si Cockpit está activo)
EOF
}

open_ui() {
    local url="http://localhost:${PROMETHEUS_PORT}"
    echo "🌐 Abriendo Prometheus ($url) en KDE Plasma..."
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
    echo "🔥 ESTADO DE PROMETHEUS - PODMAN ROOTLESS"
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
    echo "🖥️ Consola Web UI:   http://localhost:${PROMETHEUS_PORT}"
    echo "🌐 URL para Grafana: http://${CONTAINER_NAME}:9090"
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
        echo "⏹️ Deteniendo Prometheus ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Prometheus detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de Prometheus..."
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

if [ "$PROMETHEUS_PORT" = "9090" ] && systemctl is-active --quiet cockpit.socket 2>/dev/null; then
    echo "⚠️  Nota: 'cockpit.socket' está escuchando en el puerto 9090. Cambiando puerto de Prometheus a 9091."
    PROMETHEUS_PORT=9091
fi

if ! podman network exists "$NETWORK" 2>/dev/null; then
    echo "🌐 Creando red de desarrollo '$NETWORK'..."
    podman network create "$NETWORK" >/dev/null
fi

if ! podman volume exists "$VOLUME_NAME" 2>/dev/null; then
    echo "💾 Creando volumen persistente '$VOLUME_NAME'..."
    podman volume create "$VOLUME_NAME" >/dev/null
fi

echo "ℹ️ Iniciando Prometheus en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -v "$VOLUME_NAME:/prometheus:Z" \
    -p "${PROMETHEUS_PORT}:9090" \
    --health-cmd "wget --no-verbose --tries=1 --spider http://localhost:9090/-/healthy || exit 1" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 3 \
    --health-start-period 10s \
    "$IMAGE" >/dev/null

echo "✅ Prometheus iniciado correctamente:"
echo "   • Consola Web UI:  http://localhost:${PROMETHEUS_PORT}"
echo "   • Datasource DNS:  http://${CONTAINER_NAME}:9090 (Para Grafana en '$NETWORK')"
echo "   • Volumen datos:   ${VOLUME_NAME} (/prometheus)"
echo "   • Abrir interfaz:  PROMETHEUS_PORT=${PROMETHEUS_PORT} $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "utilities-system-monitor" "Prometheus Iniciado" \
        "Web UI: http://localhost:${PROMETHEUS_PORT}\nDatasource: http://${CONTAINER_NAME}:9090" 2>/dev/null || true
fi

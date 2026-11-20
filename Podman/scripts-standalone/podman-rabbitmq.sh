#!/bin/bash
# ==============================================================================
# podman-rabbitmq.sh - RabbitMQ Message Broker (con Management Web UI)
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

CONTAINER_NAME="rabbitmq-dev"
VOLUME_NAME="rabbitmq-dev-data"
NETWORK="dev-net"
IMAGE="docker.io/library/rabbitmq:3-management-alpine"

RMQ_USER="${RABBITMQ_DEFAULT_USER:-guest}"
RMQ_PASS="${RABBITMQ_DEFAULT_PASS:-guest}"
AMQP_PORT="${RABBITMQ_AMQP_PORT:-5672}"
UI_PORT="${RABBITMQ_UI_PORT:-15672}"

show_help() {
    cat <<EOF
🐰 Gestor de RabbitMQ (Message Broker) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea RabbitMQ Management con volumen persistente.
  --status, -s      Muestra el estado del contenedor, volumen, red y puertos.
  --open, -o        Abre la consola de RabbitMQ en el navegador de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de RabbitMQ.
  --rm, --clean     Detiene el contenedor y elimina el volumen de colas/mensajes.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  RABBITMQ_DEFAULT_USER  Usuario por defecto (por defecto: guest)
  RABBITMQ_DEFAULT_PASS  Contraseña por defecto (por defecto: guest)
  RABBITMQ_AMQP_PORT     Puerto AMQP (por defecto: 5672)
  RABBITMQ_UI_PORT       Puerto Management Web UI (por defecto: 15672)
EOF
}

open_ui() {
    local url="http://localhost:${UI_PORT}"
    echo "🌐 Abriendo RabbitMQ Management ($url) en KDE Plasma..."
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
    echo "🐰 ESTADO DE RABBITMQ (MESSAGE BROKER) - PODMAN ROOTLESS"
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
    echo "🔌 AMQP URI:         amqp://${RMQ_USER}:${RMQ_PASS}@localhost:${AMQP_PORT}/"
    echo "🖥️ Management UI:    http://localhost:${UI_PORT}"
    echo "🔑 Credenciales:     ${RMQ_USER} / ${RMQ_PASS}"
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
        echo "⏹️ Deteniendo RabbitMQ ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ RabbitMQ detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de RabbitMQ..."
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

echo "ℹ️ Iniciando RabbitMQ (Management) en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e RABBITMQ_DEFAULT_USER="$RMQ_USER" \
    -e RABBITMQ_DEFAULT_PASS="$RMQ_PASS" \
    -v "$VOLUME_NAME:/var/lib/rabbitmq:Z" \
    -p "${AMQP_PORT}:5672" \
    -p "${UI_PORT}:15672" \
    --health-cmd "rabbitmq-diagnostics -q ping || exit 1" \
    --health-interval 15s \
    --health-timeout 5s \
    --health-retries 5 \
    --health-start-period 20s \
    "$IMAGE" >/dev/null

echo "✅ RabbitMQ iniciado correctamente:"
echo "   • AMQP Endpoint:   amqp://${RMQ_USER}:${RMQ_PASS}@localhost:${AMQP_PORT}/"
echo "   • Management UI:   http://localhost:${UI_PORT}"
echo "   • Credenciales:    ${RMQ_USER} / ${RMQ_PASS}"
echo "   • Volumen datos:   ${VOLUME_NAME} (/var/lib/rabbitmq)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "network-server" "RabbitMQ Iniciado" \
        "AMQP: ${AMQP_PORT} | UI: http://localhost:${UI_PORT}\nCredenciales: ${RMQ_USER} / ${RMQ_PASS}" 2>/dev/null || true
fi

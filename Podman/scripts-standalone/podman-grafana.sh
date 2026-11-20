#!/bin/bash
# ==============================================================================
# podman-grafana.sh - Grafana Observability & Analytics Dashboard
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

CONTAINER_NAME="grafana-dev"
VOLUME_NAME="grafana-dev-data"
NETWORK="dev-net"
IMAGE="docker.io/grafana/grafana:latest"

GRAFANA_PORT="${GRAFANA_PORT:-3000}"
GF_USER="${GF_SECURITY_ADMIN_USER:-admin}"
GF_PASS="${GF_SECURITY_ADMIN_PASSWORD:-admin}"

show_help() {
    cat <<EOF
📊 Gestor de Grafana - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el contenedor de Grafana con volumen persistente.
  --status, -s      Muestra el estado del contenedor, volumen, red y puerto.
  --open, -o        Abre Grafana en el navegador predeterminado de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Grafana.
  --rm, --clean     Detiene el contenedor y elimina el volumen de dashboards.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  GRAFANA_PORT                Puerto web expuesto en el host (por defecto: 3000)
  GF_SECURITY_ADMIN_USER      Usuario administrador (por defecto: admin)
  GF_SECURITY_ADMIN_PASSWORD  Contraseña administrador (por defecto: admin)
EOF
}

open_ui() {
    local url="http://localhost:${GRAFANA_PORT}"
    echo "🌐 Abriendo Grafana ($url) en KDE Plasma..."
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
    echo "📊 ESTADO DE GRAFANA - PODMAN ROOTLESS"
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
    echo "🖥️ Consola Web UI:   http://localhost:${GRAFANA_PORT}"
    echo "🔑 Credenciales:     ${GF_USER} / ${GF_PASS}"
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
        echo "⏹️ Deteniendo Grafana ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Grafana detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de Grafana..."
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

echo "ℹ️ Iniciando Grafana en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e GF_SECURITY_ADMIN_USER="$GF_USER" \
    -e GF_SECURITY_ADMIN_PASSWORD="$GF_PASS" \
    -v "$VOLUME_NAME:/var/lib/grafana:Z" \
    -p "${GRAFANA_PORT}:3000" \
    --health-cmd "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 5 \
    --health-start-period 15s \
    "$IMAGE" >/dev/null

echo "✅ Grafana iniciado correctamente:"
echo "   • Consola Web UI:  http://localhost:${GRAFANA_PORT}"
echo "   • Credenciales:    ${GF_USER} / ${GF_PASS}"
echo "   • Volumen datos:   ${VOLUME_NAME} (/var/lib/grafana)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "utilities-system-monitor" "Grafana Iniciado" \
        "Web UI: http://localhost:${GRAFANA_PORT}\nCredenciales: ${GF_USER} / ${GF_PASS}" 2>/dev/null || true
fi

#!/bin/bash
# ==============================================================================
# podman-mailhog.sh - MailHog Development SMTP Server & Web Inbox
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

CONTAINER_NAME="mailhog-dev"
NETWORK="dev-net"
IMAGE="docker.io/mailhog/mailhog:latest"

SMTP_PORT="${MAILHOG_SMTP_PORT:-1025}"
WEB_PORT="${MAILHOG_WEB_PORT:-8025}"

show_help() {
    cat <<EOF
✉️ Gestor de MailHog (SMTP Testing Server) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el servidor SMTP de pruebas MailHog.
  --status, -s      Muestra el estado del contenedor, red y puertos SMTP/Web.
  --open, -o        Abre la bandeja de entrada web de MailHog en KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de MailHog.
  --rm, --clean     Detiene y elimina el contenedor de MailHog.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  MAILHOG_SMTP_PORT Puerto SMTP en el host (por defecto: 1025)
  MAILHOG_WEB_PORT  Puerto de la bandeja web (por defecto: 8025)
EOF
}

open_ui() {
    local url="http://localhost:${WEB_PORT}"
    echo "🌐 Abriendo bandeja web de MailHog ($url) en KDE Plasma..."
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
    echo "✉️ ESTADO DE MAILHOG (SMTP TESTING) - PODMAN ROOTLESS"
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
    echo "📮 Servidor SMTP:    localhost:${SMTP_PORT} (En red '$NETWORK': ${CONTAINER_NAME}:1025)"
    echo "🖥️ Bandeja Web UI:   http://localhost:${WEB_PORT}"
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
        echo "⏹️ Deteniendo MailHog ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ MailHog detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor de MailHog..."
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

echo "ℹ️ Iniciando MailHog (SMTP & Web Inbox) en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -p "${SMTP_PORT}:1025" \
    -p "${WEB_PORT}:8025" \
    "$IMAGE" >/dev/null

echo "✅ MailHog iniciado correctamente:"
echo "   • Servidor SMTP:   localhost:${SMTP_PORT} (Host en '$NETWORK': ${CONTAINER_NAME}:1025)"
echo "   • Bandeja Web UI:  http://localhost:${WEB_PORT}"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "mail-unread" "MailHog Iniciado" \
        "SMTP: localhost:${SMTP_PORT}\nWeb UI: http://localhost:${WEB_PORT}" 2>/dev/null || true
fi

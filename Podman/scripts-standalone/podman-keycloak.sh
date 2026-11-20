#!/bin/bash
# ==============================================================================
# podman-keycloak.sh - Keycloak Identity & Access Management (OAuth2 / OIDC)
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

CONTAINER_NAME="keycloak-dev"
VOLUME_NAME="keycloak-dev-data"
NETWORK="dev-net"
IMAGE="quay.io/keycloak/keycloak:26"

KC_PORT="${KEYCLOAK_PORT:-8083}"
KC_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KC_PASS="${KEYCLOAK_ADMIN_PASSWORD:-admin}"

show_help() {
    cat <<EOF
🔐 Gestor de Keycloak (IAM / OIDC) - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea Keycloak 26 en modo desarrollo con volumen persistente.
  --status, -s      Muestra el estado del contenedor, volumen, red y puerto.
  --open, -o        Abre la consola de administración de Keycloak en KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de Keycloak.
  --rm, --clean     Detiene el contenedor y elimina el volumen de realms/datos.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  KEYCLOAK_PORT            Puerto web expuesto en el host (por defecto: 8083)
  KEYCLOAK_ADMIN           Usuario administrador (por defecto: admin)
  KEYCLOAK_ADMIN_PASSWORD  Contraseña administrador (por defecto: admin)
EOF
}

open_ui() {
    local url="http://localhost:${KC_PORT}"
    echo "🌐 Abriendo Keycloak ($url) en KDE Plasma..."
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
    echo "🔐 ESTADO DE KEYCLOAK (OAUTH2 / OIDC) - PODMAN ROOTLESS"
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
    echo "🖥️ Consola Admin:    http://localhost:${KC_PORT}"
    echo "🔑 Credenciales:     ${KC_ADMIN} / ${KC_PASS}"
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
        echo "⏹️ Deteniendo Keycloak ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ Keycloak detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de Keycloak..."
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

echo "ℹ️ Iniciando Keycloak 26 en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e KC_BOOTSTRAP_ADMIN_USERNAME="$KC_ADMIN" \
    -e KC_BOOTSTRAP_ADMIN_PASSWORD="$KC_PASS" \
    -e KEYCLOAK_ADMIN="$KC_ADMIN" \
    -e KEYCLOAK_ADMIN_PASSWORD="$KC_PASS" \
    -v "$VOLUME_NAME:/opt/keycloak/data:Z" \
    -p "${KC_PORT}:8080" \
    "$IMAGE" start-dev >/dev/null

echo "✅ Keycloak iniciado correctamente:"
echo "   • Consola Web UI:  http://localhost:${KC_PORT}"
echo "   • Credenciales:    ${KC_ADMIN} / ${KC_PASS}"
echo "   • Volumen datos:   ${VOLUME_NAME} (/opt/keycloak/data)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "dialog-password" "Keycloak (IAM) Iniciado" \
        "Web UI: http://localhost:${KC_PORT}\nCredenciales: ${KC_ADMIN} / ${KC_PASS}" 2>/dev/null || true
fi

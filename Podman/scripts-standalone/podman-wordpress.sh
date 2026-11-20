#!/bin/bash
# ==============================================================================
# podman-wordpress.sh - WordPress CMS Development Environment
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

CONTAINER_NAME="wordpress-dev"
VOLUME_NAME="wordpress-dev-data"
NETWORK="dev-net"
IMAGE="docker.io/library/wordpress:latest"

WP_PORT="${WORDPRESS_PORT:-8080}"
WP_DB_HOST="${WORDPRESS_DB_HOST:-mysql-dev:3306}"
WP_DB_USER="${WORDPRESS_DB_USER:-root}"
WP_DB_PASS="${WORDPRESS_DB_PASSWORD:-root}"
WP_DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"

show_help() {
    cat <<EOF
📝 Gestor de WordPress CMS - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea WordPress con volumen persistente (conectado a mysql-dev).
  --status, -s      Muestra el estado del contenedor, base de datos MySQL, volumen y puerto.
  --open, -o        Abre WordPress en el navegador predeterminado de KDE Plasma.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de WordPress.
  --rm, --clean     Detiene el contenedor y elimina el volumen de archivos web.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  WORDPRESS_PORT         Puerto web expuesto en el host (por defecto: 8080)
  WORDPRESS_DB_HOST      Host de MySQL en '$NETWORK' (por defecto: mysql-dev:3306)
  WORDPRESS_DB_USER      Usuario de base de datos (por defecto: root)
  WORDPRESS_DB_PASSWORD  Contraseña de base de datos (por defecto: root)
  WORDPRESS_DB_NAME      Nombre de base de datos (por defecto: wordpress)
EOF
}

open_ui() {
    local url="http://localhost:${WP_PORT}"
    echo "🌐 Abriendo WordPress ($url) en KDE Plasma..."
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
    echo "📝 ESTADO DE WORDPRESS CMS - PODMAN ROOTLESS"
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

    if podman container exists "mysql-dev" 2>/dev/null; then
        echo "• Base Datos:  ✅ mysql-dev detectado en red '$NETWORK'"
    else
        echo "• Base Datos:  ⚠️ mysql-dev no detectado (inícialo con ./podman-mysql.sh)"
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
    echo "🖥️ Sitio WordPress:  http://localhost:${WP_PORT}"
    echo "🗄️ Conexión MySQL:   ${WP_DB_HOST} (DB: ${WP_DB_NAME})"
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
        echo "⏹️ Deteniendo WordPress ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ WordPress detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de WordPress..."
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

if ! podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^mysql-dev$"; then
    echo "⚠️  Aviso: El contenedor 'mysql-dev' no está en ejecución."
    echo "💡 Recuerda iniciarlo con: $SCRIPT_DIR/podman-mysql.sh"
fi

echo "ℹ️ Iniciando WordPress en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e WORDPRESS_DB_HOST="$WP_DB_HOST" \
    -e WORDPRESS_DB_USER="$WP_DB_USER" \
    -e WORDPRESS_DB_PASSWORD="$WP_DB_PASS" \
    -e WORDPRESS_DB_NAME="$WP_DB_NAME" \
    -v "$VOLUME_NAME:/var/www/html:Z" \
    -p "${WP_PORT}:80" \
    "$IMAGE" >/dev/null

echo "✅ WordPress iniciado correctamente:"
echo "   • Sitio Web:       http://localhost:${WP_PORT}"
echo "   • Base de datos:   ${WP_DB_HOST} (DB: ${WP_DB_NAME})"
echo "   • Volumen datos:   ${VOLUME_NAME} (/var/www/html)"
echo "   • Abrir interfaz:  $0 --open"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "applications-internet" "WordPress Iniciado" \
        "Web UI: http://localhost:${WP_PORT}\nMySQL Host: ${WP_DB_HOST}" 2>/dev/null || true
fi

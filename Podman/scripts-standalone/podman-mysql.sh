#!/bin/bash
# ==============================================================================
# podman-mysql.sh - MySQL Database Server
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

CONTAINER_NAME="mysql-dev"
VOLUME_NAME="mysql-dev-data"
NETWORK="dev-net"
IMAGE="docker.io/library/mysql:8.4"

MYSQL_ROOT_PASS="${MYSQL_ROOT_PASSWORD:-root}"
MYSQL_DB_NAME="${MYSQL_DATABASE:-wordpress}"
MYSQL_PORT="${MYSQL_PORT:-3306}"

show_help() {
    cat <<EOF
🐬 Gestor de MySQL - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el contenedor de MySQL con volumen persistente.
  --status, -s      Muestra el estado del contenedor, volumen, red y puerto.
  --cli, -c         Abre una consola interactiva 'mysql' dentro del contenedor.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de MySQL.
  --rm, --clean     Detiene el contenedor y elimina el volumen de datos persistente.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  MYSQL_ROOT_PASSWORD  Contraseña de root (por defecto: root)
  MYSQL_DATABASE       Base de datos inicial (por defecto: wordpress)
  MYSQL_PORT           Puerto expuesto en el host (por defecto: 3306)
EOF
}

show_status() {
    echo "================================================================="
    echo "🐬 ESTADO DE MYSQL - PODMAN ROOTLESS"
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
    echo "🔌 Puerto Local:     localhost:${MYSQL_PORT} (DB: ${MYSQL_DB_NAME})"
    echo "🌐 Host en '$NETWORK': ${CONTAINER_NAME}:3306"
    echo "🔑 Credenciales:     root / ${MYSQL_ROOT_PASS}"
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
        exec podman exec -it "$CONTAINER_NAME" mysql -uroot -p"$MYSQL_ROOT_PASS" "$MYSQL_DB_NAME"
        ;;
    --logs|-l|logs)
        require_podman
        exec podman logs -f "$CONTAINER_NAME"
        ;;
    --stop|stop)
        require_non_root
        require_podman
        echo "⏹️ Deteniendo MySQL ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ MySQL detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de MySQL..."
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

echo "ℹ️ Iniciando MySQL 8.4 LTS en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASS" \
    -e MYSQL_DATABASE="$MYSQL_DB_NAME" \
    -v "$VOLUME_NAME:/var/lib/mysql:Z" \
    -p "${MYSQL_PORT}:3306" \
    --health-cmd "mysqladmin ping -h localhost -uroot -p$MYSQL_ROOT_PASS || exit 1" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 5 \
    --health-start-period 20s \
    "$IMAGE" >/dev/null

echo "✅ MySQL iniciado correctamente:"
echo "   • Puerto Local:    localhost:${MYSQL_PORT} (Base de datos inicial: ${MYSQL_DB_NAME})"
echo "   • Host en red:     ${CONTAINER_NAME}:3306 (Red: $NETWORK)"
echo "   • Credenciales:    root / ${MYSQL_ROOT_PASS}"
echo "   • Volumen datos:   ${VOLUME_NAME} (/var/lib/mysql)"
echo "   • Consola mysql:   $0 --cli"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "server-database" "MySQL Iniciado" \
        "Puerto: localhost:${MYSQL_PORT} | DB: ${MYSQL_DB_NAME}\nCredenciales: root / ${MYSQL_ROOT_PASS}" 2>/dev/null || true
fi

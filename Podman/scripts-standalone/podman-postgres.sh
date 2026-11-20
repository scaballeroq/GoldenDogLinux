#!/bin/bash
# ==============================================================================
# podman-postgres.sh - PostgreSQL Database Server
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

CONTAINER_NAME="postgres-dev"
VOLUME_NAME="postgres-dev-data"
NETWORK="dev-net"
IMAGE="docker.io/library/postgres:17-alpine"

PG_USER="${POSTGRES_USER:-postgres}"
PG_PASS="${POSTGRES_PASSWORD:-postgres}"
PG_DB="${POSTGRES_DB:-postgres}"
PG_PORT="${POSTGRES_PORT:-5432}"

show_help() {
    cat <<EOF
🐘 Gestor de PostgreSQL - Podman Rootless (Debian 13 KDE Plasma)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)  Inicia o recrea el contenedor de PostgreSQL con volumen persistente.
  --status, -s      Muestra el estado del contenedor, volumen, red y puerto.
  --cli, -c         Abre una consola interactiva 'psql' dentro del contenedor.
  --logs, -l        Muestra los logs en tiempo real del contenedor.
  --stop            Detiene el contenedor de PostgreSQL.
  --rm, --clean     Detiene el contenedor y elimina el volumen de datos persistente.
  --help, -h        Muestra este mensaje de ayuda.

Variables de entorno admitidas:
  POSTGRES_USER      Usuario superadmin (por defecto: postgres)
  POSTGRES_PASSWORD  Contraseña (por defecto: postgres)
  POSTGRES_DB        Base de datos inicial (por defecto: postgres)
  POSTGRES_PORT      Puerto expuesto en el host (por defecto: 5432)
EOF
}

show_status() {
    echo "================================================================="
    echo "🐘 ESTADO DE POSTGRESQL - PODMAN ROOTLESS"
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
    echo "🔌 URI Local:        postgresql://${PG_USER}:${PG_PASS}@localhost:${PG_PORT}/${PG_DB}"
    echo "🌐 Host en '$NETWORK': ${CONTAINER_NAME}:5432"
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
        exec podman exec -it "$CONTAINER_NAME" psql -U "$PG_USER" -d "$PG_DB"
        ;;
    --logs|-l|logs)
        require_podman
        exec podman logs -f "$CONTAINER_NAME"
        ;;
    --stop|stop)
        require_non_root
        require_podman
        echo "⏹️ Deteniendo PostgreSQL ($CONTAINER_NAME)..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ PostgreSQL detenido."
        exit 0
        ;;
    --rm|--clean|clean)
        require_non_root
        require_podman
        echo "🗑️ Eliminando contenedor y volumen de datos de PostgreSQL..."
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

echo "ℹ️ Iniciando PostgreSQL 17 en Podman Rootless..."
podman run -d --replace \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    --tz local \
    -e POSTGRES_USER="$PG_USER" \
    -e POSTGRES_PASSWORD="$PG_PASS" \
    -e POSTGRES_DB="$PG_DB" \
    -v "$VOLUME_NAME:/var/lib/postgresql/data:Z" \
    -p "${PG_PORT}:5432" \
    --health-cmd "pg_isready -U $PG_USER -d $PG_DB || exit 1" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 5 \
    --health-start-period 10s \
    "$IMAGE" >/dev/null

echo "✅ PostgreSQL iniciado correctamente:"
echo "   • URI Conexión:    postgresql://${PG_USER}:${PG_PASS}@localhost:${PG_PORT}/${PG_DB}"
echo "   • Host en red:     ${CONTAINER_NAME}:5432 (Red: $NETWORK)"
echo "   • Volumen datos:   ${VOLUME_NAME} (/var/lib/postgresql/data)"
echo "   • Consola psql:    $0 --cli"

if command -v notify-send &>/dev/null && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
    notify-send -a "Podman" -i "server-database" "PostgreSQL Iniciado" \
        "Puerto: localhost:${PG_PORT} | DB: ${PG_DB}\nCredenciales: ${PG_USER} / ${PG_PASS}" 2>/dev/null || true
fi

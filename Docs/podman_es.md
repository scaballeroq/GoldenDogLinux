---
sidebar_position: 8
---

# Gestión de Contenedores con Podman en Debian 13

Esta guía explica de forma sencilla cómo usar **Podman** y la carpeta `Podman/` para levantar bases de datos, paneles web y proyectos completos con **Quadlets** sin complicaciones.

> [!NOTE]
> **¿Qué es Podman y qué son los Quadlets? (Para principiantes)**
> - Un **contenedor** es como una caja aislada donde corre un programa (por ejemplo PostgreSQL o WordPress) sin ensuciar tu sistema.
> - **Podman** es una alternativa moderna y más segura a Docker: funciona **sin demonio central** (*daemonless*) y **sin permisos de root** (*rootless*).
> - Los **Quadlets** permiten que `systemd` (el gestor de servicios de Linux) arranque, detenga y supervise tus contenedores automáticamente como si fueran servicios normales.

---

## 1. Instalación de Podman Rootless y Quadlets (`Podman/install/podman-install.sh`)

Ejecuta `just podman-setup` (o `./Podman/install/podman-install.sh` como usuario normal). El script configura todo automáticamente:

1. **Paquetes del sistema**: Instala solo lo que falte de `podman`, `podman-docker` (traduce el comando `docker` a `podman`), `passt` (red rápida sin root), `netavark`, `aardvark-dns`, `crun`, `catatonit`, `uidmap`, `dbus-user-session`, `slirp4netns`, `fuse-overlayfs` y `podman-compose` (si no hay `compose` instalado).
2. **Almacenamiento y contenedores**:
   - `~/.config/containers/storage.conf`: Usa `overlay` nativo del kernel (`ignore_chown_errors = "true"`).
   - `~/.config/containers/containers.conf`: Configura `crun`, `pasta`, `netavark`, `systemd` y logs en `journald`.
   - `~/.config/containers/registries.conf`: Búsqueda por defecto en `docker.io`, `quay.io` y `ghcr.io`.
3. **Permisos y red**:
   - Activa `loginctl enable-linger "$USER"` para que los contenedores sigan activos al cerrar la terminal.
   - Configura `/etc/subuid` y `/etc/subgid` (`100000-165535`) y añade tu usuario a `render` y `video` (aceleración GPU).
   - Permite puertos sin privilegios desde el puerto `80` (`/etc/sysctl.d/99-podman-ports.conf`) y abre `podman0` en **UFW** si está activo.
4. **Socket y entorno**:
   - Activa `podman.socket` y exporta `DOCKER_HOST="unix:///run/user/<UID>/podman/podman.sock"` en `~/.config/environment.d/10-podman.conf`, `~/.bashrc.d/podman.sh` y `~/.zshrc.d/podman.zsh` (si usas Zsh).
   - Enlaza `~/.local/bin/podman-utils` con autocompletado para Bash y Zsh, y ejecuta `quadlets-setup.sh`.

```bash
just podman-setup   # Instalación completa
just podman-status  # Diagnóstico de Podman + podman-utils doctor
```

---

## 2. Quadlets, Plantillas y CLI `podman-utils`

### Configurar Quadlets (`Podman/install/quadlets-setup.sh`)
```bash
just podman-quadlets                         # Prepara directorios Quadlet y recarga systemd --user
./Podman/install/quadlets-setup.sh --status  # Verifica el generador de Quadlets y unidades activas
./Podman/install/quadlets-setup.sh --install-shared  # Instala todos los servicios de services-shared/
./Podman/install/quadlets-setup.sh --remove-shared   # Detiene y elimina los servicios globales
```

### Servicios compartidos (`Podman/services-shared/`)
Incluye una red `proxy-net` y servicios reutilizables: `traefik` (puertos `80`, `443`, `8080`), `postgres-global` (`5432`, `postgres`/`changeme_dev_123`), `redis-global` (`6379`) y `keycloak` (`8083`, `admin`/`admin`, ruta `/auth`).

### Gestor de proyectos (`podman-utils`)
Las plantillas disponibles en `Podman/templates/` son `python-postgres`, `python-postgres-redis` y `fullstack`:
```bash
podman-utils list-templates                  # Lista plantillas disponibles
podman-utils create python-postgres mi-api   # Crea proyecto en Podman/projects/mi-api y enlaza Quadlets
podman-utils start mi-api                    # Inicia todos los servicios del proyecto (stop / restart)
podman-utils status mi-api                   # Muestra estado systemd y contenedores
podman-utils logs mi-api [servicio]          # Sigue los logs en tiempo real
podman-utils destroy mi-api                  # Detiene, desenlaza y borra el proyecto (pide confirmación)
podman-utils install-global <servicio|all>   # Instala servicios compartidos (ej. traefik, keycloak)
podman-utils uninstall-global <servicio>     # Desinstala un servicio compartido
podman-utils doctor                          # Diagnóstico completo de Podman rootless
```

---

## 3. Catálogo de Contenedores Rápidos (`Podman/scripts-standalone/`)

Todos estos scripts crean automáticamente la red `dev-net`, usan `--replace` y `--restart unless-stopped`, muestran notificaciones en KDE y aceptan las mismas banderas:
- Sin argumentos: inicia/reemplaza el contenedor.
- `--status` (`-s`), `--logs` (`-l`), `--stop`, `--rm` / `--clean` (borra contenedor y volumen), `--help` (`-h`).
- `--open` (`-o`) en servicios con interfaz web, o `--cli` (`-c`) en bases de datos para abrir su consola (`psql`, `mysql`, `mongosh`, `redis-cli`).

### Bases de Datos
* **PostgreSQL** (`podman-postgres.sh`): Puerto `5432` (`POSTGRES_PORT`), `postgres` / `postgres`, BD `postgres`.
* **MySQL 8.4** (`podman-mysql.sh`): Puerto `3306` (`MYSQL_PORT`), `root` / `root`, BD `wordpress`.
* **MongoDB** (`podman-mongodb.sh`): Puerto `27017` (`MONGO_PORT`), sin contraseña inicial.
* **Redis 7** (`podman-redis.sh`): Puerto `6379` (`REDIS_PORT`), persistencia AOF activada.

### Administración, Monitoreo y Trazabilidad
* **Portainer CE** (`podman-portainer.sh`): `https://localhost:9443` (`PORTAINER_PORT`).
* **Adminer** (`podman-adminer.sh`): `http://localhost:8081` (`ADMINER_PORT`).
* **Dozzle** (`podman-dozzle.sh`): `http://localhost:8888` (`DOZZLE_PORT`).
* **Grafana** (`podman-grafana.sh`): `http://localhost:3000` (`GRAFANA_PORT`, `admin` / `admin`).
* **Prometheus** (`podman-prometheus.sh`): `http://localhost:9090` (`PROMETHEUS_PORT`; cambia automáticamente a `9091` si Cockpit usa el `9090`).
* **Jaeger** (`podman-jaeger.sh`): UI en `http://localhost:16686` (`JAEGER_UI_PORT`), OTLP en `4317`/`4318`.

### Infraestructura, Desarrollo y CMS
* **Nginx** (`podman-nginx.sh`): `http://localhost:8082` (`NGINX_PORT`, opcional `NGINX_WEBROOT`).
* **Keycloak 26** (`podman-keycloak.sh`): `http://localhost:8083` (`KEYCLOAK_PORT`, `admin` / `admin`).
* **RabbitMQ** (`podman-rabbitmq.sh`): AMQP `5672`, UI `http://localhost:15672` (`guest` / `guest`).
* **MinIO** (`podman-minio.sh`): API `9000`, Consola `http://localhost:9001` (`minioadmin` / `minioadmin`).
* **MailHog** (`podman-mailhog.sh`): SMTP `1025`, Web `http://localhost:8025`.
* **Browserless** (`podman-browserless.sh`): Puerto `3003` (`BROWSERLESS_PORT`), token `devtoken` (`BROWSERLESS_TOKEN`), usa `/dev/dri` si existe.
* **WordPress** (`podman-wordpress.sh`): `http://localhost:8080` (`WORDPRESS_PORT`), conectado por defecto a `mysql-dev:3306` (`root`/`root`, BD `wordpress`).
* **Storybook** (`podman-storybook.sh`): `http://localhost:6006` (`STORYBOOK_PORT`).

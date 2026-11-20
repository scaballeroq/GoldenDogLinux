---
sidebar_position: 8
---

# Container Management with Podman on Debian 13

This guide explains in plain terms how to use **Podman** and the `Podman/` folder to run databases, web dashboards, and full multi-service projects with **Quadlets**.

> [!NOTE]
> **What are Podman and Quadlets? (Beginner-Friendly Summary)**
> - A **container** is an isolated box where an app (such as PostgreSQL or WordPress) runs without cluttering your OS.
> - **Podman** is a modern, safer alternative to Docker: it runs **daemonless** and **rootless** (no background root daemon required).
> - **Quadlets** let `systemd` (Linux's service manager) start, stop, and monitor your containers just like native system services.

---

## 1. Rootless Podman & Quadlets Setup (`Podman/install/podman-install.sh`)

Run `just podman-setup` (or `./Podman/install/podman-install.sh` as a normal user). It configures everything automatically:

1. **System packages**: Installs any missing packages from `podman`, `podman-docker` (maps `docker` commands to `podman`), `passt` (fast rootless networking), `netavark`, `aardvark-dns`, `crun`, `catatonit`, `uidmap`, `dbus-user-session`, `slirp4netns`, `fuse-overlayfs`, and `podman-compose` (if no compose tool is present).
2. **Storage & runtime defaults**:
   - `~/.config/containers/storage.conf`: Native kernel `overlay` with `ignore_chown_errors = "true"`.
   - `~/.config/containers/containers.conf`: Uses `crun`, `pasta`, `netavark`, `systemd`, and `journald`.
   - `~/.config/containers/registries.conf`: Unqualified search for `docker.io`, `quay.io`, and `ghcr.io`.
3. **Permissions & networking**:
   - Enables `loginctl enable-linger "$USER"` so user containers keep running after you close the terminal.
   - Configures `/etc/subuid` and `/etc/subgid` (`100000-165535`) and adds your user to `render` and `video` (GPU acceleration).
   - Allows unprivileged ports starting at `80` (`/etc/sysctl.d/99-podman-ports.conf`) and allows `podman0` in **UFW** if active.
4. **Socket & shell integration**:
   - Enables `podman.socket` and sets `DOCKER_HOST="unix:///run/user/<UID>/podman/podman.sock"` in `~/.config/environment.d/10-podman.conf`, `~/.bashrc.d/podman.sh`, and `~/.zshrc.d/podman.zsh` (if Zsh is present).
   - Symlinks `~/.local/bin/podman-utils` with Bash/Zsh completions, and runs `quadlets-setup.sh`.

```bash
just podman-setup   # Full setup
just podman-status  # Podman diagnostics + podman-utils doctor
```

---

## 2. Quadlets, Templates & `podman-utils` CLI

### Quadlets Setup (`Podman/install/quadlets-setup.sh`)
```bash
just podman-quadlets                              # Creates Quadlet folders and reloads systemd --user
./Podman/install/quadlets-setup.sh --status       # Checks Quadlet generator and active user units
./Podman/install/quadlets-setup.sh --install-shared  # Installs all services from services-shared/
./Podman/install/quadlets-setup.sh --remove-shared   # Stops and removes global shared services
```

### Shared Services (`Podman/services-shared/`)
Provides the `proxy-net` network and reusable services: `traefik` (ports `80`, `443`, `8080`), `postgres-global` (`5432`, `postgres`/`changeme_dev_123`), `redis-global` (`6379`), and `keycloak` (`8083`, `admin`/`admin`, path `/auth`).

### Project Manager (`podman-utils`)
Available templates in `Podman/templates/` are `python-postgres`, `python-postgres-redis`, and `fullstack`:
```bash
podman-utils list-templates                  # List available templates
podman-utils create python-postgres my-api   # Scaffold Podman/projects/my-api and link Quadlets
podman-utils start my-api                    # Start project services (stop / restart)
podman-utils status my-api                   # Show systemd and container status
podman-utils logs my-api [service]           # Follow live logs
podman-utils destroy my-api                  # Stop, unlink, and delete project (prompts confirmation)
podman-utils install-global <service|all>    # Install shared services (e.g. traefik, keycloak)
podman-utils uninstall-global <service>      # Uninstall a shared service
podman-utils doctor                          # Full rootless Podman diagnostics
```

---

## 3. Standalone Developer Services (`Podman/scripts-standalone/`)

All 18 scripts auto-create the `dev-net` bridge network, use `--replace` and `--restart unless-stopped`, send KDE desktop notifications, and support common flags:
- No args: start/replace container.
- `--status` (`-s`), `--logs` (`-l`), `--stop`, `--rm` / `--clean` (removes container and volume), `--help` (`-h`).
- `--open` (`-o`) for web UIs, or `--cli` (`-c`) on databases to open an interactive shell (`psql`, `mysql`, `mongosh`, `redis-cli`).

### Databases
* **PostgreSQL** (`podman-postgres.sh`): Port `5432` (`POSTGRES_PORT`), `postgres` / `postgres`, DB `postgres`.
* **MySQL 8.4** (`podman-mysql.sh`): Port `3306` (`MYSQL_PORT`), `root` / `root`, DB `wordpress`.
* **MongoDB** (`podman-mongodb.sh`): Port `27017` (`MONGO_PORT`), no initial password.
* **Redis 7** (`podman-redis.sh`): Port `6379` (`REDIS_PORT`), AOF persistence enabled.

### Administration, Monitoring & Tracing
* **Portainer CE** (`podman-portainer.sh`): `https://localhost:9443` (`PORTAINER_PORT`).
* **Adminer** (`podman-adminer.sh`): `http://localhost:8081` (`ADMINER_PORT`).
* **Dozzle** (`podman-dozzle.sh`): `http://localhost:8888` (`DOZZLE_PORT`).
* **Grafana** (`podman-grafana.sh`): `http://localhost:3000` (`GRAFANA_PORT`, `admin` / `admin`).
* **Prometheus** (`podman-prometheus.sh`): `http://localhost:9090` (`PROMETHEUS_PORT`; auto-switches to `9091` if Cockpit uses `9090`).
* **Jaeger** (`podman-jaeger.sh`): UI at `http://localhost:16686` (`JAEGER_UI_PORT`), OTLP `4317`/`4318`.

### Infrastructure, Dev & CMS
* **Nginx** (`podman-nginx.sh`): `http://localhost:8082` (`NGINX_PORT`, optional `NGINX_WEBROOT`).
* **Keycloak 26** (`podman-keycloak.sh`): `http://localhost:8083` (`KEYCLOAK_PORT`, `admin` / `admin`).
* **RabbitMQ** (`podman-rabbitmq.sh`): AMQP `5672`, UI `http://localhost:15672` (`guest` / `guest`).
* **MinIO** (`podman-minio.sh`): API `9000`, Console `http://localhost:9001` (`minioadmin` / `minioadmin`).
* **MailHog** (`podman-mailhog.sh`): SMTP `1025`, Web `http://localhost:8025`.
* **Browserless** (`podman-browserless.sh`): Port `3003` (`BROWSERLESS_PORT`), token `devtoken` (`BROWSERLESS_TOKEN`), uses `/dev/dri` if present.
* **WordPress** (`podman-wordpress.sh`): `http://localhost:8080` (`WORDPRESS_PORT`), connects to `mysql-dev:3306` (`root`/`root`, DB `wordpress`).
* **Storybook** (`podman-storybook.sh`): `http://localhost:6006` (`STORYBOOK_PORT`).

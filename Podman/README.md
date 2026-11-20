# Podman Professional - Quadlets para Desarrollo (Debian Workstation)

Gestión de contenedores con **Podman Rootless + Quadlets + Systemd** para proyectos de desarrollo con proxy, autenticación y servicios compartidos.

---

## 📁 Estructura

```
Podman/
├── install/                  # Scripts de instalación
│   ├── podman-install.sh     # Instala y configura Podman rootless, socket, linger y CLI
│   └── quadlets-setup.sh     # Configura systemd para Quadlets y servicios compartidos
│
├── lib/
│   ├── podman-utils.sh       # CLI para gestionar proyectos y templates
│   ├── podman-utils-completion.bash
│   └── podman-utils-completion.zsh
│
├── templates/                # Plantillas de proyectos
│   ├── python-postgres/      # Python + PostgreSQL
│   ├── python-postgres-redis/# Python + PostgreSQL + Redis
│   └── fullstack/            # Front + Back + PostgreSQL + Traefik + Keycloak
│
├── services-shared/          # Servicios globales reutilizables
│   ├── traefik.container          # Proxy inverso
│   ├── traefik-config.volume      # Volumen de configuración Traefik
│   ├── keycloak.container         # OAuth2/OIDC
│   ├── postgres-global.container  # PostgreSQL compartido
│   ├── postgres-global-data.volume
│   ├── redis-global.container     # Redis compartido
│   ├── redis-global-data.volume
│   └── proxy-net.network          # Red compartida
│
├── scripts-standalone/       # 18 contenedores individuales autónomos (--status, --open/--cli, --logs, --stop, --rm)
└── projects/                 # Proyectos activos de desarrollo (gitignored)
```

---

## 🚀 Instalación y Despliegue

### 1. Instalar y configurar Podman Rootless

```bash
./install/podman-install.sh           # Instala y configura Podman, socket, linger y CLI
./install/podman-install.sh --status  # Diagnóstico del entorno Podman
```

### 2. Configurar Quadlets de Systemd

```bash
./install/quadlets-setup.sh                  # Prepara directorios Quadlet y recarga systemd
./install/quadlets-setup.sh --install-shared # Instala los servicios de services-shared/
./install/quadlets-setup.sh --remove-shared  # Elimina los servicios globales
./install/quadlets-setup.sh --status         # Estado del generador Quadlet y unidades
```

### 3. CLI `podman-utils`

El script crea automáticamente un enlace simbólico en `~/.local/bin/podman-utils` y registra los autocompletados para Bash y Zsh:

```bash
podman-utils doctor
podman-utils help
```

---

## 💡 Uso Rápido

```bash
# Crear proyecto desde plantilla (python-postgres, python-postgres-redis, fullstack)
podman-utils create python-postgres mi-api

# Iniciar, detener o reiniciar servicios del proyecto
podman-utils start mi-api
podman-utils stop mi-api
podman-utils restart mi-api

# Estado, logs o eliminar proyecto
podman-utils status mi-api
podman-utils logs mi-api
podman-utils destroy mi-api

# Instalar/desinstalar servicios compartidos
podman-utils install-global traefik
podman-utils uninstall-global traefik
```

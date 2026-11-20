# 🚀 Bash.Setup - Golden Dog Linux (Debian 13 KDE Plasma)

Colección de scripts de configuración modular y funciones avanzadas para potenciar la terminal Bash y Zsh en **Golden Dog Linux** (basado en **Debian 13 Trixie** con **KDE Plasma** sobre **Wayland**).

Este directorio organiza de forma modular los alias, variables de entorno, utilidades multimedia, gestores de contenedores (Podman) y atajos de escritorio sin dependencias de entornos heredados.

---

## 📁 Estructura del Módulo

| Archivo | Descripción |
| :--- | :--- |
| `aliases.sh` | Atajos de navegación, Git, `apt`, `ufw`, hardware, `virsh` (KVM), Podman, seguridad (`rm -i`) e integración con herramientas modernas (`eza`/`lsd`, `bat`, `duf`, `dust`, `procs`, `btop`/`btm`, `fastfetch`) y `check-kernel-update`. |
| `environment.sh` | Variables globales (`EDITOR`, `PATH`, Wayland, integración Qt/KDE, `DOCKER_HOST`, `LIBVIRT_DEFAULT_URI`) y activación automática de Mise. |
| `functions.sh` | Utilidades multimedia (FFmpeg / ImageMagick), gestión de discos (`format-drive`, `iso2sd`), descompresión/compresión (`extract`, `compress`), copias (`backup`) y navegación avanzada. |
| `kde_settings.sh` | Atajos funcionales para KDE Plasma (accesos directos a `systemsettings`, Dolphin, Kate/KWrite, Plasma System Monitor, KCalc y portapapeles Wayland) sin alterar la apariencia visual. |
| `history.sh` | Configuración optimizada del historial (10k/20k comandos en Bash con marcas de tiempo, compartición y deduplicación inmediata en Zsh). |
| `options.sh` | Comportamiento avanzado de shell (`autocd`, corrección de typos con `cdspell`, globbing extendido y completado insensible a mayúsculas). |
| `podman-functions.sh` | Funciones y atajos para contenedores Podman y unidades Quadlets rootless de systemd. |
| `rclone_aliases.sh` | Suite integral de sincronización, respaldo y descarga para Google Drive y OneDrive con Rclone. |
| `yt-dlp_aliases.sh` | Descargas multimedia de alto rendimiento con yt-dlp y FFmpeg. |

---

## 🛠️ Instalación e Integración

Para activar todas estas funcionalidades de forma modular, ejecuta `./Setup/shell.sh`, el cual enlazará automáticamente estos scripts en `~/.bashrc.d/` (y en `~/.zshrc.d/` si existe Zsh):

```bash
mkdir -p ~/.bashrc.d
ln -sf ~/Workspace/Repositorios/GoldenDogLinux/Bash.Setup/*.sh ~/.bashrc.d/
```

Y añade el cargador modular a tu `~/.bashrc`:

```bash
if [ -d "$HOME/.bashrc.d" ]; then
    for script in "$HOME/.bashrc.d"/*.sh; do
        [ -r "$script" ] && source "$script"
    done
    unset script
fi
```

---

## 🛡️ Seguridad y Cortafuegos
- **UFW Nativo:** Todos los atajos de firewall (`fw`, `fw-status`, `fw-numbered`, `fw-reload`, `fw-allow`, `fw-deny`) operan con `ufw`, preinstalado y configurado en Golden Dog Linux.
- **Protección de Archivos:** Operaciones interactivas por defecto (`rm -i`, `cp -i`, `mv -i`, `ln -i`, `chown/chmod/chgrp --preserve-root`).

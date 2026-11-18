# 🐕 Golden Dog Linux Environment Configuration (Debian 13 KDE Plasma)

Este repositorio contiene una colección organizada, modular y automatizada de scripts de configuración para **Golden Dog Linux** (<https://goldendoglinux.org/>), una distribución minimalista basada en **Debian GNU/Linux 13 (Trixie)** con **KDE Plasma (Wayland)**, que incluye **Cockpit** y **UFW** preinstalados y configurados.

> [!IMPORTANT]
> **Apariencia de KDE intacta:** Golden Dog Linux trae una personalización visual propia muy cuidada. Ninguno de los scripts de este repositorio modifica temas globales, colores, iconos, cursores, paneles, fondos de pantalla ni decoraciones de ventana de KDE Plasma.

---

## 📂 Organización del Repositorio

### 🐚 [Bash.Setup](./Bash.Setup/)
Configuración modular para **Bash** (`~/.bashrc.d`) y **Zsh** (`~/.zshrc.d`):
- **`aliases.sh`**: Atajos de navegación, utilidades modernas (`eza`, `bat`, `duf`, `dust`), Git, **APT**, **UFW** (`fw*`), Libvirt y Podman.
- **`environment.sh`**: Variables globales (`EDITOR`, `PATH`, Wayland, `QT_QPA_PLATFORMTHEME="kde"`, `ELECTRON_OZONE_PLATFORM_HINT="auto"`, `DOCKER_HOST`, `LIBVIRT_DEFAULT_URI`) y Mise shims.
- **`functions.sh`**: Colección de funciones avanzadas (`mkcd`, `up`, `extract`, `duh`, `backup_file`, `monitors`).
- **`kde_settings.sh`**: Atajos funcionales para KDE Plasma (`systemsettings`, Dolphin, Kate, Plasma System Monitor, portapapeles Wayland) sin alterar la apariencia visual.
- **`history.sh`**, **`options.sh`**, **`podman-functions.sh`**, **`rclone_aliases.sh`**, **`yt-dlp_aliases.sh`**.

### 🐳 [Podman](./Podman/)
Ecosistema de contenedores rootless con Quadlets nativos de systemd (`podman-install.sh`, `quadlets-setup.sh`, `podman-utils.sh`, `services-shared/`, `templates/`).

### 🖥️ [Virtualizacion](./Virtualizacion/)
- **`virtualization.sh`**: Configuración de KVM/QEMU, Libvirt, virt-manager, Polkit sin contraseña para el grupo `libvirt`, backend nftables y reglas UFW (`virbr0` y Cockpit).

### ⚙️ [Setup](./Setup/)
Scripts de configuración del sistema, optimización funcional y endurecimiento:
- **`post-install.sh`**, **`post-install-amd.sh`**, **`post-install-intel.sh`**: Despachador por CPU, firmware, Mesa/Vulkan/VA-API, PipeWire y soporte Flatpak en KDE Discover (`plasma-discover-backend-flatpak`).
- **`kde-settings.sh`**: Mejoras **únicamente funcionales** para KDE Plasma 6 (Dolphin en modo detallado con miniaturas multimedia, servicemenus KIO para Kitty y Antigravity, atajo `Ctrl+Alt+T`).
- **`kdeconnect.sh`**: Integración de KDE Connect + `sshfs` (Dolphin) y reglas de UFW (`1714:1764` TCP/UDP).
- **`cockpit.sh`**: Verificación y ampliación modular de Cockpit (`cockpit-podman`, `cockpit-machines`, `cockpit-storaged`, `cockpit-files`, `IdleTimeout=15`) y regla UFW (`9090/tcp`).
- **`seguridad.sh`**: Configuración de **UFW** nativo (Cockpit, KDE Connect, mDNS, Podman, KVM, `--dev-ports`) y parámetros `sysctl` para contenedores rootless y virtualización.
- **`debian-tuning.sh`**: `sysctl` (inotify, `max_map_count`, TCP BBR), límites `nofile`, ZRAM y exclusiones de desarrollo en **KDE Baloo**.
- **`laptop-setup.sh`**: `power-profiles-daemon`, Bluetooth `FastConnectable`, cierre de tapa en `systemd-logind`, desplazamiento natural en KWin Wayland y perfiles PowerDevil.
- **`hp-printer-setup.sh`**: Pila de impresión CUPS/HPLIP y reglas UFW (`631/tcp`, `5353/udp`).
- **`kitty.sh`** & **`ghostty.sh`**: Terminales aceleradas por GPU con integración en KDE (`kglobalshortcutsrc`) y Dolphin (`servicemenus`).
- **`multimedia.sh`** & **`flatpak.sh`**: Códecs, VA-API, reproductores KDE (`gwenview`, `haruna`/`mpv`, `vlc`) y apps Flatpak con `xdg-desktop-portal-kde`.
- **`chrome.sh`**, **`firefox.sh`**, **`steam.sh`**, **`shell.sh`**, **`zsh-setup.sh`**, **`starship.sh`**, **`fonts.sh`**, **`fastfetch.sh`**, **`fingerprint-setup.sh`**, **`zram-setup.sh`**, **`yt-dlp-setup.sh`**, **`amd64v3.sh`**.

### 📦 [ProgrammingLanguages](./ProgrammingLanguages/) & 💻 [IDE](./IDE/)
Runtimes aislados con `mise` y `uv` (`python.sh`, `nodejs.sh`, `rust.sh`, `java.sh`, etc.) y herramientas de desarrollo (`git.sh`, `antigravity.sh`, `antigravity-cli.sh`, `antigravity-ide.sh`, `opencode.sh`).

---

## ⚡ Automatización mediante Justfile

```bash
# Instalación completa desatendida del entorno
just setup-all

# Perfil específico para Portátil AMD Ryzen
just setup-laptop-amd

# Diagnóstico integral
just status
just security-status
just cockpit-status
just kde-status
just kdeconnect-status
```

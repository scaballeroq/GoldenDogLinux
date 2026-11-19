---
sidebar_position: 9
---

# Aplicaciones Desacopladas (Flatpak) en Golden Dog Linux (Debian 13)

Esta guía detalla la instalación y gestión de aplicaciones de escritorio aisladas mediante [`Setup/flatpak.sh`](../Setup/flatpak.sh), manteniendo el sistema base **Golden Dog Linux (Debian 13 Trixie)** 100% limpio y estable.

---

## 1. Arquitectura Desacoplada con Flatpak y KDE Discover

El script [`Setup/flatpak.sh`](../Setup/flatpak.sh) configura **Flatpak**, el backend **`plasma-discover-backend-flatpak`** para **KDE Discover**, los portales **`xdg-desktop-portal-kde`** y el repositorio oficial **Flathub**, además de sincronizar la aceleración gráfica por hardware (`--device=dri`) y el tema GTK del usuario.

---

## 2. Catálogo de Aplicaciones por Categorías

* **Core / Gestión (`--core`)**:
  - **Flatseal** (`com.github.tchx84.Flatseal`): Gestor gráfico de permisos y sandbox.
  - **Warehouse** (`io.github.flattool.Warehouse`): Gestión avanzada de Flatpaks y runtimes.
  - **Podman Desktop** (`io.podman_desktop.PodmanDesktop`): Panel gráfico para contenedores Podman.
* **Multimedia (`--multimedia`)**:
  - **VLC**, **Celluloid**, **OBS Studio**, **Kdenlive**, **Shotcut**, **Kodi**, **Stremio**, **Audacity**, **Spotify**.
* **Comunicación (`--comms`)**:
  - **Vesktop (Discord Wayland)**, **Telegram Desktop**.
* **Desarrollo (`--dev`)**:
  - **Bruno (API Client)**, **DBeaver Community**.
* **Productividad (`--productivity`)**:
  - **LibreOffice**, **Obsidian**, **LocalSend**, **Pika Backup**.
* **Diseño Gráfico (`--graphics`)**:
  - **GIMP**, **Inkscape**.

---

## 3. Comandos con Just y CLI

```bash
just flatpak                       # Instala las aplicaciones esenciales por defecto
just flatpak-status                # Muestra el catálogo y estado de aplicaciones instaladas
just flatpak-update                # Actualiza todas las aplicaciones y runtimes Flatpak
just flatpak-clean                 # Elimina runtimes huérfanos no utilizados

# Instalación por categoría o individual
./Setup/flatpak.sh --multimedia    # Instala la suite multimedia
./Setup/flatpak.sh --dev           # Instala Bruno y DBeaver
./Setup/flatpak.sh install vlc     # Instala una aplicación individual por alias o ID
```

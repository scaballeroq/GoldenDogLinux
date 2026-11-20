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

* **Perfil por defecto (sin argumentos / `just flatpak`)**:
  - **Flatseal** (`com.github.tchx84.Flatseal`): Gestor gráfico de permisos y sandbox.
  - **Warehouse** (`io.github.flattool.Warehouse`): Gestión avanzada de Flatpaks y runtimes.
* **Core / Gestión (`--core` o `--essential`)**:
  - Incluye **Flatseal**, **Warehouse** y **Podman Desktop** (`io.podman_desktop.PodmanDesktop`).
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
* **Web (`--web`)**:
  - **Mozilla Firefox** (`org.mozilla.firefox`).

---

## 3. Comandos con Just y CLI

```bash
just flatpak                       # Instala el perfil por defecto (Flatseal y Warehouse)
just flatpak-status                # Muestra el catálogo y estado de aplicaciones instaladas
just flatpak-update                # Actualiza todas las aplicaciones y runtimes Flatpak
just flatpak-clean                 # Elimina runtimes huérfanos no utilizados

# Instalación por categoría, completa o individual
./Setup/flatpak.sh --core          # Instala Flatseal, Warehouse y Podman Desktop
./Setup/flatpak.sh --multimedia    # Instala la suite multimedia
./Setup/flatpak.sh --dev           # Instala Bruno y DBeaver
./Setup/flatpak.sh --web           # Instala Mozilla Firefox en Flatpak
./Setup/flatpak.sh --all           # Instala las 22 aplicaciones del catálogo
./Setup/flatpak.sh --overrides     # Aplica solo los permisos GTK/DRI recomendados
./Setup/flatpak.sh install vlc     # Instala una aplicación individual por alias o ID
./Setup/flatpak.sh --user --multimedia  # Instala en espacio de usuario (sin sudo)
```

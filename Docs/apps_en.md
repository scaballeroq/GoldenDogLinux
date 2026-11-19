---
sidebar_position: 9
---

# Decoupled Applications (Flatpak) on Golden Dog Linux (Debian 13)

This guide details the installation and management of sandboxed desktop applications via [`Setup/flatpak.sh`](../Setup/flatpak.sh), keeping the base **Golden Dog Linux (Debian 13 Trixie)** system 100% clean and pure.

---

## 1. Decoupled Architecture with Flatpak & KDE Discover

The [`Setup/flatpak.sh`](../Setup/flatpak.sh) script configures **Flatpak**, **`plasma-discover-backend-flatpak`** for **KDE Discover**, **`xdg-desktop-portal-kde`**, and the official **Flathub** remote, while applying GPU acceleration (`--device=dri`) and user GTK theme overrides.

---

## 2. Application Catalog by Category

* **Core / System (`--core`)**:
  - **Flatseal** (`com.github.tchx84.Flatseal`): Graphical permissions and sandbox manager.
  - **Warehouse** (`io.github.flattool.Warehouse`): Versatile Flatpak and runtime manager.
  - **Podman Desktop** (`io.podman_desktop.PodmanDesktop`): Graphical dashboard for Podman containers.
* **Multimedia (`--multimedia`)**:
  - **VLC**, **Celluloid**, **OBS Studio**, **Kdenlive**, **Shotcut**, **Kodi**, **Stremio**, **Audacity**, **Spotify**.
* **Communication (`--comms`)**:
  - **Vesktop (Wayland Discord)**, **Telegram Desktop**.
* **Development (`--dev`)**:
  - **Bruno (API Client)**, **DBeaver Community**.
* **Productivity (`--productivity`)**:
  - **LibreOffice**, **Obsidian**, **LocalSend**, **Pika Backup**.
* **Graphics (`--graphics`)**:
  - **GIMP**, **Inkscape**.

---

## 3. Commands with Just & CLI

```bash
just flatpak                       # Install default essential applications
just flatpak-status                # Display catalog and installation status
just flatpak-update                # Update all Flatpak applications and runtimes
just flatpak-clean                 # Remove unused orphan runtimes

# Category or single-app installation
./Setup/flatpak.sh --multimedia    # Install the multimedia suite
./Setup/flatpak.sh --dev           # Install Bruno and DBeaver
./Setup/flatpak.sh install vlc     # Install a single app by alias or Flatpak ID
```

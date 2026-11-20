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

* **Default Profile (no arguments / `just flatpak`)**:
  - **Flatseal** (`com.github.tchx84.Flatseal`): Graphical permissions and sandbox manager.
  - **Warehouse** (`io.github.flattool.Warehouse`): Versatile Flatpak and runtime manager.
* **Core / System (`--core` or `--essential`)**:
  - Includes **Flatseal**, **Warehouse**, and **Podman Desktop** (`io.podman_desktop.PodmanDesktop`).
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
* **Web (`--web`)**:
  - **Mozilla Firefox** (`org.mozilla.firefox`).

---

## 3. Commands with Just & CLI

```bash
just flatpak                       # Install default profile (Flatseal & Warehouse)
just flatpak-status                # Display catalog and installation status
just flatpak-update                # Update all Flatpak applications and runtimes
just flatpak-clean                 # Remove unused orphan runtimes

# Category, full, or single-app installation
./Setup/flatpak.sh --core          # Install Flatseal, Warehouse, and Podman Desktop
./Setup/flatpak.sh --multimedia    # Install the multimedia suite
./Setup/flatpak.sh --dev           # Install Bruno and DBeaver
./Setup/flatpak.sh --web           # Install Mozilla Firefox Flatpak
./Setup/flatpak.sh --all           # Install all 22 catalog applications
./Setup/flatpak.sh --overrides     # Apply GTK/DRI user overrides only
./Setup/flatpak.sh install vlc     # Install a single app by alias or Flatpak ID
./Setup/flatpak.sh --user --multimedia  # Install in user scope (no sudo)
```

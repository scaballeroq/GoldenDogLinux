# 🐕 Golden Dog Linux Environment Configuration (Debian 13 KDE Plasma)

This repository contains a modular, automated set of configuration scripts for **Golden Dog Linux** (<https://goldendoglinux.org/>), a minimalist distribution based on **Debian GNU/Linux 13 (Trixie)** with **KDE Plasma (Wayland)**, featuring **Cockpit** and **UFW** pre-installed and configured.

> [!IMPORTANT]
> **KDE appearance preserved:** Golden Dog Linux ships with a polished custom KDE visual setup. None of the scripts in this repository modify KDE global themes, color schemes, icons, cursors, panels, wallpapers, or window decorations.

---

## 📂 Repository Structure

- **[Bash.Setup](./Bash.Setup/)**: Modular shell configuration for Bash (`~/.bashrc.d`) and Zsh (`~/.zshrc.d`), including UFW aliases (`fw*`), `QT_QPA_PLATFORMTHEME="kde"`, and functional KDE helpers (`kde_settings.sh`).
- **[Setup](./Setup/)**: System setup scripts adapted for KDE Plasma 6 and UFW:
  - `post-install.sh`, `post-install-amd.sh`, `post-install-intel.sh` (with `plasma-discover-backend-flatpak`).
  - `kde-settings.sh` (functional-only: Dolphin detailed view & thumbnails, KIO servicemenus, `Ctrl+Alt+T` — zero visual theme changes).
  - `kdeconnect.sh`, `cockpit.sh`, `seguridad.sh`, `hp-printer-setup.sh` (all integrated with native **UFW**).
  - `debian-tuning.sh` (sysctl, limits, ZRAM, **KDE Baloo** exclusions), `laptop-setup.sh` (KWin Wayland touchpad & PowerDevil), `kitty.sh`, `ghostty.sh`, `multimedia.sh`, `flatpak.sh`, `chrome.sh`, `firefox.sh`, `steam.sh`, `shell.sh`, `zsh-setup.sh`, `starship.sh`, `fonts.sh`, `fastfetch.sh`, `fingerprint-setup.sh`, `zram-setup.sh`, `yt-dlp-setup.sh`, `amd64v3.sh`.
- **[Podman](./Podman/)**: Rootless Podman & systemd Quadlets setup.
- **[Virtualizacion](./Virtualizacion/)**: KVM/QEMU, Libvirt, Virt-Manager, and UFW integration.
- **[ProgrammingLanguages](./ProgrammingLanguages/)** & **[IDE](./IDE/)**: `mise`, `uv`, `git`, Antigravity, OpenCode.

---

## ⚡ Quick Start with Justfile

```bash
just setup-all
just status
just security-status
just cockpit-status
just kde-status
```

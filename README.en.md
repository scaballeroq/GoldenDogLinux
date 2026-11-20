# 🐕 Golden Dog Linux — Environment Configuration (Debian 13 KDE Plasma)

This repository provides an organized, modular, and automated collection of scripts to set up **Golden Dog Linux** (<https://goldendoglinux.org/>), a minimalist distribution based on **Debian GNU/Linux 13 (Trixie)** with **KDE Plasma (Wayland)**, featuring **Cockpit** and **UFW** pre-installed and configured.

> [!TIP]
> **New to Linux or looking for a simple, jargon-free walkthrough?**
> 👉 **[Read the Beginner-Friendly Step-by-Step Guide (`Docs/quick_guide_en.md`)](./Docs/quick_guide_en.md)**.
> *(Versión en español disponible en [`README.md`](./README.md) y [`Docs/guia_rapida_es.md`](./Docs/guia_rapida_es.md)).*

> [!IMPORTANT]
> **100% KDE appearance preserved:** Golden Dog Linux ships with a carefully crafted custom KDE visual setup. None of the scripts in this repository modify KDE global themes, color schemes, icons, cursors, panels, wallpapers, or window decorations.

---

## 🚀 3-Step Quick Start (For Everyone)

If you just installed **Golden Dog Linux** on any desktop or laptop with an **AMD** or **Intel** processor *(dedicated Nvidia GPUs excluded)*:

### 1. Open the terminal and install `git` and `just`
```bash
sudo apt update && sudo apt install -y git just
```

### 2. Download this project
```bash
mkdir -p ~/Workspace/Repositorios
cd ~/Workspace/Repositorios
git clone https://github.com/GoldendogLinux/GoldenDogLinux.git
cd GoldenDogLinux
```

### 3. Run the automated setup (or pick only what you need)

```bash
# Option A: Set up EVERYTHING automatically (auto-detects AMD or Intel hardware)
just setup-all

# Option B: Set up only base system + multimedia + desktop apps (skips developer tools)
just post-install multimedia flatpak chrome kde-setup tuning security
```

When finished, **restart your computer** and enjoy!

---

## 🎯 What Does Each Command Do? (Cheat Sheet)

| Easy Command | What is it for? | Check its status |
| :--- | :--- | :--- |
| `just post-install` | Installs **AMD** or **Intel** drivers, microcode, **PipeWire** audio, **ZRAM**, and **Flatpak** support in KDE Discover. | `just amd-status` / `just intel-status` |
| `just multimedia` | Installs all audio/video codecs (**FFmpeg**, **GStreamer**), **VA-API** GPU acceleration, and video thumbnails in Dolphin. | `just multimedia-status` |
| `just kde-setup` | Enhances **Dolphin** (detailed view & media thumbnails), adds `Ctrl+Alt+T`, and right-click actions (**leaves visual theme intact**). | `just kde-status` |
| `just flatpak` | Connects **Flathub** and installs core helpers (**Flatseal**, **Warehouse**) so you can install apps like VLC, Spotify, or LibreOffice. | `just flatpak-status` |
| `just chrome` | Installs the official **Google Chrome** browser with Wayland video acceleration. | `just chrome-status` |
| `just firefox` | Installs the official **Mozilla Firefox** browser (native `.deb`). | `just firefox-status` |
| `just tuning` | Speeds up the system: 50% **ZRAM** swap, **TCP BBR** networking, fast shutdowns, and heavy-folder exclusions in **KDE Baloo**. | `just tuning-status` |
| `just security` | Configures the native **UFW** firewall for **Cockpit** (`9090`), **KDE Connect**, **Podman** containers, and **KVM** virtual machines. | `just security-status` |
| `just cockpit` | Optimizes the preinstalled **Cockpit** web console (`https://localhost:9090`), adds extra modules (`podman`, `files`, `sosreport`), and enables idle timeout (`IdleTimeout=15`). | `just cockpit-status` |
| `just shell` | Installs modern CLI tools (`eza`, `bat`, `fzf`, `zoxide`, `btop`, `ripgrep`) and enables `Bash.Setup` shortcuts. | `just shell-status` |
| `just zsh` | *(Optional)* Configures modular **Zsh** (`~/.zshrc.d`) with Powerline styling, syntax highlighting, and autosuggestions (`just zsh-default` to switch). | `just zsh-status` |
| `just kitty` | Installs and configures the GPU-accelerated **Kitty** terminal with Wayland blur and Catppuccin Mocha palette. | `just kitty-status` |
| `just fonts` | Installs **Nerd Fonts** (`JetBrainsMono`, `FiraCode`, `CascadiaCode`, `Meslo`, `Hack`) for terminal icons. | `just fonts-status` |
| `just fastfetch` | Configures the visual system summary (**Fastfetch** — type `ff` in the terminal to see it). | `just fastfetch-status` |
| `just languages` | *(For developers)* Installs **Mise**, **Node.js LTS**, **Python + uv**, **Rust**, and **OpenJDK 21**. | `just languages-status` |
| `just git-setup` | *(For developers)* Installs and configures **Git**, **Git-Delta**, **Lazygit**, and **GitHub CLI (`gh`)**. | `just git-status` |
| `just ides` | *(For developers)* Installs **Google Antigravity Desktop 2.0**, **Antigravity CLI (`agy`)**, **Antigravity IDE**, and **OpenCode AI**. | `just ides-status` |
| `just podman-setup` | *(For developers)* Configures **Rootless Podman** containers and systemd **Quadlets**. | `just podman-status` |
| `just virtualization` | *(Advanced)* Configures **KVM/QEMU** virtual machines with **Virt-Manager** and **Cockpit Machines**. | `just virtualization-status` |

---

## 📚 Documentation Index (`Docs/`)

1. 🌟 **[Beginner-Friendly Step-by-Step Guide](./Docs/quick_guide_en.md)** | *[Guía Fácil Paso a Paso (ES)](./Docs/guia_rapida_es.md)*
2. ⚙️ **[System, KDE & Multimedia Setup](./Docs/setup_en.md)** | *[Configuración del Sistema (ES)](./Docs/setup_es.md)*
3. 🛡️ **[Security & UFW Firewall](./Docs/seguridad_en.md)** | *[Seguridad y UFW (ES)](./Docs/seguridad_es.md)*
4. 📦 **[Desktop Applications (Flatpak / Flathub)](./Docs/apps_en.md)** | *[Aplicaciones Flatpak (ES)](./Docs/apps_es.md)*
5. 🐚 **[Terminal, Shortcuts & Functions (`Bash.Setup`)](./Docs/bash_en.md)** | *[Terminal y Atajos (ES)](./Docs/bash_es.md)*
6. 🐙 **[Version Control (Git, Delta, Lazygit, GitHub CLI)](./Docs/git_en.md)** | *[Git (ES)](./Docs/git_es.md)*
7. 💻 **[IDEs & AI Tools (Antigravity & OpenCode)](./Docs/ide_en.md)** | *[IDEs e IA (ES)](./Docs/ide_es.md)*
8. 🐍 **[Programming Languages (Mise, Node, Python, Rust, Java)](./Docs/languages_en.md)** | *[Lenguajes (ES)](./Docs/languages_es.md)*
9. 🐳 **[Rootless Podman Containers & Quadlets](./Docs/podman_en.md)** | *[Contenedores Podman (ES)](./Docs/podman_es.md)*
10. 🖥️ **[KVM/QEMU Virtualization with Virt-Manager & Cockpit](./Docs/virtualization_en.md)** | *[Virtualización KVM (ES)](./Docs/virtualizacion_es.md)*

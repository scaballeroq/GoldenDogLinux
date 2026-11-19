---
sidebar_position: 2
---

# System Configuration in Debian GNU/Linux (KDE Plasma 6 Wayland)

This guide details the base system setup, terminal optimization, essential tooling, multimedia support, and desktop personalization applied to a **Debian GNU/Linux** workstation with **KDE Plasma 6**.

Configurations are automated via scripts in the `Setup/` folder and orchestrated with the `justfile`.

---

## 1. Base Post-Installation (`post-install.sh`)

Prepares the base system by detecting host CPU/GPU architecture (any **AMD** or **Intel** desktop or laptop; **Nvidia GPUs excluded**) and executing the tailored installer:
- **`post-install-amd.sh`** + **`amd-setup.sh`**: For AMD CPUs and GPUs (microcode, AMD firmware, Mesa RADV, VA-API `radeonsi`, PipeWire, ZRAM, Flatpak Flathub).
- **`post-install-intel.sh`** + **`intel-setup.sh`**: For Intel CPUs and GPUs (Intel microcode, `iHD`/`i965` VA-API, Mesa ANV Vulkan, PipeWire, ZRAM, Flatpak Flathub).

Command:
```bash
just post-install
```

---

## 2. Terminal Environment & Shell (`shell.sh`, `fastfetch.sh`, `fonts.sh`, and `kitty.sh`)

Installs modern console utilities, developer typefaces, Starship prompt, and the GPU-accelerated Kitty terminal emulator.

### Modern Terminal Utilities
- `eza` (modern `ls` replacement with git integration and glyphs)
- `bat` (syntax-highlighted `cat` replacement via `batcat`)
- `fzf` (interactive fuzzy finder for Ctrl+R, Ctrl+T, Alt+C)
- `zoxide` (smart `cd` directory jumping)
- `ripgrep` (`rg`, blazing fast text search)
- `fd-find` (`fd`, user-friendly file search)
- `duf` & `du-dust` (modern disk usage visualization)
- `procs` (modern `ps` replacement)
- `btop` (resource monitor)

### Kitty Terminal (GPU-Accelerated)
Configured with:
- 75% background opacity and background blur (*blur 32*) accelerated by Mesa RADV GPU.
- Catppuccin Mocha color scheme (#181825).
- JetBrainsMono Nerd Font.
- Global `Ctrl+Alt+T` keybinding in KDE Plasma 6.
- Dolphin context menu (KIO ServiceMenu: "Open in Kitty").

### Developer Fonts (Nerd Fonts)
Automated installation of:
`JetBrainsMono`, `FiraCode`, `CascadiaCode`, `Meslo`, and `Hack`.

### Fastfetch
Aesthetic hardware and system banner supporting official Debian theme (`debian`) and minimalist mode (`compact`).

---

## 3. Functional KDE Plasma 6 Desktop (`kde-settings.sh`)

> [!IMPORTANT]
> **Golden Dog Linux appearance preserved:** `kde-settings.sh` never alters global themes, color schemes, icons, cursors, panels, or window decorations.

- **KDE Gear Packages**: Installs official utilities (`dolphin`, `kate`, `spectacle`, `okular`, `gwenview`, `ark`, `kio-extras`, `dolphin-plugins`, `ffmpegthumbs`, `wl-clipboard`).
- **Optimized Dolphin**: Detailed view mode enabled by default with multimedia thumbnail previews.
- **Global `Ctrl+Alt+T` Shortcut**: Launches your preferred terminal (`kitty` or `konsole`).
- **Dolphin ServiceMenus**: Right-click context actions for **Kitty**, **Google Antigravity**, and **Antigravity IDE**.

---

## 4. Browsers & Decoupled Software

- **Google Chrome** (`chrome.sh`): Official Google repository with Ozone Wayland flags (`--ozone-platform-hint=auto` and VA-API hardware acceleration).
- **Mozilla Firefox** (`firefox.sh`): Native `.deb` package from Mozilla with APT Pin-Priority 1000, replacing Firefox ESR.
- **Flatpak** (`flatpak.sh`): Modular catalog integrated with KDE Discover (Flatseal, Podman Desktop, Warehouse, VLC, Celluloid, OBS Studio, Kdenlive, Shotcut, Kodi, Stremio, Audacity, Spotify, Vesktop, Telegram, Bruno, DBeaver, LibreOffice, Obsidian, LocalSend, Pika Backup, GIMP, Inkscape).
- **Cockpit Web Console** (`cockpit.sh`): On-demand activation via `cockpit.socket` on port `9090` with Podman, KVM Machines, Storage, and NetworkManager modules.

---

## 5. Summary of Commands with Just

```bash
just post-install        # Smart post-install dispatcher (AMD / Intel)
just kde-setup           # Functional KDE Plasma 6 setup (preserves visual theme)
just kde-status          # Show KDE Plasma 6 functional status
just tuning              # Kernel sysctl, limits, Baloo exclusions, and ZRAM
just shell               # Install modern CLI tools and link Bash.Setup
just zsh                 # Configure modular Zsh environment
just starship            # Install and enable Starship prompt
just kitty               # Configure GPU-accelerated Kitty terminal
just fonts               # Install Nerd Fonts
just fastfetch           # Configure Fastfetch banner
just multimedia          # Install GStreamer/FFmpeg codecs and VA-API acceleration
just flatpak             # Install Flatpak applications
just chrome              # Install official Google Chrome
just firefox             # Install native Firefox (.deb)
just cockpit             # Configure Cockpit Web Console
```

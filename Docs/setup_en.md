---
sidebar_position: 2
---

# System Configuration in Debian GNU/Linux (KDE Plasma 6 Wayland)

This guide details the base system setup, terminal optimization, essential tooling, multimedia support, and desktop personalization applied to a **Debian GNU/Linux** workstation with **KDE Plasma 6**.

Configurations are automated via scripts in the `Setup/` folder and orchestrated with the `justfile`.

---

## 1. Base Post-Installation (`post-install.sh`)

Prepares the base system by detecting host CPU/GPU architecture (any **AMD** or **Intel** desktop or laptop; **Nvidia GPUs excluded**) and executing the tailored installer:
- **`post-install-amd.sh`** + **`amd-setup.sh`**: For AMD CPUs and GPUs (microcode, AMD firmware, Mesa RADV, VA-API `radeonsi`, FFmpeg/GStreamer codecs, PipeWire, ZRAM, and Flatpak Discover backend).
- **`post-install-intel.sh`** + **`intel-setup.sh`**: For Intel CPUs and GPUs (Intel microcode, `iHD`/`i965` VA-API, Mesa ANV Vulkan, FFmpeg/GStreamer codecs, PipeWire, ZRAM, and Flatpak Discover backend).

> [!NOTE]
> `post-install` installs `flatpak` and the KDE Discover backend; the **Flathub** remote is added afterward by `just flatpak` or `just multimedia`. **Rebooting** after completion is recommended.

Commands:
```bash
just post-install          # Auto-detects AMD or Intel (also accepts --amd / --intel)
just amd-setup --status    # AMD hardware/driver diagnostics (or intel-status)
just zram-status           # Check ZRAM compressed swap (50% RAM with ZSTD)
```

---

## 2. Terminal Environment & Shell (`shell.sh`, `zsh-setup.sh`, `starship.sh`, `fastfetch.sh`, `fonts.sh`, and `kitty.sh`)

Installs modern console utilities, developer typefaces, optional Zsh, Starship prompt, and the GPU-accelerated Kitty terminal emulator.

### Modern Terminal Utilities (`shell.sh` and `zsh-setup.sh`)
- `eza` (modern `ls` replacement with git integration and glyphs)
- `bat` (syntax-highlighted `cat` replacement via `batcat`)
- `fzf` (interactive fuzzy finder for Ctrl+R, Ctrl+T, Alt+C)
- `zoxide` (smart `cd` directory jumping)
- `ripgrep` (`rg`, blazing fast text search)
- `fd-find` (`fd`, user-friendly file search)
- `duf` & `du-dust` (modern disk usage visualization)
- `procs` (modern `ps` replacement)
- `btop` (resource monitor)
- `curl`, `git`, and `jq` (networking and JSON helpers)

If you want to use **Zsh** instead of Bash, `just zsh` sets up `~/.zshrc` with Powerline styling, syntax highlighting, and autosuggestions (and `just zsh-default` sets it as your login shell). For **Starship**, run `./Setup/starship.sh` once to install the binary, then use `just starship` / `just starship-disable` to toggle it.

### Kitty Terminal (GPU-Accelerated)
Configured with:
- 75% background opacity and background blur (*blur 32*) accelerated by Mesa GPU drivers (AMD/Intel).
- Catppuccin Mocha color scheme (`#181825`).
- JetBrainsMono Nerd Font.
- Global `Ctrl+Alt+T` keybinding in KDE Plasma 6 and Dolphin context menu (*"Open in Kitty"*).

### Developer Fonts (Nerd Fonts)
Automated user-space installation into `~/.local/share/fonts`:
`JetBrainsMono`, `FiraCode`, `CascadiaCode`, `Meslo`, and `Hack` (you can also pass custom font names like `./Setup/fonts.sh GeistMono`).

### Fastfetch
Aesthetic hardware and system summary (`ff` or `fastfetch`) supporting 4 themes: `debian`, `debian-simple`, `modern`, and `compact` (use `./Setup/fastfetch.sh --menu` to pick interactively or `--preview` to test).

---

## 3. Functional KDE Plasma 6 Desktop (`kde-settings.sh`)

> [!IMPORTANT]
> **Golden Dog Linux appearance preserved:** `kde-settings.sh` never alters global themes, color schemes, icons, cursors, panels, or window decorations.

- **KDE Gear Packages**: Installs official utilities (`dolphin`, `kate`, `spectacle`, `kcalc`, `ark`, `gwenview`, `okular`, `plasma-systemmonitor`, `kio-extras`, `dolphin-plugins`, `ffmpegthumbs`, `wl-clipboard`).
- **Optimized Dolphin**: Detailed view mode enabled by default with multimedia thumbnail previews.
- **Global `Ctrl+Alt+T` Shortcut**: Launches your preferred terminal (`kitty` or `konsole`).
- **Dolphin ServiceMenus**: Right-click context actions for **Kitty**, **Google Antigravity**, and **Antigravity IDE**.

---

## 4. Browsers, Media & Decoupled Software

- **Google Chrome** (`chrome.sh`): Official Google repository with Ozone Wayland flags (`--ozone-platform-hint=auto` and VA-API hardware acceleration).
- **Mozilla Firefox** (`firefox.sh`): Native `.deb` package from Mozilla with APT Pin-Priority 1000, replacing Firefox ESR. *(Note: this script currently installs the Spanish `firefox-l10n-es-es` language pack alongside `firefox`.)*
- **`yt-dlp` Downloader** (`yt-dlp-setup.sh`): Installs `yt-dlp`, `ffmpeg`, `aria2`, `python3-mutagen`, and configures `deno` via Mise for reliable YouTube downloads.
- **Flatpak** (`flatpak.sh`): Modular 22-app catalog integrated with KDE Discover (see the [Flatpak Apps Guide](./apps_en.md)).
- **Cockpit Web Console** (`cockpit.sh`): Preinstalled in Golden Dog Linux; this manager adds complementary modules (`cockpit-podman`, `cockpit-files`, `cockpit-sosreport`), optimizes `/etc/cockpit/cockpit.conf` (`IdleTimeout=15`, local/LAN origins), and keeps on-demand activation via `cockpit.socket` at `https://localhost:9090` (supports `--open`, `--client`, `--start`, `--stop`, `--restart`, `--disable`).

---

## 5. Summary of Commands with Just

```bash
just setup-all           # Set up the ENTIRE environment automatically (AMD / Intel)
just status              # Full system diagnostics (tuning, security, KDE, Cockpit)
just post-install        # Smart post-install dispatcher (AMD / Intel)
just kde-setup           # Functional KDE Plasma 6 setup (preserves visual theme)
just kde-status          # Show KDE Plasma 6 functional status
just tuning              # Kernel sysctl, limits, Baloo exclusions, and ZRAM
just zram                # Configure ZRAM compressed swap (50% RAM)
just security            # Configure UFW firewall and container/VM networking
just shell               # Install modern CLI tools and link Bash.Setup
just zsh                 # Configure modular Zsh environment (just zsh-default to switch)
just starship            # Enable Starship prompt (run ./Setup/starship.sh to install)
just kitty               # Configure GPU-accelerated Kitty terminal
just fonts               # Install Nerd Fonts
just fastfetch           # Configure Fastfetch banner
just multimedia          # Install GStreamer/FFmpeg codecs, VA-API, and Flathub
just yt-dlp              # Configure yt-dlp + FFmpeg + Deno
just flatpak             # Install core Flatpak utilities (Flatseal & Warehouse)
just chrome              # Install official Google Chrome
just firefox             # Install native Firefox (.deb)
just kodi                # Install Kodi media center via APT
just cockpit             # Configure Cockpit Web Console (just cockpit-open to launch)
just update              # Full Debian system upgrade via APT
```

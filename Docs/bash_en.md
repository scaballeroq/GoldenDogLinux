---
sidebar_position: 3
---

# Terminal Configuration (Bash & Zsh) on Debian 13

This guide explains in plain terms what each file in `Bash.Setup/` does to make your terminal faster, safer, and easier to use on both **Bash** and **Zsh**.

> [!NOTE]
> **How does this work? (Beginner-Friendly Summary)**
> An **alias** is a short nickname for a longer command (for instance, typing `g` instead of `git`, or `c` instead of `clear`).
> All scripts in `Bash.Setup/` are automatically linked into `~/.bashrc.d/` (and `~/.zshrc.d/` if you use Zsh) when you run `just shell` (`./Setup/shell.sh`) or `just zsh` (`./Setup/zsh-setup.sh`), keeping your `~/.bashrc` clean.

---

## 1. Installation & Modular Loading

The recommended way to enable everything is:
```bash
just shell   # Installs modern CLI tools (eza, bat, fzf, zoxide...) and links Bash.Setup
```
A small loader in `~/.bashrc` sources every readable `*.sh` file in `~/.bashrc.d/` (and `Setup/shell.sh` / `Setup/zsh-setup.sh` also initialize `fzf` and `zoxide`).

---

## 2. Environment Variables (`environment.sh`)

Sets up global defaults for both the terminal and KDE Plasma 6 Wayland apps:
- **Editor & Pager**: `EDITOR` and `VISUAL` default to `nvim` (falling back to `nano`); `PAGER="less"` with colorized `man` pages.
- **Wayland / KDE / Electron**: `GDK_BACKEND="wayland,x11,*"`, `QT_QPA_PLATFORM="wayland;xcb"`, `QT_QPA_PLATFORMTHEME="kde"`, `QT_AUTO_SCREEN_SCALE_FACTOR=1`, `MOZ_ENABLE_WAYLAND=1`, `ELECTRON_OZONE_PLATFORM_HINT="auto"`.
- **`PATH` entries**: Automatically prepends (if present) `~/bin`, `~/.local/bin`, `~/.cargo/bin`, `~/go/bin`, and `~/.local/share/mise/shims`.
- **Tools & Services**:
  - Activates `mise` (`mise activate bash/zsh --shims`).
  - Sets `DOCKER_HOST` to the rootless Podman socket when available.
  - Sets `LIBVIRT_DEFAULT_URI="qemu:///system"` for KVM virtual machines.
  - Configures `GPG_TTY`, `UV_LINK_MODE="copy"` (for Python `uv`), and Antigravity updater paths (`UPDATE_ANTIGRAVITY_PATH`, `UPDATE_ANTIGRAVITY_IDE_PATH`).

---

## 3. Shell Behavior & History (`options.sh` and `history.sh`)

### Smart Behavior (`options.sh`)
- **Bash**: Enables `autocd` (enter folders by typing their name), `cdspell` / `dirspell` (fixes minor folder typos), `globstar` (`**/*.ext`), and `checkwinsize`. Configures Readline for case-insensitive, colored tab completion.
- **Zsh**: Enables `AUTO_CD`, `CORRECT`, `AUTO_PUSHD`, `PUSHD_IGNORE_DUPS`, `NO_CASE_GLOB`, `EXTENDED_GLOB`, `INTERACTIVE_COMMENTS`, and interactive completion menus (`zstyle`).

### Command History (`history.sh`)
- **Bash**: Stores up to **10,000** commands in memory and **20,000** in `~/.bash_history`, adds timestamps (`HISTTIMEFORMAT="%F %T "`), enables `histappend` and `cmdhist`, and ignores duplicates and trivial commands (`HISTCONTROL=ignoreboth:erasedups`, `HISTIGNORE`).
- **Zsh**: Stores **20,000** commands in `~/.zsh_history` with live cross-tab sharing (`SHARE_HISTORY`), automatic deduplication (`HIST_IGNORE_ALL_DUPS`, `HIST_SAVE_NO_DUPS`), and `HISTORY_IGNORE`.

---

## 4. System Shortcuts & Aliases (`aliases.sh`)

- **File safety**: `rm -i`, `cp -i`, `mv -i`, `ln -i` (confirm before overwriting/deleting), `mkdir -p`, and `--preserve-root` on `chown`, `chmod`, and `chgrp`.
- **Modern listing & reading**: Uses `eza` (or `lsd` / `ls`) for `ls`, `ll`, `la`, `lt`, `tree`; and `batcat` / `bat` for `cat`, `less`, and `bat`.
- **Quick navigation**: `..`, `...`, `....`, `~`, `repo` (`~/Workspace/Repositorios`), `workspace` (`~/Workspace`), `gdl` (`~/Workspace/Repositorios/GoldenDogLinux`).
- **Modern CLI tools (when installed)**: `df` (`duf`), `du` (`dust`), `ps` (`procs`), `fd` (`fdfind`), `top` (`btm` or `btop`), `ff` / `sysinfo` (`fastfetch`).
- **Git (15 shortcuts)**: `g`, `gs`, `ga`, `gc`, `gca`, `gcm`, `gp`, `gph`, `gF`, `gl`, `gd`, `gco`, `gb`, `gbr`, `gba`.
- **APT packages (9 shortcuts)**: `update`, `upgrade`, `install`, `remove`, `purge`, `search`, `clean`, `list`, `pkg-info`.
- **Network & UFW Firewall**: `ports`, `myip`, `localip`; and `fw`, `fw-status`, `fw-numbered`, `fw-reload`, `fw-allow`, `fw-deny`.
- **Hardware, Kernel, VMs & Containers**:
  - `check-kernel` / `kernel-check` (`check-kernel-update()` checks `kernel.org`), `cpu-info`, `gpu-info`, `ram-info`, `disk-info`.
  - Virtual machines (`virsh`): `vms`, `vmstart`, `vmstop`, `vminfo`, `vmconsole`.
  - Podman: `pc` (`podman-compose`), `ppsa`, `pimg`, `pods`, `podsa`, `pclean` (`podman system prune -af`).
  - Shell & IDEs: `reload`, `edit-bashrc`, `edit-zshrc`, `edit-shell`, `edit-aliases`, `update-antigravity`, `update-antigravity-ide`.

---

## 5. Useful Functions (`functions.sh`)

- **Folders & search**: `mkcd <dir>` (create and enter), `up <N>` (go up N levels), `duh` (sorted folder sizes), `psgrep <name>`, `hg <text>` (search command history).
- **Backups & archives**: `backup <file>` (alias `backup_file`, timestamped copy), `extract <archive>` (auto-extracts `.zip`, `.tar.gz`, `.tar.xz`, `.tar.zst`, `.7z`, `.rar`, `.bz2`, etc.), and `compress <format> <source>` (`tar.gz`, `tar.bz2`, `tar.xz`, `zip`, `7z`).
- **USB drives**: `iso2sd <iso> <device>` (writes an ISO to USB) and `format-drive <device>` (interactive exFAT formatter).
- **Media**: `webm2mp4`, `transcode-video-1080p`, `img2jpg`, `img2png`.

---

## 6. Cloud Sync & Downloads (`rclone_aliases.sh` and `yt-dlp_aliases.sh`)

### Rclone Sync (`rclone_aliases.sh`)
Shortcuts using `--fast-list --transfers 8 --checkers 16 --tpslimit 10` for **Google Drive** and **OneDrive** (with `-dry` dry-run, `-copy` non-destructive copy, and `-down` download variants):
- `gdrive-imagenes`, `gdrive-documentos`, `gdrive-videos`, `gdrive-musica`, `gdrive-software`, `gdrive-kdenlive`, `gdrive-repos`, `gdrive-repos-debian`, `gdrive-repos-loladelacamara` (plus `-dry`, `-copy`, `-copy-dry`, and `-down*` for the first 5).
- `lola-onedrive-documentos-down` (and `-dry`, `-copy`, `-copy-dry` variants).
- Base paths can be overridden via `RCLONE_REPOS_BASE` (default `~/Proyectos`) and `RCLONE_EXT_BASE` (default `/run/media/$USER/NVME_EXT`).

### `yt-dlp` Downloads (`yt-dlp_aliases.sh`)
Requires `yt-dlp` and `ffmpeg` (plus optional `deno` and `firefox` cookies):
- `ytvideo <URL>`: Downloads video up to 1080p MP4.
- `ytaudio <URL>`: Downloads and converts to MP3.
- `ytlista <URL>` / `ytlista-audio <URL>`: Downloads full playlists (MP4 video or MP3 audio) using Firefox cookies.
- `ytdl-subs <URL>`: Downloads 1080p video with embedded Spanish auto-subtitles.

---

## 7. KDE Plasma 6 (`kde_settings.sh`) & Podman (`podman-functions.sh`)

### KDE Plasma 6 (`kde_settings.sh`)
CLI shortcuts that leave Golden Dog Linux's visual theme untouched:
- Reload: `plasma-restart`, `kwin-reload`.
- System Settings: `kde-settings`, `kde-conf-display`, `kde-conf-audio`, `kde-conf-sound`, `kde-conf-bluetooth`, `kde-conf-network`, `kde-conf-power`, `kde-conf-shortcuts`, `kde-conf-keyboard`, `kde-conf-touchpad`, `kde-conf-mouse`, `kde-conf-printers`.
- Apps & Wayland clipboard: `files` (Dolphin), `editor` / `text-editor` (`kate` or `kwrite`), `sysmon` / `monitor` (`plasma-systemmonitor`), `calc` (`kcalc`), `clipcopy` (`wl-copy`), `clippaste` (`wl-paste`).

### Podman Containers (`podman-functions.sh`)
- Functions: `pexec` (alias `psh`), `plogs`, `pinfo`, `pcp`, `pclean-all`, `prm-stopped`, `prmi-dangling`, `pstop-all`, `prm-all`, `prmi-all`, `quadlet-status`, `quadlet-logs`.
- Aliases: `p` (`podman`), `pps`, `psa`, `pi`, `pv`, `quadlet-reload`. *(Note: `pclean` is defined in `aliases.sh`.)*

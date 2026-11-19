---
sidebar_position: 3
---

# Bash Configuration on Debian 13

This guide details the terminal environment (Bash) setup and built-in utilities provided in the modular scripts under the `Bash.Setup` folder.

The modular configuration is structured through the `~/.bashrc.d/` directory to ensure the `~/.bashrc` file remains clean and maintainable.

---

## 1. Modular Environment Loading

The scripts are loaded dynamically by adding the following block to your `~/.bashrc` file:

```bash
# Modular loading of Bash.Setup scripts
if [ -d "$HOME/.bashrc.d" ]; then
    for script in "$HOME/.bashrc.d"/*.sh; do
        [ -r "$script" ] && source "$script"
    done
    unset script
fi
```

You can enable them by creating symbolic links in `~/.bashrc.d/`:
```bash
mkdir -p ~/.bashrc.d
ln -s "$(pwd)/Bash.Setup/"*.sh ~/.bashrc.d/
```

---

## 2. Environment Variables (`environment.sh`)

Defines global settings and performance optimizations for system tools:

- **Default Editor**: Sets `nvim` (Neovim) as the global editor.
- **Executable Paths (`PATH`)**: Adds local user directories to the environment path:
  - `~/.local/bin`
  - `~/bin`
  - Cargo/Rust bin directory (`~/.cargo/bin`)
- **Aesthetic Pager (`less` and `man`)**: Configures custom colors and flags to make Linux manual pages (`man`) and text viewing with `less` more readable.

---

## 3. Bash Behavior (`options.sh` and `history.sh`)

Optimizes shell interaction through internal adjustments.

### Advanced Shell Behavior (`options.sh`)
* **`autocd`**: Allows changing directories by typing the path directly (without prefixing `cd`).
* **`globstar`**: Enables recursive globbing pattern expansions (e.g. `ls **/*.js`).
* **Directory Typo Correction**: Enables `cdspell` and `dirspell` to automatically fix minor typos when entering folder names.

### Command History (`history.sh`)
* Expanded capacity of up to **10,000 commands** in memory and **20,000 in history file**.
* Ignores duplicates and common commands (`history -a`, `histignore`).
* Writes commands to the history file immediately after execution.

---

## 4. System Shortcuts & Aliases (`aliases.sh`)

Replaces standard commands with enriched and safe alternatives:

- **Security**:
  - `rm -i` (prompt before deletion)
  - `cp -i` (prompt before overwrite when copying)
  - `mv -i` (prompt before overwrite when moving)
  - Defensive `--preserve-root` flag enabled by default.
- **File Visualization** (if `eza` and `bat` are installed):
  - `ls` mapped to `eza` with icons and a clean structure.
  - `cat` mapped to `bat` with syntax highlighting.
- **Quick Navigation**:
  - `..`, `...`, `....` to step up directories quickly.
  - `c` to clear the screen (`clear`).
  - `path` to list PATH directories on individual lines.

---

## 5. System Functions & Utilities (`functions.sh`)

Includes helper shell functions to simplify recurring tasks:

* **`extract`**: Automatically extracts almost any compressed file format (`.zip`, `.tar.gz`, `.bz2`, `.rar`, etc.) without needing to recall specific decompression flags.
* **`mkcd`**: Creates a folder and immediately changes into it with a single command.
* **`up <N>`**: Steps up `N` directory levels easily (e.g. `up 3`).
* **`duh`**: Displays folder sizes in the current directory, sorted by weight on disk.
* **Multimedia Processing**:
  - `webm2mp4`: Converts WebM screen recordings (common in Wayland) to standard MP4 files.
  - `img2jpg` / `img2png`: Rapidly converts and optimizes image formats via console.

---

## 6. Cloud Sync and Downloads (`rclone_aliases.sh` and `yt-dlp_aliases.sh`)

Automates remote storage synchronization and media downloads.

### Rclone Synchronization
Facilitates cloud syncing (mirror or copy) with services like Google Drive and OneDrive using controlled transaction limits (`--tpslimit 10 --fast-list`) to avoid API throttling:
- `gdrive-documentos` / `gdrive-imagenes`: Synchronizes local -> cloud (with `-copy` and `-dry` variants).
- `gdrive-videos-down` / `gdrive-documentos-down`: Downloads files from the cloud to the local machine.

### yt-dlp Downloads
Utilities to automate media extraction:
- `ytvideo <URL>`: Downloads video in optimal quality (1080p).
- `ytaudio <URL>`: Downloads and converts stream to high-fidelity MP3.
- `ytlista-audio <URL>`: Downloads complete playlists converted to MP3.

---

## 7. Functional KDE Plasma 6 Helpers (`kde_settings.sh`)

Provides quick CLI shortcuts for KDE Plasma 6 while preserving 100% of Golden Dog Linux's native visual appearance:
- Quick reload for Plasma (`plasma-restart`) and KWin (`kwin-reload`).
- Direct launchers for System Settings modules (`kde-settings`, `kde-conf-display`, `kde-conf-audio`, `kde-conf-network`, `kde-conf-power`, etc.).
- Shortcuts for `files` (Dolphin), `editor` (Kate), `sysmon` (Plasma System Monitor), and Wayland clipboard (`clipcopy` / `clippaste`).

---

## 8. Container Functions (`podman-functions.sh`)

Aliases and helper functions that simplify Podman container and systemd Quadlet operations:
- `pexec <container>` (or `psh <container>`): Opens an interactive shell inside the specified container.
- `plogs <container>`: Follows container logs in real time.
- `quadlet-status` / `quadlet-reload`: Inspects and reloads systemd user Quadlet units.
- `pclean` / `pclean-all`: Performs a complete system purge of unused containers and images.

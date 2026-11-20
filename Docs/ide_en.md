---
sidebar_position: 5
---

# Integrated Development Environments (IDEs) & AI Tools on Golden Dog Linux (Debian 13)

This guide explains in plain terms what each script in the `IDE/` folder installs and how to use it for coding with modern editors and AI assistants.

> [!NOTE]
> **What are IDEs and CLIs? (Beginner-Friendly Summary)**
> - An **IDE** (*Integrated Development Environment*) is the app where you write, run, and debug code.
> - A **CLI** (*Command Line Interface*) is a tool you run directly inside the terminal.
> - All installers are tuned for **Golden Dog Linux (Debian 13 Trixie)** on **KDE Plasma 6 (Wayland)**, enabling sharp Wayland rendering and **Dolphin** right-click actions (*Open in...*).

---

## 1. Google Antigravity Desktop 2.0 (`IDE/antigravity.sh`)

Installs the official **Google Antigravity Desktop 2.0** application into `/opt/antigravity` with a desktop launcher and `/usr/local/bin/antigravity` command:

* **What it does under the hood**:
  - Checks and installs required graphics/desktop libraries (including Debian 13 `t64` packages).
  - Downloads and installs the official tarball atomically with backup and automatic rollback via `/usr/local/bin/update-antigravity`.
  - Sets `chrome-sandbox` permissions (`4755`), extracts the native 512x512 icon, creates a Wayland launcher (`--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations`), and adds the Dolphin context menu at `/usr/share/kio/servicemenus/open-in-antigravity.desktop` (with user-level fallback in `~/.local/share/kio/servicemenus/`).
  - Detects legacy APT installations that could conflict.

* **Available commands**:
  ```bash
  just antigravity                  # Install or update Antigravity Desktop
  ./IDE/antigravity.sh --status     # Fast rootless status check (-s)
  ./IDE/antigravity.sh --check      # Check for updates (0 = up to date, 1 = update available) (-c)
  ./IDE/antigravity.sh --force      # Force reinstall even if already up to date (-f)
  ./IDE/antigravity.sh --url <URL>  # Install from a custom tarball URL
  ./IDE/antigravity.sh --uninstall  # Remove the application and its links
  ./IDE/antigravity.sh --help       # Show help (-h)
  ```

---

## 2. Google Antigravity CLI (`IDE/antigravity-cli.sh`)

Installs the **`agy`** command-line tool 100% rootlessly into `~/.local/bin/agy`:

* **What it does under the hood**:
  - Queries the official release manifest and downloads only when a newer version is available (with fallback to `https://antigravity.google/cli/install.sh`).
  - Creates the `~/.local/bin/update-antigravity-cli` helper symlink.
  - Automatically adds `~/.local/bin` to your graphical and terminal sessions via `~/.config/environment.d/10-antigravity-cli.conf`, `~/.bashrc.d/antigravity-cli.sh`, and `~/.zshrc.d/antigravity-cli.zsh` (if Zsh is present).

* **Available commands**:
  ```bash
  just antigravity-cli                  # Install or update agy CLI
  ./IDE/antigravity-cli.sh --status     # Inspect local and remote versions (-s)
  ./IDE/antigravity-cli.sh --check      # Check updates (-c: 0 up-to-date, 1 available, 2 error)
  ./IDE/antigravity-cli.sh --update     # Upgrade to the latest version (-u)
  ./IDE/antigravity-cli.sh --force      # Force reinstall (-f)
  ./IDE/antigravity-cli.sh --url <URL>  # Install from a specific URL
  ./IDE/antigravity-cli.sh --uninstall  # Remove agy and its shell integration
  ./IDE/antigravity-cli.sh --help       # Show help (-h)
  ```

---

## 3. Google Antigravity IDE (`IDE/antigravity-ide.sh`)

Installs **Google Antigravity IDE** into `/opt/antigravity-ide` along with `/usr/local/bin/update-antigravity-ide`, Wayland desktop entry, and Dolphin context menu (`/usr/share/kio/servicemenus/open-in-antigravity-ide.desktop` -> *"Open in Antigravity IDE"*):

```bash
just antigravity-ide                  # Install or update Antigravity IDE
./IDE/antigravity-ide.sh --status     # Check installation status (-s or status)
./IDE/antigravity-ide.sh --url <URL>  # Install from a specific official tarball URL
./IDE/antigravity-ide.sh --uninstall  # Uninstall Antigravity IDE
./IDE/antigravity-ide.sh --help       # Show help (-h or help)
```

---

## 4. OpenCode AI CLI (`IDE/opencode.sh`)

Installs and manages the **OpenCode AI** terminal coding assistant in user space via **Mise**:

* **What it does under the hood**:
  - If `mise` is not installed yet, it automatically runs `../ProgrammingLanguages/mise.sh` first.
  - Installs `opencode@latest` (or a pinned version) globally in Mise (`mise use --global`).
  - Cleans up legacy binaries (`~/.opencode/bin/opencode`, `~/.local/bin/opencode`, `~/.bashrc.d/opencode.sh`, `~/.zshrc.d/opencode.zsh`) to prevent `PATH` shadowing.
  - Propagates Mise shims to KDE Plasma 6 via `~/.config/environment.d/10-opencode.conf`, `systemctl --user`, and `dbus`.

* **Available commands**:
  ```bash
  just opencode                         # Install OpenCode via Mise (-i / --install)
  ./IDE/opencode.sh --version 1.18.13   # Install a specific version (-v or positional arg)
  ./IDE/opencode.sh --update            # Upgrade OpenCode to the latest version (-u)
  ./IDE/opencode.sh --force             # Force reinstall (-f)
  ./IDE/opencode.sh --status            # Check Mise and OpenCode status (-s)
  ./IDE/opencode.sh --uninstall         # Uninstall OpenCode while keeping user config (-r)
  ./IDE/opencode.sh --help              # Show help (-h)
  ```

---

## 5. Batch Installation & Diagnostics

```bash
just ides         # Install Antigravity Desktop, CLI, IDE, and OpenCode together
just ides-status  # Run status diagnostics across all 4 IDE/AI tools
```

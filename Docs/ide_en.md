---
sidebar_position: 5
---

# Integrated Development Environments (IDEs) & AI Tools on Golden Dog Linux (Debian 13)

This guide details the installation, update, and diagnostic scripts for the development environments and AI coding agents managed in the `IDE/` folder.

All installers are optimized for **Golden Dog Linux (Debian 13 Trixie)** on **KDE Plasma 6 (Wayland)**, featuring native Ozone Wayland desktop launchers, `~/.config/environment.d/` integration, and **Dolphin** context menu actions (`~/.local/share/kio/servicemenus/`).

---

## 1. Google Antigravity Desktop 2.0 (`IDE/antigravity.sh`)

Installs the official **Google Antigravity Desktop 2.0** application into `/opt/antigravity` with a `/usr/local/bin/antigravity` symlink:

* **Features**:
  - 100% rootless local vs. remote version inspection (`--status` and `--check`).
  - Atomic updater `/usr/local/bin/update-antigravity` with automatic rollback and `chrome-sandbox` SUID 4755 setup.
  - Native 512x512 icon extraction directly from `app.asar`.
  - Desktop launcher configured with `--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations`.
  - Dolphin context menu action: *"Open in Antigravity"*.

* **Commands**:
  ```bash
  just antigravity               # Install or update Antigravity Desktop
  ./IDE/antigravity.sh --status  # Fast rootless status check
  ```

---

## 2. Google Antigravity CLI (`IDE/antigravity-cli.sh`)

Installs the **`agy`** command-line tool 100% rootlessly into `~/.local/bin/agy`:

* **Features**:
  - Queries the official release manifest and downloads only when a newer version is available.
  - Automatic fallback to the official installer (`https://antigravity.google/cli/install.sh`).
  - Idempotent integration in `~/.bashrc.d/antigravity-cli.sh` and `~/.config/environment.d/10-antigravity-cli.conf`.

* **Commands**:
  ```bash
  just antigravity-cli               # Install or update agy CLI
  ./IDE/antigravity-cli.sh --status  # Inspect local and remote versions
  ```

---

## 3. Google Antigravity IDE (`IDE/antigravity-ide.sh`)

Installs **Google Antigravity IDE** into `/opt/antigravity-ide` with its `/usr/local/bin/update-antigravity-ide` helper and Dolphin context menu integration (*"Open in Antigravity IDE"*):

```bash
just antigravity-ide               # Install or update Antigravity IDE
./IDE/antigravity-ide.sh --status  # Check installation status
```

---

## 4. OpenCode AI CLI (`IDE/opencode.sh`)

Manages the **OpenCode AI** terminal agent in user space via **Mise**:

* **Features**:
  - Idempotent installation (`mise use --global opencode@latest`) or version pinning (`--version <ver>`).
  - Automatic cleanup of legacy binaries in `~/.opencode/bin` to avoid `PATH` conflicts.
  - Propagates Mise shims to the KDE Plasma 6 session (`~/.config/environment.d/10-opencode.conf`).

* **Commands**:
  ```bash
  just opencode               # Install OpenCode via Mise
  ./IDE/opencode.sh --status  # Check Mise and OpenCode status
  ./IDE/opencode.sh --update  # Upgrade to the latest version
  ```

---

## 5. Batch Installation & Diagnostics

```bash
just ides         # Install Antigravity Desktop, CLI, IDE, and OpenCode
just ides-status  # Run status diagnostics across all IDE tools
```

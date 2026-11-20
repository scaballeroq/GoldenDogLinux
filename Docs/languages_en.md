---
sidebar_position: 6
---

# Programming Languages Management on Debian 13

This guide explains in plain terms how to install, update, and maintain the programming languages managed in `ProgrammingLanguages/`.

> [!NOTE]
> **How are languages organized here? (Beginner-Friendly Summary)**
> Instead of mixing global language versions into the OS, we use modern tools that keep everything clean and isolated:
> - **Mise**: A single manager to install and update tools like Node.js or `uv` inside your user folder.
> - **Rustup**: The official Rust toolchain installer.
> - **APT (Native Debian)**: Used for system Python and OpenJDK 21 (Java) for rock-solid stability.

---

## 1. Version Manager Mise (`mise.sh`)

[`ProgrammingLanguages/mise.sh`](../ProgrammingLanguages/mise.sh) installs and configures **Mise** (a modern replacement for `nvm`, `pyenv`, or `asdf`):

* **Smart install mode**:
  - When run as a **normal user** (recommended, e.g. via `just mise`), it installs the **standalone** binary in `~/.local/bin/mise` without needing root privileges.
  - When run with `sudo` or `--deb`, it registers `https://mise.jdx.dev/deb` and installs the official `.deb` package (`/usr/bin/mise`).
* **Automatic integration**:
  - Writes `~/.config/environment.d/10-mise.conf` (Mise shims `PATH` + `COREPACK_ENABLE_DOWNLOAD_PROMPT=0`) and propagates it to KDE Plasma 6 via `systemctl --user` and `dbus`.
  - Creates `~/.bashrc.d/mise.sh` (and `~/.zshrc.d/mise.zsh` if Zsh is present) along with shell completions.
* **Commands & flags**:
  ```bash
  just mise                    # Install or reconfigure Mise
  just mise-status             # Full diagnostics for Mise and runtimes (-s / --status)
  ./ProgrammingLanguages/mise.sh --update      # Upgrade Mise, plugins, and tools (-u)
  ./ProgrammingLanguages/mise.sh --standalone  # Force standalone install in ~/.local/bin/mise
  ./ProgrammingLanguages/mise.sh --deb         # Force official .deb package (requires sudo)
  ./ProgrammingLanguages/mise.sh --uninstall   # Uninstall Mise (preserves ~/.local/share/mise) (-r)
  ./ProgrammingLanguages/mise.sh --help        # Show help (-h)
  ```

---

## 2. Language Runtimes & SDKs

### Node.js LTS & Corepack (`nodejs.sh`)
* **Automatic dependencies**: Automatically runs `./mise.sh` if `mise` is missing, and installs missing APT packages (`build-essential`, `make`, `curl`, `python3`) for compiling native npm modules (`node-gyp`).
* **Node.js & Corepack**: Installs `node@lts` globally in Mise, enables **Corepack** (`pnpm` and `yarn` without interactive prompts), and tunes multi-core parallelism (`MAKEFLAGS`, `JOBS`, `npm_config_jobs`).
* **Integration**: Writes `~/.config/environment.d/10-nodejs.conf`, `~/.bashrc.d/nodejs.sh`, `~/.zshrc.d/nodejs.zsh`, and completions for `npm` and `pnpm`.
* **Commands**: `just node`, `just node --status` (`-s`), `just node --update` (`-u`), `just node --help` (`-h`).

### Native Python + `uv` Package Manager (`python.sh` & `python-uv-init.sh`)
* **PEP 668 System Protection**: Debian 13 relies on `/usr/bin/python3` for critical OS tools (APT, UFW, KDE). `python.sh` **removes any global Mise Python shim** (`mise unuse --global python`) and verifies native Debian packages (`python3`, `python3-venv`, `python3-pip`, `git`, `curl`, `build-essential`, `libssl-dev`).
* **Isolated per-project environments with `uv`**: Installs `uv@latest` (and `uvx`) via Mise, configures `UV_LINK_MODE=copy` and `PYTHONUNBUFFERED=1` in `10-python.conf`, shells, and completions, and symlinks [`python-uv-init.sh`](../ProgrammingLanguages/python-uv-init.sh) to `~/.local/bin/py-project`.
* **Commands**: `just python`, `just python --status` (`-s`), `just python --update` (`-u`), `just python-uv` (project wizard).

---

## 3. Rust Environment (`rust.sh`)

Configures **Rustup**, **Cargo**, and fast build tooling:

1. **System dependencies**: Installs missing APT packages from `build-essential`, `cmake`, `libssl-dev`, `pkg-config`, `clang`, `libclang-dev`, `curl`, `mold`, and `sccache`.
2. **Rustup & components**: Installs the `stable` toolchain (`--profile default --no-modify-path`) with `rust-analyzer`, `clippy`, `rustfmt`, `rust-src`, plus `cargo-binstall`, `cargo-update`, and `cargo-watch`.
3. **Cargo config (`~/.cargo/config.toml`)**: Sets multi-core `jobs = NPROC`, `sccache` wrapper, and the `clang` + `mold` linker (`-C link-arg=-fuse-ld=mold`).
4. **Integration & commands**: Configures `10-rust.conf`, `~/.bashrc.d/rust.sh`, `~/.zshrc.d/rust.zsh`, and `rustup`/`cargo` completions.
   ```bash
   just rust           # Install and optimize Rust
   just rust --status  # Full diagnostics (-s)
   just rust --update  # Update rustup, toolchains, and cargo tools (-u)
   ```

---

## 4. OpenJDK 21 LTS (`java.sh`)

Installs **Java 21** and build tools:

* **APT packages**: `openjdk-21-jdk`, `openjdk-21-jre`, `ca-certificates`, `ca-certificates-java`, `maven`, `curl`, `pcscd`, and `libnss3-tools` (smartcard / eID support).
* **RAM-aware optimization**: Configures `JAVA_HOME`, `_JAVA_AWT_WM_NONREPARENTING=1` and font antialiasing (`JAVA_TOOL_OPTIONS`) for Wayland, `MAVEN_ARGS="-T 1C"`, and scales heap memory (`4096m`/`4g` on systems with >= 15 GB RAM, or `2048m`/`2g` otherwise).
* **Gradle properties**: Generates an optimized `~/.gradle/gradle.properties` (daemon, parallel, `workers.max`, caching, `vfs.watch`). *(Note: it configures Gradle performance properties rather than installing a global Gradle binary, as projects typically use `./gradlew`.)*
* **Commands**:
  ```bash
  just java                 # Install and optimize OpenJDK 21 and Maven
  just java --status        # Inspect Java, JAVA_HOME, Maven, and Gradle (-s)
  just java --alternatives  # Show installed Java alternatives (-a)
  just java --update        # Upgrade OpenJDK and Maven via APT (-u)
  ```

---

## 5. Task Automation (`justfile`)

Available from both the root `justfile` and `ProgrammingLanguages/justfile`:

```bash
just languages          # Install Mise, Node.js LTS, Python/uv, Rust, and OpenJDK 21
just languages-status   # Show full diagnostics for all runtimes
just mise [args]        # Manage Mise (--status, --update, --standalone, --deb, --uninstall)
just node [args]        # Manage Node.js LTS + Corepack (--status, --update)
just python [args]      # Verify native Python + manage uv (--status, --update)
just python-uv          # Create a new isolated Python project with uv
just rust [args]        # Manage Rust + Mold + sccache (--status, --update)
just java [args]        # Manage OpenJDK 21 + Maven (--status, --alternatives, --update)
```

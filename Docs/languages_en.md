---
sidebar_position: 6
---

# Programming Languages Management on Debian 13

This guide details the installation, control, and maintenance of programming languages and their development environments managed in the `ProgrammingLanguages` folder.

Environment management is centralized through **Mise** (runtimes and SDKs) and **Rustup** (Rust toolchain), supplemented by automated tasks configured via a `justfile`.

---

## 1. Version Manager Mise (`mise.sh`)

Mise is a modern CLI version manager that replaces older tools like `asdf`, `nvm`, or `pyenv`. It downloads and configures development environments globally or locally.

1. **Official Repository Registration and Installation**:
   ```bash
   sudo apt update
   sudo apt install -y curl gpg
   sudo mkdir -p -m 755 /etc/apt/keyrings
   curl -fsSL https://mise.jdx.dev/gpg-key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
   echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list > /dev/null
   sudo apt update
   sudo apt install -y mise
   ```

2. **Shell Activation**:
   Mise initialization is added to `~/.bashrc.d/mise.sh`:
   ```bash
   eval "$(mise activate bash)"
   ```

---

## 2. Language Runtimes and SDKs

### Node.js LTS & Corepack (`nodejs.sh`)
* **Dependencies**: Verifies and installs `build-essential`, `python3`, and `make` via APT if missing, required to build native npm dependencies (`node-gyp`), with automatic multi-core parallelism (`JOBS=$(nproc)`).
* **Installation**: Configures the latest global Node.js LTS release in Mise:
  ```bash
  mise use --global node@lts
  ```
* **Corepack (pnpm & yarn)**: Enables Corepack with unattended downloads (`COREPACK_ENABLE_DOWNLOAD_PROMPT=0`) and generates native shell completions for `npm` and `pnpm`.

### Native Python + `uv` Package Manager (`python.sh` & `python-uv-init.sh`)
* **PEP 668 Philosophy**: Python is **not** installed globally in Mise to protect `/usr/bin/python3` and Debian system tools (APT, UFW, KDE Plasma 6).
* **Per-project `uv` management**: Installs `uv` globally via Mise (`mise use --global uv@latest`) with `UV_LINK_MODE=copy` and links the interactive `py-project` wizard (`python-uv-init.sh`) to `~/.local/bin/py-project` to create isolated virtual environments from templates (Basic, FastAPI, Typer/Rich CLI, Data Science).

---

## 3. Rust Environment (`rust.sh`)

Rust is managed through **Rustup**, accelerated with the **Mold** linker and **sccache** compilation cache:

1. **System Build Dependencies, Mold, and sccache**:
   ```bash
   sudo apt-get install -y build-essential cmake libssl-dev pkg-config curl mold sccache
   ```

2. **Rustup & IDE Components**:
   Installs the `stable` toolchain along with `rust-analyzer`, `clippy`, `rustfmt`, and `rust-src`:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path
   rustup component add rust-analyzer clippy rustfmt rust-src
   ```

3. **Cargo Optimizations (`~/.cargo/config.toml`)**:
   Automatically configures CPU thread count (`jobs = NPROC`), `rustc-wrapper = "sccache"`, and the `mold` linker (`-C link-arg=-fuse-ld=mold`).

4. **Fast Binary Installer (`cargo-binstall`)**:
   Installs `cargo-binstall` along with `cargo-update` and `cargo-watch`.

---

## 4. OpenJDK 21 LTS (`java.sh`)

Installs `openjdk-21-jdk`, `openjdk-21-jre`, `maven`, `ca-certificates-java`, `pcscd`, and `libnss3-tools` (compatible with smartcards and AutoFirma):
* Configures `_JAVA_AWT_WM_NONREPARENTING=1` and font antialiasing for KWin Wayland.
* Optimizes **Maven** (`MAVEN_ARGS="-T 1C"`) and **Gradle** (`~/.gradle/gradle.properties` with daemon, parallel execution, caching, and `vfs.watch`).

---

## 5. Task Automation (`justfile`)

Both the root `justfile` and `ProgrammingLanguages/justfile` provide recipes to install or inspect all languages:

```bash
just languages          # Install Mise, Node.js LTS, Python/uv, Rust, and OpenJDK 21
just languages-status   # Show full diagnostics for all runtimes
just mise               # Install/update Mise
just node               # Install/update Node.js LTS + Corepack
just python             # Verify native Python + install uv
just python-uv          # Interactive wizard to create Python projects with uv
just rust               # Install/update Rust + Mold + sccache
just java               # Install/update OpenJDK 21 + Maven + Gradle
```

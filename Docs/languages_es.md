---
sidebar_position: 6
---

# Gestión de Lenguajes de Programación en Debian 13

Esta guía detalla la instalación, control y mantenimiento de lenguajes de programación y sus herramientas de desarrollo en la carpeta `ProgrammingLanguages`.

La gestión de entornos se centraliza principalmente a través de **Mise** (runtimes y SDKs) y **Rustup** (entorno de Rust), complementados por un gestor de tareas automatizado mediante un `justfile`.

---

## 1. Gestor de Versiones Mise (`mise.sh`)

Mise es una herramienta de terminal moderna que reemplaza a herramientas como `asdf`, `nvm` o `pyenv`. Se encarga de descargar y configurar rápidamente entornos de desarrollo locales o globales.

1. **Instalación y Repositorio Oficial**:
   ```bash
   sudo apt update
   sudo apt install -y curl gpg
   sudo mkdir -p -m 755 /etc/apt/keyrings
   curl -fsSL https://mise.jdx.dev/gpg-key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
   echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list > /dev/null
   sudo apt update
   sudo apt install -y mise
   ```

2. **Activación de Shell**:
   Se crea de manera modular la inicialización de Mise en `~/.bashrc.d/mise.sh`:
   ```bash
   eval "$(mise activate bash)"
   ```

---

## 2. Runtimes de Lenguajes y SDKs

### Node.js LTS & Corepack (`nodejs.sh`)
* **Dependencias**: Verifica e instala `build-essential`, `python3` y `make` vía APT si faltan, necesarios para compilar dependencias nativas de npm (`node-gyp`), configurando paralelismo multinúcleo automático (`JOBS=$(nproc)`).
* **Instalación**: Configura la última versión LTS de Node.js en Mise:
  ```bash
  mise use --global node@lts
  ```
* **Corepack (pnpm & yarn)**: Habilita Corepack con descargas desatendidas (`COREPACK_ENABLE_DOWNLOAD_PROMPT=0`) y genera autocompletados nativos para `npm` y `pnpm`.

### Python Nativo + Gestor `uv` (`python.sh` y `python-uv-init.sh`)
* **Filosofía PEP 668**: Python **no** se instala de forma global en Mise para proteger la integridad de `/usr/bin/python3` y las herramientas del sistema Debian (APT, UFW, KDE Plasma 6).
* **Gestor `uv` por proyecto**: Instala `uv` globalmente vía Mise (`mise use --global uv@latest`) con `UV_LINK_MODE=copy` y enlaza el asistente interactivo `py-project` (`python-uv-init.sh`) en `~/.local/bin/py-project` para crear entornos virtuales aislados con plantillas (Básico, FastAPI, CLI con Typer/Rich, Data Science).

---

## 3. Entorno de Rust (`rust.sh`)

Rust se gestiona mediante su herramienta estándar **Rustup**, optimizada con el enlazador ultrarrápido **Mold** y caché de compilación **sccache**:

1. **Compiladores, Mold y sccache**:
   ```bash
   sudo apt-get install -y build-essential cmake libssl-dev pkg-config curl mold sccache
   ```

2. **Instalador Rustup y Componentes IDE**:
   Instala el toolchain `stable` junto con `rust-analyzer`, `clippy`, `rustfmt` y `rust-src`:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path
   rustup component add rust-analyzer clippy rustfmt rust-src
   ```

3. **Configuración de Cargo (`~/.cargo/config.toml`)**:
   Configura automáticamente el número de hilos de la CPU (`jobs = NPROC`), `rustc-wrapper = "sccache"` y el linker `mold` (`-C link-arg=-fuse-ld=mold`).

4. **Instalador de Binarios Rápidos (`cargo-binstall`)**:
   Instala `cargo-binstall` junto con utilidades como `cargo-update` y `cargo-watch`.

---

## 4. OpenJDK 21 LTS (`java.sh`)

Instala `openjdk-21-jdk`, `openjdk-21-jre`, `maven`, `ca-certificates-java`, `pcscd` y `libnss3-tools` (compatible con AutoFirma y DNIe):
* Configura `_JAVA_AWT_WM_NONREPARENTING=1` y suavizado de fuentes para KWin Wayland.
* Optimiza **Maven** (`MAVEN_ARGS="-T 1C"`) y **Gradle** (`~/.gradle/gradle.properties` con daemon, paralelismo, caché y `vfs.watch`).

---

## 5. Automatización de Tareas (`justfile`)

Tanto en el `justfile` raíz como en `ProgrammingLanguages/justfile` dispones de recetas para instalar o diagnosticar todos los lenguajes:

```bash
just languages          # Instala Mise, Node.js LTS, Python/uv, Rust y OpenJDK 21
just languages-status   # Muestra el diagnóstico completo de todos los runtimes
just mise               # Instala/actualiza Mise
just node               # Instala/actualiza Node.js LTS + Corepack
just python             # Verifica Python nativo + instala uv
just python-uv          # Asistente interactivo para crear proyectos Python con uv
just rust               # Instala/actualiza Rust + Mold + sccache
just java               # Instala/actualiza OpenJDK 21 + Maven + Gradle
```

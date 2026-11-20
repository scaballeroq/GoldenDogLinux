---
sidebar_position: 6
---

# Gestión de Lenguajes de Programación en Debian 13

Esta guía explica de forma sencilla cómo instalar, actualizar y mantener los lenguajes de programación incluidos en la carpeta `ProgrammingLanguages/`.

> [!NOTE]
> **¿Cómo se organizan los lenguajes aquí? (Para principiantes)**
> En lugar de mezclar versiones globales en todo el sistema, usamos herramientas modernas que mantienen todo ordenado y limpio:
> - **Mise**: Un gestor único para instalar y actualizar herramientas como Node.js o `uv` dentro de tu usuario (sin ensuciar Debian).
> - **Rustup**: El instalador oficial de Rust.
> - **APT (Debian nativo)**: Para Python del sistema y OpenJDK 21 (Java), garantizando máxima estabilidad.

---

## 1. Gestor de Versiones Mise (`mise.sh`)

[`ProgrammingLanguages/mise.sh`](../ProgrammingLanguages/mise.sh) instala y configura **Mise** (alternativa moderna a `nvm`, `pyenv` o `asdf`):

* **Modo de instalación inteligente**:
  - Si lo ejecutas como **usuario normal** (lo recomendado, por ejemplo con `just mise`), instala el binario **standalone** en `~/.local/bin/mise` sin necesitar permisos de administrador.
  - Si lo ejecutas con `sudo` o con `--deb`, añade el repositorio oficial `https://mise.jdx.dev/deb` e instala el paquete `.deb` (`/usr/bin/mise`).
* **Integración automática**:
  - Configura `~/.config/environment.d/10-mise.conf` (`PATH` con shims de Mise + `COREPACK_ENABLE_DOWNLOAD_PROMPT=0`) y lo propaga a KDE Plasma 6 vía `systemctl --user` y `dbus`.
  - Crea `~/.bashrc.d/mise.sh` (y `~/.zshrc.d/mise.zsh` si usas Zsh) junto con el autocompletado en terminal.
* **Comandos y banderas**:
  ```bash
  just mise                    # Instala o reconfigura Mise
  just mise-status             # Diagnóstico completo de Mise y runtimes (-s / --status)
  ./ProgrammingLanguages/mise.sh --update      # Actualiza Mise, plugins y herramientas (-u)
  ./ProgrammingLanguages/mise.sh --standalone  # Fuerza instalación en ~/.local/bin/mise
  ./ProgrammingLanguages/mise.sh --deb         # Fuerza paquete oficial .deb (requiere sudo)
  ./ProgrammingLanguages/mise.sh --uninstall   # Desinstala Mise (conserva ~/.local/share/mise) (-r)
  ./ProgrammingLanguages/mise.sh --help        # Muestra la ayuda (-h)
  ```

---

## 2. Runtimes de Lenguajes y SDKs

### Node.js LTS & Corepack (`nodejs.sh`)
* **Instalación automática**: Si `mise` no está instalado aún, ejecuta `./mise.sh` automáticamente. Comprueba e instala `build-essential`, `make`, `curl` y `python3` vía APT para poder compilar módulos nativos (`node-gyp`).
* **Node.js y Corepack**: Instala `node@lts` globalmente en Mise, activa **Corepack** (para usar `pnpm` y `yarn` sin prompts) y ajusta el paralelismo automático al número de núcleos de tu CPU (`MAKEFLAGS`, `JOBS`, `npm_config_jobs`).
* **Integración**: Genera `~/.config/environment.d/10-nodejs.conf`, `~/.bashrc.d/nodejs.sh`, `~/.zshrc.d/nodejs.zsh` y autocompletado para `npm` y `pnpm`.
* **Comandos**: `just node`, `just node --status` (`-s`), `just node --update` (`-u`), `just node --help` (`-h`).

### Python Nativo + Gestor `uv` (`python.sh` y `python-uv-init.sh`)
* **Protección del sistema (PEP 668)**: Debian 13 usa `/usr/bin/python3` para herramientas críticas del sistema (APT, UFW, KDE). Por eso `python.sh` **desactiva cualquier Python global en Mise** (`mise unuse --global python`) y verifica los paquetes nativos (`python3`, `python3-venv`, `python3-pip`, `git`, `curl`, `build-essential`, `libssl-dev`).
* **Entornos aislados con `uv`**: Instala `uv@latest` (y `uvx`) mediante Mise, activa `UV_LINK_MODE=copy` y `PYTHONUNBUFFERED=1` en `10-python.conf`, shells y autocompletado, y enlaza el asistente [`python-uv-init.sh`](../ProgrammingLanguages/python-uv-init.sh) en `~/.local/bin/py-project`.
* **Comandos**: `just python`, `just python --status` (`-s`), `just python --update` (`-u`), `just python-uv` (asistente de proyectos; consulta la [Guía práctica de Python con `uv`](./python_uv_es.md)).

---

## 3. Entorno de Rust (`rust.sh`)

Configura **Rustup**, **Cargo** y herramientas de compilación ultrarrápida:

1. **Dependencias del sistema**: Instala vía APT solo lo que falte de `build-essential`, `cmake`, `libssl-dev`, `pkg-config`, `clang`, `libclang-dev`, `curl`, `mold` y `sccache`.
2. **Rustup y componentes**: Instala el toolchain `stable` (`--profile default --no-modify-path`) junto con `rust-analyzer`, `clippy`, `rustfmt` y `rust-src`, además de `cargo-binstall`, `cargo-update` y `cargo-watch`.
3. **Configuración de Cargo (`~/.cargo/config.toml`)**: Activa compilación multinúcleo (`jobs = NPROC`), caché de compilación `sccache` y el enlazador `clang` + `mold` (`-C link-arg=-fuse-ld=mold`).
4. **Integración y comandos**: Configura `10-rust.conf`, `~/.bashrc.d/rust.sh`, `~/.zshrc.d/rust.zsh` y autocompletado de `rustup` y `cargo`.
   ```bash
   just rust           # Instala y optimiza Rust
   just rust --status  # Diagnóstico completo (-s)
   just rust --update  # Actualiza rustup, toolchains y paquetes de cargo (-u)
   ```

---

## 4. OpenJDK 21 LTS (`java.sh`)

Instala **Java 21** y herramientas de construcción:

* **Paquetes APT**: `openjdk-21-jdk`, `openjdk-21-jre`, `ca-certificates`, `ca-certificates-java`, `maven`, `curl`, `pcscd` y `libnss3-tools` (soporte para tarjetas inteligentes, DNIe y AutoFirma).
* **Optimización automática según tu RAM**: Configura `JAVA_HOME`, `_JAVA_AWT_WM_NONREPARENTING=1` y suavizado de fuentes (`JAVA_TOOL_OPTIONS`) para Wayland, `MAVEN_ARGS="-T 1C"`, y asigna memoria dinámica (`4096m`/`4g` si tienes >= 15 GB de RAM, o `2048m`/`2g` en equipos con menos RAM).
* **Propiedades de Gradle**: Genera `~/.gradle/gradle.properties` optimizado (daemon, paralelo, `workers.max`, caché y `vfs.watch`). *(Nota: configura las propiedades de rendimiento de Gradle, pero no instala el binario global de Gradle porque los proyectos modernos usan `./gradlew`).*
* **Comandos**:
  ```bash
  just java                 # Instala y optimiza OpenJDK 21 y Maven
  just java --status        # Diagnóstico de Java, JAVA_HOME, Maven y Gradle (-s)
  just java --alternatives  # Muestra versiones de Java instaladas (-a)
  just java --update        # Actualiza OpenJDK y Maven vía APT (-u)
  ```

---

## 5. Resumen de Comandos con `just`

Tanto desde la raíz del repositorio como dentro de `ProgrammingLanguages/`, puedes usar:

```bash
just languages          # Instala Mise, Node.js LTS, Python/uv, Rust y OpenJDK 21
just languages-status   # Diagnóstico completo de todos los lenguajes
just mise [opciones]    # Gestiona Mise (--status, --update, --standalone, --deb, --uninstall)
just node [opciones]    # Gestiona Node.js LTS + Corepack (--status, --update)
just python [opciones]  # Verifica Python nativo + gestiona uv (--status, --update)
just python-uv          # Crea un nuevo proyecto Python aislado con uv
just rust [opciones]    # Gestiona Rust + Mold + sccache (--status, --update)
just java [opciones]    # Gestiona OpenJDK 21 + Maven (--status, --alternatives, --update)
```

# 🐕 Golden Dog Linux — Asistente de Configuración (Debian 13 KDE Plasma)

Este repositorio contiene una colección organizada, modular y automatizada de scripts para dejar a punto **Golden Dog Linux** (<https://goldendoglinux.org/>), una distribución minimalista basada en **Debian GNU/Linux 13 (Trixie)** con **KDE Plasma (Wayland)**, que incluye **Cockpit** y **UFW** preinstalados y configurados.

> [!TIP]
> **¿Eres nuevo/a en Linux o buscas una guía sencilla sin tecnicismos?**
> 👉 **[Lee aquí la Guía Fácil Paso a Paso (`Docs/guia_rapida_es.md`)](./Docs/guia_rapida_es.md)** con explicaciones claras para cualquier nivel.
> *(English version available at [`README.en.md`](./README.en.md) and [`Docs/quick_guide_en.md`](./Docs/quick_guide_en.md)).*

> [!IMPORTANT]
> **Apariencia de KDE 100% intacta:** Golden Dog Linux trae una personalización visual propia muy cuidada. Ninguno de los scripts de este repositorio modifica temas globales, colores, iconos, cursores, paneles, fondos de pantalla ni decoraciones de ventana de KDE Plasma.

---

## 🚀 Inicio Rápido en 3 Pasos (Para Todos los Usuarios)

Si acabas de instalar **Golden Dog Linux** en cualquier PC o portátil con procesador **AMD** o **Intel** *(tarjetas gráficas Nvidia excluidas)*:

### 1. Abre la terminal e instala `git` y `just`
```bash
sudo apt update && sudo apt install -y git just
```

### 2. Descarga este proyecto
```bash
mkdir -p ~/Workspace/Repositorios
cd ~/Workspace/Repositorios
git clone https://github.com/GoldendogLinux/GoldenDogLinux.git
cd GoldenDogLinux
```

### 3. Ejecuta la configuración automática (o elige solo lo que necesites)

```bash
# Opción A: Configurar TODO automáticamente (detecta si tu equipo es AMD o Intel)
just setup-all

# Opción B: Configurar solo la base del sistema + multimedia + apps de escritorio (sin herramientas de programación)
just post-install multimedia flatpak chrome kde-setup tuning security
```

Cuando termine, **reinicia tu ordenador** y tendrás todos los drivers, códecs multimedia, tienda de aplicaciones y optimizaciones listas.

---

## 🎯 ¿Qué hace cada comando? (Tabla Rápida)

Puedes instalar todo de golpe con `just setup-all` o ejecutar **solo la pieza que quieras** en cualquier momento:

| Comando Fácil | ¿Para qué sirve? | Comprobar su estado |
| :--- | :--- | :--- |
| `just post-install` | Instala drivers **AMD** o **Intel**, microcódigo, audio **PipeWire**, **ZRAM** y soporte **Flatpak** en KDE Discover. | `just amd-status` / `just intel-status` |
| `just multimedia` | Instala todos los códecs de vídeo/audio (**FFmpeg**, **GStreamer**), aceleración **VA-API** y miniaturas de vídeo en Dolphin. | `just multimedia-status` |
| `just kde-setup` | Mejora **Dolphin** (vista detallada y miniaturas), añade el atajo `Ctrl+Alt+T` y menús de clic derecho (**sin tocar tu tema visual**). | `just kde-status` |
| `just flatpak` | Configura el catálogo **Flathub** e instala utilidades base (**Flatseal**, **Warehouse**) para instalar apps como VLC, Spotify o LibreOffice. | `just flatpak-status` |
| `just chrome` | Instala el navegador **Google Chrome** oficial con aceleración de vídeo Wayland. | `just chrome-status` |
| `just firefox` | Instala el navegador **Mozilla Firefox** oficial (`.deb` nativo en español). | `just firefox-status` |
| `just tuning` | Acelera el sistema: memoria **ZRAM** al 50%, red **TCP BBR**, apagado rápido y exclusiones de carpetas pesadas en **KDE Baloo**. | `just tuning-status` |
| `just security` | Configura el cortafuegos **UFW** nativo permitiendo **Cockpit** (`9090`), **KDE Connect**, contenedores **Podman** y máquinas virtuales **KVM**. | `just security-status` |
| `just cockpit` | Optimiza el panel web preinstalado **Cockpit** (`https://localhost:9090`), añade módulos extra (`podman`, `files`, `sosreport`) y activa ahorro de batería (`IdleTimeout=15`). | `just cockpit-status` |
| `just shell` | Instala herramientas modernas de terminal (`eza`, `bat`, `fzf`, `zoxide`, `btop`, `ripgrep`) y activa los atajos de `Bash.Setup`. | `just shell-status` |
| `just kitty` | Instala y configura la terminal **Kitty** acelerada por GPU con desenfoque Wayland y tema Catppuccin Mocha. | `just kitty-status` |
| `just fonts` | Instala las fuentes **Nerd Fonts** (`JetBrainsMono`, `FiraCode`, `CascadiaCode`, `Meslo`, `Hack`) para ver iconos en la terminal. | `just fonts-status` |
| `just fastfetch` | Configura el resumen visual del sistema (**Fastfetch** — escribe `ff` en la terminal para verlo). | `just fastfetch-status` |
| `just languages` | *(Para desarrolladores)* Instala **Mise**, **Node.js LTS**, **Python + uv**, **Rust** y **OpenJDK 21**. | `just languages-status` |
| `just git-setup` | *(Para desarrolladores)* Instala y configura **Git**, **Git-Delta**, **Lazygit** y **GitHub CLI (`gh`)**. | `just git-status` |
| `just ides` | *(Para desarrolladores)* Instala **Google Antigravity Desktop 2.0**, **Antigravity CLI (`agy`)**, **Antigravity IDE** y **OpenCode AI**. | `just ides-status` |
| `just podman-setup` | *(Para desarrolladores)* Configura contenedores **Podman Rootless** y servicios **Quadlets** de systemd. | `just podman-status` |
| `just virtualization` | *(Avanzado)* Configura máquinas virtuales **KVM/QEMU** con **Virt-Manager** y **Cockpit Machines**. | `just virtualization-status` |

---

## 📚 Índice de Documentación (`Docs/`)

Toda la documentación está disponible en español e inglés dentro de la carpeta [`Docs/`](./Docs/):

1. 🌟 **[Guía Fácil Paso a Paso (Para Todos los Niveles)](./Docs/guia_rapida_es.md)** | *[Beginner's Quick Guide (EN)](./Docs/quick_guide_en.md)*
2. ⚙️ **[Configuración del Sistema, KDE y Multimedia](./Docs/setup_es.md)** | *[System Setup (EN)](./Docs/setup_en.md)*
3. 🛡️ **[Seguridad y Cortafuegos UFW](./Docs/seguridad_es.md)** | *[Security & UFW (EN)](./Docs/seguridad_en.md)*
4. 📦 **[Aplicaciones de Escritorio (Flatpak / Flathub)](./Docs/apps_es.md)** | *[Flatpak Apps (EN)](./Docs/apps_en.md)*
5. 🐚 **[Terminal, Atajos y Funciones (`Bash.Setup`)](./Docs/bash_es.md)** | *[Bash & Zsh Setup (EN)](./Docs/bash_en.md)*
6. 🐙 **[Control de Versiones (Git, Delta, Lazygit, GitHub CLI)](./Docs/git_es.md)** | *[Git Setup (EN)](./Docs/git_en.md)*
7. 💻 **[Entornos de Desarrollo e IA (Antigravity & OpenCode)](./Docs/ide_es.md)** | *[IDEs & AI Tools (EN)](./Docs/ide_en.md)*
8. 🐍 **[Lenguajes de Programación (Mise, Node, Python, Rust, Java)](./Docs/languages_es.md)** | *[Languages (EN)](./Docs/languages_en.md)*
9. 🧪 **[Guía Práctica de Proyectos Python con `uv` (`py-project`)](./Docs/python_uv_es.md)**
10. 🐳 **[Contenedores Podman Rootless y Quadlets](./Docs/podman_es.md)** | *[Podman Containers (EN)](./Docs/podman_en.md)*
11. 🖥️ **[Virtualización KVM/QEMU con Virt-Manager y Cockpit](./Docs/virtualizacion_es.md)** | *[KVM Virtualization (EN)](./Docs/virtualization_en.md)*

---

## 📂 Organización Técnica del Repositorio

* **[`Setup/`](./Setup/)**: Scripts independientes de sistema, hardware (`amd-setup.sh`, `intel-setup.sh`), escritorio (`kde-settings.sh`, `kitty.sh`, `fastfetch.sh`, `fonts.sh`), navegadores (`chrome.sh`, `firefox.sh`), multimedia (`multimedia.sh`, `flatpak.sh`, `yt-dlp-setup.sh`), rendimiento (`debian-tuning.sh`, `zram-setup.sh`) y seguridad/administración (`seguridad.sh`, `cockpit.sh`).
* **[`Bash.Setup/`](./Bash.Setup/)**: Configuración modular para **Bash** (`~/.bashrc.d`) y **Zsh** (`~/.zshrc.d`) con atajos útiles (`aliases.sh`, `functions.sh`, `kde_settings.sh`, `podman-functions.sh`, `rclone_aliases.sh`, `yt-dlp_aliases.sh`).
* **[`ProgrammingLanguages/`](./ProgrammingLanguages/)**: Gestión limpia de runtimes con `mise.sh`, proyectos Python aislados con `uv` (`python.sh`, `python-uv-init.sh`), `nodejs.sh`, `rust.sh` (con `mold` y `sccache`) y `java.sh` (OpenJDK 21 + Maven/Gradle).
* **[`IDE/`](./IDE/)**: Instaladores y actualizadores para `git.sh`, `antigravity.sh`, `antigravity-cli.sh`, `antigravity-ide.sh` y `opencode.sh`.
* **[`Podman/`](./Podman/)**: Ecosistema de contenedores rootless con Quadlets de systemd, plantillas de proyectos y el asistente `podman-utils`.
* **[`Virtualizacion/`](./Virtualizacion/)**: Aprovisionamiento de KVM/QEMU, Libvirt, aceleración 3D VirGL, Polkit sin contraseña e integración con Cockpit y UFW.

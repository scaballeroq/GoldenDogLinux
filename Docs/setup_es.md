---
sidebar_position: 2
---

# Configuración del Sistema en Debian GNU/Linux (KDE Plasma 6 Wayland)

Esta guía detalla el proceso de configuración base, optimización de la terminal, instalación de herramientas esenciales, soporte multimedia y personalización del entorno de usuario aplicados a un sistema **Debian GNU/Linux** con **KDE Plasma 6**.

Las configuraciones están automatizadas a través de los scripts ubicados en la carpeta `Setup` y orquestadas mediante el `justfile`.

---

## 1. Post-Instalación Base (`post-install.sh`)

Prepara el sistema base detectando la CPU/GPU del equipo (cualquier sobremesa o portátil **AMD** o **Intel**; gráficas **Nvidia excluidas**) y ejecutando el aprovisionamiento adecuado:
- **`post-install-amd.sh`** + **`amd-setup.sh`**: Para procesadores y gráficas AMD (microcódigo, firmware AMD, Mesa RADV, VA-API `radeonsi`, códecs FFmpeg/GStreamer, PipeWire, ZRAM y soporte Flatpak en Discover).
- **`post-install-intel.sh`** + **`intel-setup.sh`**: Para procesadores y gráficas Intel (microcódigo Intel, VA-API `iHD`/`i965`, Mesa ANV Vulkan, códecs FFmpeg/GStreamer, PipeWire, ZRAM y soporte Flatpak en Discover).

> [!NOTE]
> `post-install` instala `flatpak` y el backend de KDE Discover; el repositorio **Flathub** se añade después con `just flatpak` o `just multimedia`. Se recomienda **reiniciar el equipo** al terminar.

Comandos:
```bash
just post-install          # Auto-detecta AMD o Intel (también acepta --amd / --intel)
just amd-setup --status    # Diagnóstico de hardware y drivers AMD (o intel-status)
just zram-status           # Comprueba la memoria swap comprimida ZRAM (50% de RAM en ZSTD)
```

---

## 2. Entorno de Terminal y Shell (`shell.sh`, `zsh-setup.sh`, `starship.sh`, `fastfetch.sh`, `fonts.sh` y `kitty.sh`)

Instala utilidades modernas de consola, tipografías para desarrollo, Zsh opcional, el prompt Starship y el emulador Kitty acelerado por GPU.

### Utilidades Modernas de Terminal (`shell.sh` y `zsh-setup.sh`)
Se instalan alternativas modernas a comandos clásicos y utilidades base:
- `eza` (reemplazo de `ls` con git e iconos)
- `bat` (reemplazo de `cat` con sintaxis coloreada vía `batcat`)
- `fzf` (buscador difuso interactivo para Ctrl+R, Ctrl+T, Alt+C)
- `zoxide` (navegación inteligente con `cd`)
- `ripgrep` (`rg`, búsqueda rápida de texto)
- `fd-find` (`fd`, búsqueda intuitiva de archivos)
- `duf` y `du-dust` (visualización de espacio en disco)
- `procs` (reemplazo moderno de `ps`)
- `btop` (monitor de recursos del sistema)
- `curl`, `git` y `jq` (herramientas de red y JSON)

Si deseas usar **Zsh** en lugar de Bash, `just zsh` configura `~/.zshrc` con tema Powerline, resaltado de sintaxis y autosugerencias (y `just zsh-default` lo fija como shell predeterminada). Para **Starship**, ejecuta `./Setup/starship.sh` la primera vez para instalar el binario y `just starship` / `just starship-disable` para activarlo o desactivarlo.

### Kitty Terminal Acelerada por GPU
Configura Kitty con:
- Opacidad al 75% con desenfoque de fondo (*blur 32*) acelerado por GPU Mesa (AMD/Intel).
- Esquema de color Catppuccin Mocha (`#181825`).
- Tipografía JetBrainsMono Nerd Font.
- Atajo global `Ctrl+Alt+T` en KDE Plasma 6 y menú contextual en Dolphin (*"Abrir en Kitty"*).

### Fuentes de Desarrollo (Nerd Fonts)
Descarga e instala en `~/.local/share/fonts` fuentes optimizadas para programación y glifos de terminal:
`JetBrainsMono`, `FiraCode`, `CascadiaCode`, `Meslo` y `Hack` (también puedes pasar nombres concretos como `./Setup/fonts.sh GeistMono`).

### Fastfetch
Muestra información estética del hardware y sistema (`ff` o `fastfetch`). Soporta 4 temas: `debian`, `debian-simple`, `modern` y `compact` (puedes elegir interactivamente con `./Setup/fastfetch.sh --menu` o previsualizar con `--preview`).

---

## 3. Escritorio KDE Plasma 6 Funcional (`kde-settings.sh`)

> [!IMPORTANT]
> **Apariencia de Golden Dog Linux intacta:** `kde-settings.sh` no altera temas globales, colores, iconos, cursores, paneles ni decoraciones de ventana de KDE Plasma.

- **Paquetes KDE Gear**: Instala utilidades oficiales (`dolphin`, `kate`, `spectacle`, `kcalc`, `ark`, `gwenview`, `okular`, `plasma-systemmonitor`, `kio-extras`, `dolphin-plugins`, `ffmpegthumbs`, `wl-clipboard`).
- **Dolphin Optimizado**: Vista detallada por defecto con previsualización de miniaturas multimedia (vídeo, audio, imágenes, fuentes).
- **Atajo Global `Ctrl+Alt+T`**: Lanza directamente tu terminal preferida (`kitty` o `konsole`).
- **Dolphin ServiceMenus**: Menú contextual con accesos directos para abrir carpetas en **Kitty**, **Google Antigravity** y **Antigravity IDE**.

---

## 4. Navegadores, Multimedia y Software Desacoplado

- **Google Chrome** (`chrome.sh`): Repositorio oficial de Google con optimización Wayland (`--ozone-platform-hint=auto` y aceleración VA-API).
- **Mozilla Firefox** (`firefox.sh`): Paquete nativo `.deb` oficial de Mozilla (con localización `firefox-l10n-es-es`) y APT Pin-Priority 1000, eliminando Firefox ESR.
- **Descargador `yt-dlp`** (`yt-dlp-setup.sh`): Instala `yt-dlp`, `ffmpeg`, `aria2`, `python3-mutagen` y configura `deno` vía Mise para descargas de vídeo/audio sin bloqueos.
- **Flatpak** (`flatpak.sh`): Catálogo modular de 22 aplicaciones con integración en KDE Discover (ver [guía de aplicaciones Flatpak](./apps_es.md)).
- **Cockpit Web Console** (`cockpit.sh`): Activación bajo demanda por `cockpit.socket` en `https://localhost:9090` con módulos para Podman, KVM Machines, Storage, NetworkManager y Files (soporta `--open`, `--client`, `--start`, `--stop`, `--restart`, `--disable`).

---

## 5. Resumen de Comandos con Just

```bash
just setup-all           # Configura TODO el entorno automáticamente (AMD / Intel)
just status              # Diagnóstico integral (tuning, seguridad, KDE y Cockpit)
just post-install        # Despachador de post-instalación (AMD / Intel)
just kde-setup           # Optimización funcional de KDE Plasma 6 (sin tocar temas)
just kde-status          # Muestra el estado funcional de KDE Plasma 6
just tuning              # Optimizaciones de Kernel sysctl, límites, Baloo y ZRAM
just zram                # Configura memoria swap comprimida ZRAM (50% RAM)
just security            # Configura cortafuegos UFW y red para contenedores/VMs
just shell               # Instala herramientas CLI modernas y enlaza Bash.Setup
just zsh                 # Configura entorno Zsh modular (just zsh-default para fijarlo)
just starship            # Activa Starship prompt (ejecuta ./Setup/starship.sh para instalar)
just kitty               # Configura terminal Kitty acelerada por GPU
just fonts               # Instala fuentes Nerd Fonts
just fastfetch           # Configura banner estético Fastfetch
just multimedia          # Instala códecs GStreamer/FFmpeg, VA-API y Flathub
just yt-dlp              # Configura yt-dlp + FFmpeg + Deno
just flatpak             # Instala utilidades base Flatpak (Flatseal y Warehouse)
just chrome              # Instala Google Chrome oficial
just firefox             # Instala Firefox nativo (.deb)
just kodi                # Instala centro multimedia Kodi vía APT
just cockpit             # Configura Cockpit Web Console (just cockpit-open para abrir)
just update              # Actualiza todo el sistema Debian vía APT
```

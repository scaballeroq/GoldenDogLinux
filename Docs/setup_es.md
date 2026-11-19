---
sidebar_position: 2
---

# Configuración del Sistema en Debian GNU/Linux (KDE Plasma 6 Wayland)

Esta guía detalla el proceso de configuración base, optimización de la terminal, instalación de herramientas esenciales, soporte multimedia y personalización del entorno de usuario aplicados a un sistema **Debian GNU/Linux** con **KDE Plasma 6**.

Las configuraciones están automatizadas a través de los scripts ubicados en la carpeta `Setup` y orquestadas mediante el `justfile`.

---

## 1. Post-Instalación Base (`post-install.sh`)

Prepara el sistema base detectando la CPU/GPU del equipo (cualquier sobremesa o portátil **AMD** o **Intel**; gráficas **Nvidia excluidas**) y ejecutando el aprovisionamiento adecuado:
- **`post-install-amd.sh`** + **`amd-setup.sh`**: Para procesadores y gráficas AMD (microcódigo, firmware AMD, Mesa RADV, VA-API `radeonsi`, PipeWire, ZRAM, Flatpak Flathub).
- **`post-install-intel.sh`** + **`intel-setup.sh`**: Para procesadores y gráficas Intel (microcódigo Intel, VA-API `iHD`/`i965`, Mesa ANV Vulkan, PipeWire, ZRAM, Flatpak Flathub).

Comando:
```bash
just post-install
```

---

## 2. Entorno de Terminal y Shell (`shell.sh`, `fastfetch.sh`, `fonts.sh` y `kitty.sh`)

Instala utilidades modernas de consola, tipografías para desarrollo, el prompt interactivo Starship y el emulador Kitty acelerado por GPU.

### Utilidades Modernas de Terminal
Se instalan alternativas modernas a comandos clásicos:
- `eza` (reemplazo de `ls` con git e iconos)
- `bat` (reemplazo de `cat` con sintaxis coloreada vía `batcat`)
- `fzf` (buscador difuso interactivo para Ctrl+R, Ctrl+T, Alt+C)
- `zoxide` (navegación inteligente con `cd`)
- `ripgrep` (`rg`, búsqueda rápida de texto)
- `fd-find` (`fd`, búsqueda intuitiva de archivos)
- `duf` y `du-dust` (visualización de espacio en disco)
- `procs` (reemplazo moderno de `ps`)
- `btop` (monitor de recursos del sistema)

### Kitty Terminal Acelerada por GPU
Configura Kitty con:
- Opacidad al 75% con desenfoque de fondo (*blur 32*) acelerado por GPU Mesa RADV.
- Esquema de color Catppuccin Mocha (#181825).
- Tipografía JetBrainsMono Nerd Font.
- Atajo global `Ctrl+Alt+T` en KDE Plasma 6.
- Menú contextual en Dolphin (KIO ServiceMenu) para "Abrir en Kitty".

### Fuentes de Desarrollo (Nerd Fonts)
Descarga e instala fuentes optimizadas para programación y glifos de terminal:
`JetBrainsMono`, `FiraCode`, `CascadiaCode`, `Meslo` y `Hack`.

### Fastfetch
Muestra información estética del hardware y sistema. Soporta temas oficiales de Debian (`debian`) y diseño minimalista (`compact`).

---

## 3. Escritorio KDE Plasma 6 Funcional (`kde-settings.sh`)

> [!IMPORTANT]
> **Apariencia de Golden Dog Linux intacta:** `kde-settings.sh` no altera temas globales, colores, iconos, cursores, paneles ni decoraciones de ventana de KDE Plasma.

- **Paquetes KDE Gear**: Instala utilidades oficiales (`dolphin`, `kate`, `spectacle`, `okular`, `gwenview`, `ark`, `kio-extras`, `dolphin-plugins`, `ffmpegthumbs`, `wl-clipboard`).
- **Dolphin Optimizado**: Vista detallada por defecto con previsualización de miniaturas multimedia (vídeo, audio, imágenes, fuentes).
- **Atajo Global `Ctrl+Alt+T`**: Lanza directamente tu terminal preferida (`kitty` o `konsole`).
- **Dolphin ServiceMenus**: Menú contextual con accesos directos para abrir carpetas en **Kitty**, **Google Antigravity** y **Antigravity IDE**.

---

## 4. Navegadores y Software Desacoplado

- **Google Chrome** (`chrome.sh`): Repositorio oficial de Google con optimización Wayland (`--ozone-platform-hint=auto` y aceleración VA-API).
- **Mozilla Firefox** (`firefox.sh`): Paquete nativo `.deb` oficial de Mozilla con APT Pin-Priority 1000, eliminando Firefox ESR.
- **Flatpak** (`flatpak.sh`): Catálogo modular con integración en KDE Discover (Flatseal, Podman Desktop, Warehouse, VLC, Celluloid, OBS Studio, Kdenlive, Shotcut, Kodi, Stremio, Audacity, Spotify, Vesktop, Telegram, Bruno, DBeaver, LibreOffice, Obsidian, LocalSend, Pika Backup, GIMP, Inkscape).
- **Cockpit Web Console** (`cockpit.sh`): Activación bajo demanda por `cockpit.socket` en el puerto `9090` con módulos para Podman, KVM Machines, Storage y NetworkManager.

---

## 5. Resumen de Comandos con Just

```bash
just post-install        # Despachador de post-instalación (AMD / Intel)
just kde-setup           # Optimización funcional de KDE Plasma 6 (sin tocar temas)
just kde-status          # Muestra el estado funcional de KDE Plasma 6
just tuning              # Optimizaciones de Kernel sysctl, límites, Baloo y ZRAM
just shell               # Instala herramientas CLI modernas y enlaza Bash.Setup
just zsh                 # Configura entorno Zsh modular
just starship            # Instala y activa Starship prompt
just kitty               # Configura terminal Kitty acelerada por GPU
just fonts               # Instala fuentes Nerd Fonts
just fastfetch           # Configura banner estético Fastfetch
just multimedia          # Instala códecs GStreamer/FFmpeg y aceleración VA-API
just flatpak             # Instala catálogo Flatpak
just chrome              # Instala Google Chrome oficial
just firefox             # Instala Firefox nativo (.deb)
just cockpit             # Configura Cockpit Web Console
```

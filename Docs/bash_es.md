---
sidebar_position: 3
---

# Configuración de Terminal (Bash y Zsh) en Debian 13

Esta guía explica de forma sencilla qué hace cada archivo de la carpeta `Bash.Setup/` para hacer tu terminal más cómoda, segura y rápida, tanto en **Bash** como en **Zsh**.

> [!NOTE]
> **¿Cómo funciona esto? (Para principiantes)**
> Un **alias** es un atajo corto para no tener que escribir comandos largos (por ejemplo, escribir `g` en vez de `git`, o `c` en vez de `clear`).
> Todos los scripts de `Bash.Setup/` se enlazan automáticamente en `~/.bashrc.d/` (y en `~/.zshrc.d/` si usas Zsh) al ejecutar `just shell` (`./Setup/shell.sh`) o `just zsh` (`./Setup/zsh-setup.sh`), manteniendo tu `~/.bashrc` limpio.

---

## 1. Instalación y Carga Modular

La forma recomendada de activarlo todo es ejecutar:
```bash
just shell   # Instala herramientas modernas (eza, bat, fzf, zoxide...) y enlaza Bash.Setup
```
Si prefieres hacerlo manualmente, el bloque en `~/.bashrc` carga cada archivo `*.sh` legible de `~/.bashrc.d/` (y `Setup/shell.sh` / `Setup/zsh-setup.sh` añaden también la inicialización de `fzf` y `zoxide`).

---

## 2. Variables de Entorno (`environment.sh`)

Configura el entorno base para la terminal y las aplicaciones gráficas en KDE Plasma 6 Wayland:
- **Editor y paginador**: `EDITOR` y `VISUAL` usan `nvim` (o `nano` si Neovim no está instalado); `PAGER="less"` con colores para leer manuales (`man`).
- **Wayland / KDE / Electron**: `GDK_BACKEND="wayland,x11,*"`, `QT_QPA_PLATFORM="wayland;xcb"`, `QT_QPA_PLATFORMTHEME="kde"`, `QT_AUTO_SCREEN_SCALE_FACTOR=1`, `MOZ_ENABLE_WAYLAND=1`, `ELECTRON_OZONE_PLATFORM_HINT="auto"`.
- **Rutas (`PATH`)**: Añade automáticamente (si existen) `~/bin`, `~/.local/bin`, `~/.cargo/bin`, `~/go/bin` y `~/.local/share/mise/shims`.
- **Herramientas y servicios**:
  - Activa `mise` (`mise activate bash/zsh --shims`).
  - `DOCKER_HOST` apuntando al socket rootless de Podman si está activo.
  - `LIBVIRT_DEFAULT_URI="qemu:///system"` para máquinas virtuales KVM.
  - `GPG_TTY`, `UV_LINK_MODE="copy"` (para Python `uv`), y rutas de actualización de Antigravity (`UPDATE_ANTIGRAVITY_PATH`, `UPDATE_ANTIGRAVITY_IDE_PATH`).

---

## 3. Comportamiento e Historial (`options.sh` e `history.sh`)

### Comportamiento Inteligente (`options.sh`)
- **Bash**: Activa `autocd` (entrar en carpetas escribiendo solo su nombre), `cdspell` / `dirspell` (corrige pequeños errores al escribir rutas), `globstar` (`**/*.ext`) y `checkwinsize`. Configura Readline para autocompletado sin distinguir mayúsculas y con colores.
- **Zsh**: Activa `AUTO_CD`, `CORRECT`, `AUTO_PUSHD`, `PUSHD_IGNORE_DUPS`, `NO_CASE_GLOB`, `EXTENDED_GLOB`, `INTERACTIVE_COMMENTS` y menú visual de autocompletado (`zstyle`).

### Historial de Comandos (`history.sh`)
- **Bash**: Guarda hasta **10.000** comandos en memoria y **20.000** en `~/.bash_history`, añade fecha y hora (`HISTTIMEFORMAT="%F %T "`), usa `histappend` y `cmdhist`, e ignora duplicados y comandos triviales (`HISTCONTROL=ignoreboth:erasedups`, `HISTIGNORE`).
- **Zsh**: Guarda **20.000** comandos en `~/.zsh_history` con compartición inmediata entre pestañas (`SHARE_HISTORY`), deduplicación automática (`HIST_IGNORE_ALL_DUPS`, `HIST_SAVE_NO_DUPS`) y `HISTORY_IGNORE`.

---

## 4. Atajos y Aliases del Sistema (`aliases.sh`)

- **Seguridad al manipular archivos**: `rm -i`, `cp -i`, `mv -i`, `ln -i` (piden confirmación antes de sobrescribir/borrar), `mkdir -p`, y `--preserve-root` en `chown`, `chmod` y `chgrp`.
- **Listado y lectura modernos**: Usa `eza` (o `lsd` / `ls`) para `ls`, `ll`, `la`, `lt`, `tree`; y `batcat` / `bat` para `cat`, `less` y `bat`.
- **Navegación rápida**: `..`, `...`, `....`, `~`, `repo` (`~/Workspace/Repositorios`), `workspace` (`~/Workspace`), `gdl` (`~/Workspace/Repositorios/GoldenDogLinux`).
- **Herramientas modernas (si están instaladas)**: `df` (`duf`), `du` (`dust`), `ps` (`procs`), `fd` (`fdfind`), `top` (`btm` o `btop`), `ff` / `sysinfo` (`fastfetch`).
- **Git (15 atajos)**: `g`, `gs`, `ga`, `gc`, `gca`, `gcm`, `gp`, `gph`, `gF`, `gl`, `gd`, `gco`, `gb`, `gbr`, `gba`.
- **Paquetes APT (9 atajos)**: `update`, `upgrade`, `install`, `remove`, `purge`, `search`, `clean`, `list`, `pkg-info`.
- **Red y Cortafuegos UFW**: `ports`, `myip`, `localip`; y `fw`, `fw-status`, `fw-numbered`, `fw-reload`, `fw-allow`, `fw-deny`.
- **Hardware, Kernel, VMs y Contenedores**:
  - `check-kernel` / `kernel-check` (función `check-kernel-update` que consulta `kernel.org`), `cpu-info`, `gpu-info`, `ram-info`, `disk-info`.
  - Máquinas virtuales (`virsh`): `vms`, `vmstart`, `vmstop`, `vminfo`, `vmconsole`.
  - Podman: `pc` (`podman-compose`), `ppsa`, `pimg`, `pods`, `podsa`, `pclean` (`podman system prune -af`).
  - Shell e IDEs: `reload`, `edit-bashrc`, `edit-zshrc`, `edit-shell`, `edit-aliases`, `update-antigravity`, `update-antigravity-ide`.

---

## 5. Funciones Útiles (`functions.sh`)

- **Carpetas y búsqueda**: `mkcd <dir>` (crea y entra), `up <N>` (sube N niveles), `duh` (tamaño de carpetas ordenado), `psgrep <nombre>`, `hg <texto>` (busca en el historial).
- **Copias y compresión**: `backup <archivo>` (alias `backup_file`, crea copia con fecha/hora), `extract <archivo>` (descomprime `.zip`, `.tar.gz`, `.tar.xz`, `.tar.zst`, `.7z`, `.rar`, `.bz2`, etc.) y `compress <formato> <origen>` (`tar.gz`, `tar.bz2`, `tar.xz`, `zip`, `7z`).
- **Discos USB**: `iso2sd <iso> <dispositivo>` (graba una ISO en USB) y `format-drive <dispositivo>` (formatea a exFAT con confirmación interactiva).
- **Multimedia**: `webm2mp4`, `transcode-video-1080p`, `img2jpg`, `img2png`.

---

## 6. Nube y Descargas (`rclone_aliases.sh` y `yt-dlp_aliases.sh`)

### Sincronización Rclone (`rclone_aliases.sh`)
Atajos con `--fast-list --transfers 8 --checkers 16 --tpslimit 10` para **Google Drive** y **OneDrive** (con variantes `-dry` para simular sin cambios, `-copy` para copiar sin borrar en destino y `-down` para descargar):
- `gdrive-imagenes`, `gdrive-documentos`, `gdrive-videos`, `gdrive-musica`, `gdrive-software`, `gdrive-kdenlive`, `gdrive-repos`, `gdrive-repos-debian`, `gdrive-repos-loladelacamara` (y sus versiones `-dry`, `-copy`, `-copy-dry`, más `-down*` para las 5 primeras).
- `lola-onedrive-documentos-down` (y variantes `-dry`, `-copy`, `-copy-dry`).
- Puedes personalizar `RCLONE_REPOS_BASE` (por defecto `~/Proyectos`) y `RCLONE_EXT_BASE` (por defecto `/run/media/$USER/NVME_EXT`).

### Descargas con `yt-dlp` (`yt-dlp_aliases.sh`)
Requiere `yt-dlp` y `ffmpeg` (y opcionalmente `deno` y cookies de `firefox`):
- `ytvideo <URL>`: Descarga vídeo hasta 1080p en MP4.
- `ytaudio <URL>`: Descarga y convierte a MP3.
- `ytlista <URL>` / `ytlista-audio <URL>`: Descarga listas de reproducción completas (vídeo MP4 o audio MP3) usando cookies de Firefox.
- `ytdl-subs <URL>`: Descarga vídeo 1080p con subtítulos automáticos en español incrustados.

---

## 7. KDE Plasma 6 (`kde_settings.sh`) y Podman (`podman-functions.sh`)

### KDE Plasma 6 (`kde_settings.sh`)
Atajos de consola que no alteran la estética de Golden Dog Linux:
- Recarga: `plasma-restart`, `kwin-reload`.
- Preferencias del Sistema: `kde-settings`, `kde-conf-display`, `kde-conf-audio`, `kde-conf-sound`, `kde-conf-bluetooth`, `kde-conf-network`, `kde-conf-power`, `kde-conf-shortcuts`, `kde-conf-keyboard`, `kde-conf-touchpad`, `kde-conf-mouse`, `kde-conf-printers`.
- Apps y portapapeles Wayland: `files` (Dolphin), `editor` / `text-editor` (`kate` o `kwrite`), `sysmon` / `monitor` (`plasma-systemmonitor`), `calc` (`kcalc`), `clipcopy` (`wl-copy`), `clippaste` (`wl-paste`).

### Contenedores Podman (`podman-functions.sh`)
- Funciones: `pexec` (alias `psh`), `plogs`, `pinfo`, `pcp`, `pclean-all`, `prm-stopped`, `prmi-dangling`, `pstop-all`, `prm-all`, `prmi-all`, `quadlet-status`, `quadlet-logs`.
- Aliases: `p` (`podman`), `pps`, `psa`, `pi`, `pv`, `quadlet-reload`. *(Nota: `pclean` está en `aliases.sh`.)*

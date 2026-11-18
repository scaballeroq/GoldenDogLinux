# =============================================================================
# Golden Dog Linux Environment Configuration Justfile
# (Debian 13 Trixie + KDE Plasma 6 Wayland + Cockpit + UFW)
# =============================================================================

# Instala todo el entorno por defecto (Auto-detección de CPU AMD/Intel y Portátil/Sobremesa)
setup-all: post-install multimedia flatpak chrome tuning kde-setup shell security fonts fastfetch kitty ides git-setup languages podman-setup
    @echo "🚀 Entorno completo de Golden Dog Linux (KDE Plasma Wayland) configurado. Por favor, reinicia el sistema."

# Perfil completo para Portátil AMD
setup-laptop-amd: post-install-amd multimedia flatpak chrome tuning kde-setup shell security fonts fastfetch kitty ides git-setup languages podman-setup
    @echo "🚀 Entorno Portátil AMD (Golden Dog Linux KDE) configurado con éxito. Por favor, reinicia el sistema."

# Perfil completo para Portátil Intel
setup-laptop-intel: post-install-intel multimedia flatpak chrome tuning kde-setup shell security fonts fastfetch kitty ides git-setup languages podman-setup
    @echo "🚀 Entorno Portátil Intel (Golden Dog Linux KDE) configurado con éxito. Por favor, reinicia el sistema."

# Perfil completo para Sobremesa AMD (sin optimizaciones de batería/tapa de portátil)
setup-desktop-amd: post-install-amd multimedia flatpak chrome tuning kde-setup shell security fonts fastfetch kitty ides git-setup languages podman-setup
    @echo "🚀 Entorno Sobremesa AMD (Golden Dog Linux KDE) configurado con éxito. Por favor, reinicia el sistema."

# Perfil completo para Sobremesa Intel (sin optimizaciones de batería/tapa de portátil)
setup-desktop-intel: post-install-intel multimedia flatpak chrome tuning kde-setup shell security fonts fastfetch kitty ides git-setup languages podman-setup
    @echo "🚀 Entorno Sobremesa Intel (Golden Dog Linux KDE) configurado con éxito. Por favor, reinicia el sistema."

# Diagnóstico integral del sistema, hardware, energía, red y entorno de desarrollo
status:
    @echo "================================================================="
    @echo "🔍 DIAGNÓSTICO INTEGRAL GOLDEN DOG LINUX (DEBIAN 13 KDE PLASMA)"
    @echo "================================================================="
    @./Setup/debian-tuning.sh --status
    @echo ""
    @./Setup/seguridad.sh --status
    @echo ""
    @./Setup/kde-settings.sh --status

# =============================================================================
# CONFIGURACIÓN BASE DEL SISTEMA
# =============================================================================

# Configuración base post-instalación (Auto-detección inteligente: AMD vs Intel; Nvidia excluido)
post-install:
    ./Setup/post-install.sh

# Configuración post-instalación para AMD (Sobremesa o Portátil)
post-install-amd:
    ./Setup/post-install-amd.sh

# Configuración post-instalación para Intel (Sobremesa o Portátil)
post-install-intel:
    ./Setup/post-install-intel.sh

# Configuración independiente de hardware y drivers AMD (Microcódigo, Mesa RADV/VA-API, KVM)
amd-setup *args:
    ./Setup/amd-setup.sh {{args}}

# Estado del hardware y drivers AMD
amd-status:
    ./Setup/amd-setup.sh --status

# Configuración independiente de hardware y drivers Intel (Microcódigo, iHD/i965 VA-API, ANV, KVM)
intel-setup *args:
    ./Setup/intel-setup.sh {{args}}

# Estado del hardware y drivers Intel
intel-status:
    ./Setup/intel-setup.sh --status

# Autenticación y desbloqueo por huella dactilar (fprintd, PAM)
fingerprint *args:
    ./Setup/fingerprint-setup.sh {{args}}

# Estado y diagnóstico de la autenticación por huella dactilar
fingerprint-status:
    ./Setup/fingerprint-setup.sh --status

# Registrar huella dactilar en la terminal (sensor táctil)
fingerprint-enroll *finger:
    ./Setup/fingerprint-setup.sh --enroll {{finger}}

# Probar verificación biométrica en el lector
fingerprint-verify *finger:
    ./Setup/fingerprint-setup.sh --verify {{finger}}

# Optimización funcional de KDE Plasma 6 (Dolphin, miniaturas, Ctrl+Alt+T, servicemenus KIO) SIN alterar la apariencia de Golden Dog Linux
kde-setup *args:
    ./Setup/kde-settings.sh {{args}}

# Diagnóstico y estado funcional de KDE Plasma 6
kde-status:
    ./Setup/kde-settings.sh --status

# Optimizaciones avanzadas de rendimiento (Sysctl, límites, inotify 1M, max_map_count 16M, TCP BBR, exclusiones Baloo)
tuning:
    ./Setup/debian-tuning.sh

# Estado actual de las optimizaciones y métricas de rendimiento
tuning-status:
    ./Setup/debian-tuning.sh --status

# Configuración de swap comprimida en RAM (ZRAM con ZSTD al 50% de RAM)
zram *args:
    ./Setup/zram-setup.sh {{args}}

# Diagnóstico y estado de los dispositivos de memoria ZRAM
zram-status:
    ./Setup/zram-setup.sh --status

# Utilidades de terminal modernas (eza, bat, fzf, zoxide, ripgrep, fd, duf, dust, btop)
shell:
    ./Setup/shell.sh

# Diagnóstico y estado de utilidades CLI de terminal (eza, bat, fzf, zoxide, ripgrep...)
shell-status:
    ./Setup/shell.sh --status

# Replicación del entorno Zsh (Powerline prompt, syntax highlighting, autosuggestions, FZF, Zoxide)
zsh:
    ./Setup/zsh-setup.sh

# Diagnóstico y estado del entorno Zsh y módulos ~/.zshrc.d
zsh-status:
    ./Setup/zsh-setup.sh --status

# Establecer Zsh como shell por defecto para el usuario actual
zsh-default:
    ./Setup/zsh-setup.sh --default-shell

# Starship Prompt moderno (Instalar / Activar)
starship:
    ./Setup/starship.sh --enable

# Desactivar Starship y restaurar prompt nativo
starship-disable:
    ./Setup/starship.sh --disable

# Estado de Starship prompt
starship-status:
    ./Setup/starship.sh --status

# Suite de Fuentes Nerd Fonts completas (JetBrainsMono, FiraCode, CascadiaCode, Meslo, Hack)
fonts *args:
    ./Setup/fonts.sh {{args}}

# Diagnóstico y listado de fuentes Nerd Fonts instaladas
fonts-status:
    ./Setup/fonts.sh --status

# Diagnóstico visual del sistema (Fastfetch con diseño Debian Ruby y soporte FastCat)
fastfetch *args:
    ./Setup/fastfetch.sh {{args}}

# Estado del tema de Fastfetch
fastfetch-status:
    ./Setup/fastfetch.sh --status

# Terminal Kitty acelerada por GPU (Tema Catppuccin Mocha, blur Wayland/KWin, JetBrainsMono, Dolphin)
kitty *args:
    ./Setup/kitty.sh {{args}}

# Diagnóstico y estado de la terminal Kitty
kitty-status:
    ./Setup/kitty.sh --status

# Suite multimedia completa: códecs GStreamer, FFmpeg, VA-API Wayland y reproductores KDE
multimedia *args:
    ./Setup/multimedia.sh {{args}}

# Diagnóstico y estado de códecs multimedia y aceleración VA-API
multimedia-status:
    ./Setup/multimedia.sh --status

# Descargador y stack multimedia yt-dlp + FFmpeg + Deno JS engine
yt-dlp *args:
    ./Setup/yt-dlp-setup.sh {{args}}

# Diagnóstico y estado del entorno multimedia yt-dlp
yt-dlp-status:
    ./Setup/yt-dlp-setup.sh --status

# =============================================================================
# RED, SEGURIDAD Y FIREWALL (UFW)
# =============================================================================

# Cortafuegos UFW nativo y parámetros seguros de red para desarrollo (Cockpit, KDE Connect, Podman, KVM)
security:
    ./Setup/seguridad.sh

# Diagnóstico de seguridad, estado de UFW y parámetros del kernel
security-status:
    ./Setup/seguridad.sh --status

# Abrir puertos locales de desarrollo en UFW (Vite: 5173, Next.js: 3000, FastAPI: 8000, 8080)
dev-ports:
    ./Setup/seguridad.sh --dev-ports

# =============================================================================
# APLICACIONES DESACOPLADAS Y NAVEGADORES
# =============================================================================

# Gestor universal Flatpak y repositorio Flathub (Instalación por categorías o apps individuales)
flatpak *args:
    ./Setup/flatpak.sh {{args}}

# Diagnóstico y lista de aplicaciones Flatpak instaladas
flatpak-status:
    ./Setup/flatpak.sh --status

# Actualizar todas las aplicaciones y runtimes de Flatpak
flatpak-update:
    ./Setup/flatpak.sh --update

# Limpiar runtimes huérfanos y dependencias no utilizadas de Flatpak
flatpak-clean:
    ./Setup/flatpak.sh --clean

# Navegador Google Chrome oficial (Instalación, actualización u optimización Wayland)
chrome *args:
    ./Setup/chrome.sh {{args}}

# Diagnóstico y estado de Google Chrome, repositorio oficial y Wayland
chrome-status:
    ./Setup/chrome.sh --status

# Navegador Firefox nativo (.deb oficial de Mozilla)
firefox *args:
    ./Setup/firefox.sh {{args}}

# Diagnóstico y estado de Mozilla Firefox nativo y repositorio oficial
firefox-status:
    ./Setup/firefox.sh --status

# Centro Multimedia (Kodi + complementos de streaming)
kodi:
    sudo apt-get install -y kodi kodi-inputstream-adaptive kodi-inputstream-rtmp

# Actualización completa del sistema Debian vía APT
update:
    sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove --purge -y

# =============================================================================
# CONFIGURACIÓN DE RED Y VIRTUALIZACIÓN
# =============================================================================

# Configuración de KVM/QEMU y Libvirt (Optimizado para KDE Wayland, Cockpit Machines y Virt-Manager)
virtualization:
    ./Virtualizacion/virtualization.sh

# Diagnóstico y estado de la virtualización KVM/QEMU
virtualization-status:
    ./Virtualizacion/virtualization.sh --status

# Administración Web (Cockpit + Podman + Máquinas Virtuales + UFW)
cockpit *args:
    ./Setup/cockpit.sh {{args}}

# Estado del servicio y módulos de Cockpit
cockpit-status:
    ./Setup/cockpit.sh --status

# Abrir Cockpit en el navegador web (https://localhost:9090)
cockpit-open:
    ./Setup/cockpit.sh --open

# =============================================================================
# CONTROL DE VERSIONES
# =============================================================================

# Git, Delta, Lazygit, GH CLI
git-setup:
    ./IDE/git.sh

# =============================================================================
# GESTORES DE RUNTIMES
# =============================================================================

# Gestor de versiones Mise (Instalación, actualización u opciones)
mise *args:
    ./ProgrammingLanguages/mise.sh {{args}}

# Diagnóstico y estado de Mise y runtimes de desarrollo
mise-status:
    ./ProgrammingLanguages/mise.sh --status

# =============================================================================
# LENGUAJES DE PROGRAMACIÓN
# =============================================================================

# Todos los lenguajes
languages: mise node python rust java
    @echo "✅ Lenguajes instalados."

# Node.js LTS
node *args:
    ./ProgrammingLanguages/nodejs.sh {{args}}

# Python con UV package manager
python *args:
    ./ProgrammingLanguages/python.sh {{args}}

# Inicializador de proyectos Python con UV
python-uv *args:
    ./ProgrammingLanguages/python-uv-init.sh {{args}}

# Rust
rust *args:
    ./ProgrammingLanguages/rust.sh {{args}}

# Java (OpenJDK)
java *args:
    ./ProgrammingLanguages/java.sh {{args}}

# =============================================================================
# ENTORNOS DE DESARROLLO (IDEs)
# =============================================================================

# Todos los IDEs
ides: antigravity antigravity-cli antigravity-ide opencode
    @echo "✅ IDEs instalados."

# Google Antigravity Desktop 2.0 (Completo)
antigravity:
    ./IDE/antigravity.sh

# Google Antigravity CLI
antigravity-cli:
    ./IDE/antigravity-cli.sh

# Google Antigravity IDE Engine
antigravity-ide:
    ./IDE/antigravity-ide.sh

# OpenCode AI CLI/Editor
opencode:
    ./IDE/opencode.sh

# =============================================================================
# PODMAN Y CONTENEDORES QUADLETS
# =============================================================================

# Configuración completa de Podman Rootless y Quadlets
podman-setup:
    ./Podman/install/podman-install.sh

# Configuración base de Podman Rootless
podman-base:
    ./Podman/install/podman-install.sh

# Configuración de servicios Quadlets de Podman
podman-quadlets:
    ./Podman/install/quadlets-setup.sh

# Estado y diagnóstico de Podman y Quadlets
podman-status:
    ./Podman/install/podman-install.sh --status
    ./Podman/lib/podman-utils.sh doctor

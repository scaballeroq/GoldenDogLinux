#!/bin/bash
# =============================================================================
# CONFIGURACIÓN Y ALIASES PARA KDE PLASMA (kde_settings.sh)
# Golden Dog Linux (Debian 13 Trixie + KDE Plasma Wayland)
# =============================================================================
# Proporciona atajos rápidos, accesos directos a Preferencias del Sistema de KDE,
# aplicaciones nativas de KDE Gear y utilidades Wayland.
# Preserva íntegramente la personalización visual nativa de Golden Dog Linux.
# =============================================================================

# Evitar ejecución en subshells y sesiones no interactivas
[[ $- != *i* ]] && return 0 2>/dev/null || true

# -----------------------------------------------------------------------------
# 1. GESTIÓN DEL ENTORNO Y RECARGA DE PLASMA / KWIN
# -----------------------------------------------------------------------------
alias plasma-restart='systemctl --user restart plasma-plasmashell.service 2>/dev/null || (kquitapp6 plasmashell 2>/dev/null; kstart plasmashell &>/dev/null &) || true'
alias kwin-reload='qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true'

# -----------------------------------------------------------------------------
# 2. ACCESOS DIRECTOS A PREFERENCIAS DEL SISTEMA DE KDE (systemsettings)
# -----------------------------------------------------------------------------
alias kde-settings='systemsettings &>/dev/null &'
alias kde-conf-display='systemsettings kcm_kscreen &>/dev/null &'
alias kde-conf-audio='systemsettings kcm_pulseaudio &>/dev/null &'
alias kde-conf-sound='systemsettings kcm_pulseaudio &>/dev/null &'
alias kde-conf-bluetooth='systemsettings kcm_bluetooth &>/dev/null &'
alias kde-conf-network='systemsettings kcm_networkmanagement &>/dev/null &'
alias kde-conf-power='systemsettings kcm_powerdevilprofilesconfig &>/dev/null &'
alias kde-conf-shortcuts='systemsettings kcm_keys &>/dev/null &'
alias kde-conf-keyboard='systemsettings kcm_keyboard &>/dev/null &'
alias kde-conf-touchpad='systemsettings kcm_touchpad &>/dev/null &'
alias kde-conf-mouse='systemsettings kcm_mouse &>/dev/null &'
alias kde-conf-printers='systemsettings kcm_printer_manager &>/dev/null &'

# -----------------------------------------------------------------------------
# 3. APLICACIONES NATIVAS DE KDE Y WAYLAND
# -----------------------------------------------------------------------------
if command -v dolphin &>/dev/null; then
    alias files='dolphin . &>/dev/null &'
fi

if command -v kate &>/dev/null; then
    alias text-editor='kate &>/dev/null &'
    alias editor='kate &>/dev/null &'
elif command -v kwrite &>/dev/null; then
    alias text-editor='kwrite &>/dev/null &'
    alias editor='kwrite &>/dev/null &'
fi

if command -v plasma-systemmonitor &>/dev/null; then
    alias sysmon='plasma-systemmonitor &>/dev/null &'
    alias monitor='plasma-systemmonitor &>/dev/null &'
fi

if command -v kcalc &>/dev/null; then
    alias calc='kcalc &>/dev/null &'
fi

# Portapapeles Wayland nativo (wl-clipboard)
if command -v wl-copy &>/dev/null; then
    alias clipcopy='wl-copy'
    alias clippaste='wl-paste'
fi

# -----------------------------------------------------------------------------
# 4. MENSAJE DE CARGA
# -----------------------------------------------------------------------------
[[ $- == *i* ]] && echo "✅ Configuración KDE Plasma cargada (Golden Dog Linux)"

#!/usr/bin/env bash
# ==============================================================================
# virtualization.sh - Instalación y Optimización Avanzada de Virtualización (KVM/QEMU)
# Sistema: Golden Dog Linux (Debian 13 Trixie) | Escritorio: KDE Plasma 6 (Wayland)
# Compatible con CPU/GPU AMD o Intel (3D VirGL / VA-API)
# Almacenamiento: SSD NVMe (Btrfs NoCoW / Ext4) | Firewall: UFW (Nativo)
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "❌ Error: 'sudo' no está disponible y el script no se ejecuta como root."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)
else
    TARGET_USER="${USER:-$(id -un)}"
    TARGET_HOME="${HOME:-$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || true)}"
fi
[ -z "$TARGET_HOME" ] && TARGET_HOME="/home/$TARGET_USER"

run_as_user() {
    if [ "$EUID" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then
        sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" USER="$TARGET_USER" "$@"
    else
        "$@"
    fi
}

WITH_WINDOWS=false
STATUS_ONLY=false
SETUP_BRIDGE=false
USER_ENV_ONLY=false

TUNED_ADM_BIN=$(command -v tuned-adm 2>/dev/null || echo "/usr/sbin/tuned-adm")

# ---------------------------------------------------------------------------
# Funciones de ayuda y utilidades
# ---------------------------------------------------------------------------
show_help() {
    cat <<EOF
Uso: $0 [OPCIONES]

Script de aprovisionamiento y optimización de virtualización KVM/QEMU en Golden Dog Linux (Debian 13 KDE Plasma 6).
Optimizado para sistemas AMD e Intel (KVM/QEMU 10 + Libvirt 11.3 + 3D VirGL + PipeWire).
Proporciona dos vías de gestión completas para desarrollo y producción:
  1. Cockpit Web Console (módulo cockpit-machines en https://localhost:9090)
  2. Virt-Manager (interfaz gráfica de escritorio nativa para KDE Plasma 6 Wayland)

OPCIONES:
  --status, -s, --check Verifica el estado de KVM, Cockpit, libvirt, módulos del kernel,
                        AMD AVIC / Intel EPT, VirGL, Polkit, Btrfs NoCoW, UFW, KSM y red.
  --user-env            Configura únicamente el perfil de usuario sin privilegios root
                        (LIBVIRT_DEFAULT_URI en environment.d/bash/zsh y preferencias de Virt-Manager).
  --with-windows        Descarga los controladores VirtIO para Windows (virtio-win.iso).
  --setup-bridge        Crea un puente de red br0 enlazado a la interfaz Ethernet activa
                        (Opcional; por defecto se mantiene la red NAT virbr0 segura para portátiles).
  -h, --help            Muestra esta ayuda y recomendaciones para VMs Linux/Windows.

CARACTERÍSTICAS Y OPTIMIZACIONES:
  - Doble interfaz de gestión: Cockpit Machines (Web) y Virt-Manager (KDE Plasma Wayland).
  - Aceleración CPU AMD / Intel: AVIC/NPT (AMD) o EPT/VPID/PML (Intel) y Nested KVM.
  - Aceleración Gráfica 3D VirGL: Acceso directo a /dev/dri/renderD128 para usuario y libvirt-qemu.
  - Redirección SPICE USB: Integración completa de spice-client-gtk y gir1.2-spiceclientgtk.
  - Red Virtual NAT limpia: dnsmasq-base integrado en libvirt sin conflicto con systemd-resolved.
  - UFW nativo: Reglas de paso y enrutamiento para virbr0 y puerto 9090/tcp de Cockpit.
  - Almacenamiento NVMe Btrfs NoCoW (+C): Elimina fragmentación de imágenes en /var/lib/libvirt/images.
  - VirtioFS ultrarrápido: Compartición de carpetas host-guest mediante demonio virtiofsd.
  - Deduplicación KSM calibrada: sleep_millisecs=2000 para balancear ahorro de RAM y batería.
  - Regla Polkit sin contraseñas para miembros del grupo 'libvirt'.
  - Conexión por defecto unificada con LIBVIRT_DEFAULT_URI="qemu:///system".

EJEMPLO DE CREACIÓN DE VM LINUX CON ACELERACIÓN 3D (virt-install):
  virt-install \\
    --name debian-test \\
    --memory 4096 \\
    --vcpus 4 \\
    --cpu host-passthrough \\
    --disk size=25,format=qcow2,bus=virtio \\
    --network network=default,model=virtio \\
    --graphics spice,gl=on,listen=none \\
    --video virtio,accel3d=on \\
    --boot uefi \\
    --os-variant debian13
EOF
}

check_status() {
    echo "================================================================="
    echo "🔍 DIAGNÓSTICO DEL ENTORNO DE VIRTUALIZACIÓN (DEBIAN KDE PLASMA 6)"
    echo "================================================================="

    echo -n "• Entorno de Escritorio Host: "
    local desktop="${XDG_CURRENT_DESKTOP:-KDE}"
    local session_type="${XDG_SESSION_TYPE:-wayland}"
    local distro_name="Golden Dog Linux (Debian 13 Trixie)"
    if [ -r /etc/os-release ]; then
        distro_name=$(. /etc/os-release && echo "${PRETTY_NAME:-$NAME}")
    fi
    echo "✅ $distro_name | $desktop ($session_type)"

    echo -n "• Soporte de Virtualización Hardware (CPU): "
    if grep -E -q '(vmx|svm)' /proc/cpuinfo; then
        local cpu_model
        cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
        echo "✅ Detectado ($cpu_model)"
    else
        echo "❌ No detectado o deshabilitado en BIOS/UEFI."
    fi

    echo -n "• Dispositivo /dev/kvm: "
    if [ -e /dev/kvm ]; then
        if [ -w /dev/kvm ]; then
            echo "✅ Accesible con permisos de lectura/escritura"
        else
            echo "⚠️ Presente pero sin permisos de escritura (requiere pertenecer al grupo kvm)"
        fi
    else
        echo "❌ No encontrado."
    fi

    echo -n "• Virtualización Anidada (Nested KVM): "
    if [ -f /sys/module/kvm_amd/parameters/nested ]; then
        local nested_amd
        nested_amd=$(cat /sys/module/kvm_amd/parameters/nested 2>/dev/null || echo "0")
        if [ "$nested_amd" = "1" ] || [ "$nested_amd" = "Y" ]; then
            echo "✅ Activa en AMD (nested=1)"
        else
            echo "ℹ️ Inactiva en AMD (parámetro nested=$nested_amd)"
        fi
    elif [ -f /sys/module/kvm_intel/parameters/nested ]; then
        local nested_intel
        nested_intel=$(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || echo "0")
        if [ "$nested_intel" = "1" ] || [ "$nested_intel" = "Y" ]; then
            echo "✅ Activa en Intel (nested=1)"
        else
            echo "ℹ️ Inactiva en Intel (parámetro nested=$nested_intel)"
        fi
    else
        echo "ℹ️ Módulos KVM no cargados en este momento"
    fi

    if [ -f /sys/module/kvm_amd/parameters/avic ]; then
        echo -n "• Aceleración Hardware AMD (AVIC / NPT): "
        local avic_amd npt_amd
        avic_amd=$(cat /sys/module/kvm_amd/parameters/avic 2>/dev/null || echo "N")
        npt_amd=$(cat /sys/module/kvm_amd/parameters/npt 2>/dev/null || echo "N")
        if { [ "$avic_amd" = "1" ] || [ "$avic_amd" = "Y" ]; } && { [ "$npt_amd" = "1" ] || [ "$npt_amd" = "Y" ]; }; then
            echo "✅ Activa en AMD (avic=$avic_amd, npt=$npt_amd - baja latencia)"
        else
            echo "ℹ️ Parcial/Inactiva (avic=$avic_amd, npt=$npt_amd; se activará con kvm_amd.conf)"
        fi
    elif [ -f /sys/module/kvm_intel/parameters/ept ]; then
        echo -n "• Aceleración Hardware Intel (EPT / VPID / PML): "
        local ept_intel vpid_intel pml_intel
        ept_intel=$(cat /sys/module/kvm_intel/parameters/ept 2>/dev/null || echo "N")
        vpid_intel=$(cat /sys/module/kvm_intel/parameters/vpid 2>/dev/null || echo "N")
        pml_intel=$(cat /sys/module/kvm_intel/parameters/pml 2>/dev/null || echo "N")
        if { [ "$ept_intel" = "1" ] || [ "$ept_intel" = "Y" ]; } && { [ "$vpid_intel" = "1" ] || [ "$vpid_intel" = "Y" ]; }; then
            echo "✅ Activa en Intel (ept=$ept_intel, vpid=$vpid_intel, pml=$pml_intel)"
        else
            echo "ℹ️ Parcial/Inactiva (ept=$ept_intel, vpid=$vpid_intel, pml=$pml_intel)"
        fi
    fi

    echo -n "• Módulos de aceleración de red/kernel: "
    local modules=("vhost_net" "vhost_vsock" "tun")
    local loaded=()
    for mod in "${modules[@]}"; do
        if [ -d "/sys/module/$mod" ] || lsmod | grep -q "^${mod}[[:space:]]"; then
            loaded+=("$mod")
        fi
    done
    echo "${loaded[*]:-Ninguno cargado}"

    echo "• Estado de servicios de Libvirt:"
    local libvirt_state="❌ Inactivo"
    if systemctl is-active --quiet libvirtd 2>/dev/null; then
        libvirt_state="✅ Activo (libvirtd en ejecución)"
    elif systemctl is-active --quiet virtqemud 2>/dev/null; then
        libvirt_state="✅ Activo (virtqemud modular en ejecución)"
    elif systemctl is-active --quiet libvirtd.socket 2>/dev/null || systemctl is-enabled --quiet libvirtd.socket 2>/dev/null || systemctl is-enabled --quiet libvirtd.service 2>/dev/null; then
        libvirt_state="✅ Activo bajo demanda (libvirtd.socket habilitado - 0% consumo en reposo)"
    fi
    echo "  - Servicio libvirt: $libvirt_state"

    echo "• Consola Web Cockpit & Módulo de Máquinas Virtuales:"
    local cockpit_socket_state="❌ Inactivo"
    if systemctl is-active --quiet cockpit.socket 2>/dev/null || ss -tln 2>/dev/null | grep -q ":9090 "; then
        cockpit_socket_state="✅ Activo (escuchando en puerto 9090)"
    elif systemctl is-enabled --quiet cockpit.socket 2>/dev/null; then
        cockpit_socket_state="✅ Habilitado bajo demanda (cockpit.socket - Puerto 9090)"
    fi
    echo "  - Servicio cockpit.socket: $cockpit_socket_state"

    echo -n "  - Módulo cockpit-machines: "
    if [ -d "/usr/share/cockpit/machines" ] || dpkg -s cockpit-machines >/dev/null 2>&1; then
        echo "✅ Instalado y disponible (/usr/share/cockpit/machines)"
    else
        echo "❌ No instalado"
    fi

    if [[ "$cockpit_socket_state" == ✅* ]]; then
        echo "  - Acceso Web Cockpit: 🌐 https://localhost:9090"
    fi

    echo -n "• Aceleración Gráfica 3D VirGL (/dev/dri/renderD128): "
    if [ -e /dev/dri/renderD128 ]; then
        local gpu_name
        gpu_name=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -n1 | cut -d: -f3 | xargs || echo "GPU Mesa")
        echo "✅ Disponible ($gpu_name - Nodo DRM render)"
    else
        echo "ℹ️ No disponible"
    fi

    if id libvirt-qemu >/dev/null 2>&1; then
        echo -n "• Permisos de GPU del daemon QEMU (libvirt-qemu): "
        local qemu_groups
        qemu_groups=$(id -Gn libvirt-qemu 2>/dev/null || true)
        if [[ "$qemu_groups" =~ (^|[[:space:]])render($|[[:space:]]) ]] && [[ "$qemu_groups" =~ (^|[[:space:]])kvm($|[[:space:]]) ]]; then
            echo "✅ render, kvm (aceleración 3D habilitada)"
        else
            echo "⚠️ Incompleto ($qemu_groups) - requiere pertenencia a 'render' y 'kvm'"
        fi
    fi

    echo -n "• Estado de la red virtual 'default': "
    if ip link show virbr0 >/dev/null 2>&1; then
        echo "✅ Activa (interfaz virbr0 levantada)"
    elif [ -L /etc/libvirt/qemu/networks/autostart/default.xml ] || [ -f /etc/libvirt/qemu/networks/autostart/default.xml ]; then
        echo "✅ Configurada con autostart (virbr0 se levantará al iniciar libvirt)"
    elif command -v virsh >/dev/null 2>&1 && timeout 2 virsh -c qemu:///system net-info default >/dev/null 2>&1; then
        echo "✅ Activa (registrada en libvirt)"
    else
        echo "⚠️ No configurada aún (se creará automáticamente)"
    fi

    echo -n "• Backend de Firewall Libvirt: "
    if [ -r /etc/libvirt/network.conf ] && grep -qE '^[[:space:]]*firewall_backend[[:space:]]*=[[:space:]]*"nftables"' /etc/libvirt/network.conf 2>/dev/null; then
        echo "✅ nftables nativo (/etc/libvirt/network.conf)"
    else
        echo "ℹ️ Por defecto / pendiente de ajustar a nftables"
    fi

    echo -n "• Integración con UFW:       "
    if command -v ufw >/dev/null 2>&1 && { systemctl is-active --quiet ufw 2>/dev/null || { [ -r /etc/ufw/ufw.conf ] && grep -q "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null; }; }; then
        echo "✅ Activo (reglas virbr0 / Cockpit verificables con sudo ufw status)"
    else
        echo "ℹ️ UFW no activo o no disponible"
    fi

    echo -n "• Deduplicación de Memoria (KSM): "
    if [ -f /sys/kernel/mm/ksm/run ]; then
        local ksm_val
        ksm_val=$(cat /sys/kernel/mm/ksm/run 2>/dev/null || echo "0")
        if [ "$ksm_val" = "1" ]; then
            local ksm_sleep
            ksm_sleep=$(cat /sys/kernel/mm/ksm/sleep_millisecs 2>/dev/null || echo "2000")
            echo "✅ Activa (sleep_millisecs=${ksm_sleep}ms, optimizada para batería)"
        else
            echo "ℹ️ Inactiva (/sys/kernel/mm/ksm/run=$ksm_val)"
        fi
    else
        echo "ℹ️ No soportado por el kernel"
    fi

    echo -n "• Almacenamiento VM (/var/lib/libvirt/images): "
    if [ -d /var/lib/libvirt/images ]; then
        local fs_type acl_status=""
        fs_type=$(stat -f -c %T /var/lib/libvirt/images 2>/dev/null || true)
        if command -v getfacl >/dev/null 2>&1 && getfacl -n /var/lib/libvirt/images 2>/dev/null | grep -q "^user:$(id -u "$TARGET_USER" 2>/dev/null || echo 1000):rwx"; then
            acl_status=", ACL rwx activa para $TARGET_USER"
        fi
        if [ "$fs_type" = "btrfs" ]; then
            if lsattr -d /var/lib/libvirt/images 2>/dev/null | grep -q 'C'; then
                echo "✅ Btrfs NoCoW (+C activo, optimizado para IOPS NVMe${acl_status})"
            else
                echo "⚠️ Btrfs con Copy-on-Write activo (se recomienda aplicar chattr +C${acl_status})"
            fi
        else
            echo "✅ Presente (${fs_type}${acl_status})"
        fi
    else
        echo "ℹ️ Pendiente de creación"
    fi

    echo -n "• Regla Polkit sin contraseñas para libvirt: "
    if [ -f /etc/polkit-1/rules.d/50-libvirt.rules ] || { sudo -n test -f /etc/polkit-1/rules.d/50-libvirt.rules 2>/dev/null; }; then
        echo "✅ Presente (/etc/polkit-1/rules.d/50-libvirt.rules)"
    elif [ -f /usr/share/polkit-1/rules.d/60-libvirt.rules ]; then
        echo "✅ Activa nativa de Debian 13 (/usr/share/polkit-1/rules.d/60-libvirt.rules)"
    else
        echo "⚠️ No configurada"
    fi

    echo -n "• Pertenencia a grupos requeridos ($TARGET_USER): "
    local user_groups
    user_groups=$(id -Gn "$TARGET_USER" 2>/dev/null || true)
    local has_libvirt=false
    local has_kvm=false
    local has_render=false
    [[ "$user_groups" =~ (^|[[:space:]])libvirt($|[[:space:]]) ]] && has_libvirt=true
    [[ "$user_groups" =~ (^|[[:space:]])kvm($|[[:space:]]) ]] && has_kvm=true
    [[ "$user_groups" =~ (^|[[:space:]])render($|[[:space:]]) ]] && has_render=true

    if [ "$has_libvirt" = true ] && [ "$has_kvm" = true ] && [ "$has_render" = true ]; then
        echo "✅ libvirt, kvm, render"
    else
        echo "⚠️ Incompleto ($user_groups)."
    fi

    echo -n "• Herramientas de escritorio/UEFI/TPM/FS: "
    local tools_ok=()
    command -v virt-manager >/dev/null 2>&1 && tools_ok+=("virt-manager")
    dpkg -s ovmf >/dev/null 2>&1 && tools_ok+=("ovmf")
    command -v swtpm >/dev/null 2>&1 && tools_ok+=("swtpm")
    (command -v virtiofsd >/dev/null 2>&1 || [ -x /usr/libexec/virtiofsd ]) && tools_ok+=("virtiofsd")
    command -v passt >/dev/null 2>&1 && tools_ok+=("passt")
    echo "${tools_ok[*]:-Pendiente de instalación}"

    echo -n "• URI por defecto (environment.d): "
    if [ -f "$TARGET_HOME/.config/environment.d/10-libvirt.conf" ]; then
        echo "✅ qemu:///system ($TARGET_HOME/.config/environment.d/10-libvirt.conf)"
    else
        echo "ℹ️ No configurado (ejecuta '$0 --user-env' o '$0')"
    fi

    if command -v gsettings >/dev/null 2>&1; then
        echo -n "• Perfil Virt-Manager (KDE Wayland): "
        local vm_uris
        vm_uris=$(run_as_user gsettings get org.virt-manager.virt-manager.connections uris 2>/dev/null || true)
        if [[ "$vm_uris" == *"qemu:///system"* ]]; then
            echo "✅ Auto-conexión qemu:///system, editor XML, CPU host-passthrough y gráficas activas"
        else
            echo "ℹ️ Por defecto"
        fi
    fi

    echo "================================================================="
}

configure_user_desktop() {
    echo "ℹ️ Configurando entorno de usuario ($TARGET_USER) para Libvirt y Virt-Manager en KDE Plasma 6..."

    run_as_user mkdir -p "$TARGET_HOME/.config/environment.d"
    cat <<EOF | run_as_user tee "$TARGET_HOME/.config/environment.d/10-libvirt.conf" > /dev/null
LIBVIRT_DEFAULT_URI=qemu:///system
EOF

    run_as_user mkdir -p "$TARGET_HOME/.bashrc.d"
    cat <<EOF | run_as_user tee "$TARGET_HOME/.bashrc.d/virtualization.sh" > /dev/null
# Configuración KVM/QEMU conectando al daemon de sistema por defecto
export LIBVIRT_DEFAULT_URI="qemu:///system"
EOF

    if [ -f "$TARGET_HOME/.zshrc" ] || [ -d "$TARGET_HOME/.zshrc.d" ]; then
        run_as_user mkdir -p "$TARGET_HOME/.zshrc.d"
        cat <<EOF | run_as_user tee "$TARGET_HOME/.zshrc.d/virtualization.zsh" > /dev/null
# Configuración KVM/QEMU conectando al daemon de sistema por defecto
export LIBVIRT_DEFAULT_URI="qemu:///system"
EOF
    fi

    # Optimizar preferencias de Virt-Manager (dconf/gsettings) para KDE Plasma 6 Wayland
    if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas 2>/dev/null | grep -qx "org.virt-manager.virt-manager"; then
        run_as_user gsettings set org.virt-manager.virt-manager.connections uris "['qemu:///system']" 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager.connections autoconnect "['qemu:///system']" 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager xmleditor-enabled true 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager.new-vm cpu-default "'host-passthrough'" 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager.console resize-guest 1 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager.stats enable-cpu-poll true 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager.stats enable-memory-poll true 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager.stats enable-disk-poll true 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager.stats enable-net-poll true 2>/dev/null || true
        run_as_user gsettings set org.virt-manager.virt-manager.vmlist-fields memory-usage true 2>/dev/null || true
        echo "  ✅ Preferencias de Virt-Manager optimizadas (qemu:///system, editor XML, CPU host-passthrough, telemetría)."
    fi
}

for arg in "$@"; do
    case "$arg" in
        --status|-s|--check)
            STATUS_ONLY=true
            ;;
        --user-env)
            USER_ENV_ONLY=true
            ;;
        --with-windows)
            WITH_WINDOWS=true
            ;;
        --setup-bridge)
            SETUP_BRIDGE=true
            ;;
        -h|--help|help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Opción desconocida: $arg"
            show_help
            exit 1
            ;;
    esac
done

if [ "$STATUS_ONLY" = true ]; then
    check_status
    exit 0
fi

if [ "$USER_ENV_ONLY" = true ]; then
    configure_user_desktop
    exit 0
fi

echo "🚀 Iniciando configuración y optimización de virtualización KVM/QEMU en Debian GNU/Linux..."
echo "🎯 Integrando Cockpit Machines (Web) y Virt-Manager (KDE Plasma 6 Wayland)..."

# ---------------------------------------------------------------------------
# 1. Instalación de paquetes vía APT
# ---------------------------------------------------------------------------
echo "ℹ️ [1/13] Verificando e instalando paquetes oficiales para Debian..."

PKGS_TO_INSTALL=(
    # Hipervisor base y emulación (QEMU 10 en Debian 13 con módulos OpenGL VirGL, GUI/PipeWire y SPICE)
    qemu-system-x86
    qemu-utils
    qemu-system-gui
    qemu-system-modules-opengl
    qemu-system-modules-spice
    qemu-block-extra
    # Daemons de libvirt, configuración de red/filtros, D-Bus y herramientas CLI
    libvirt-daemon-system
    libvirt-daemon-config-network
    libvirt-daemon-config-nwfilter
    libvirt-dbus
    libvirt-clients
    # Interfaces gráficas y gestión (virt-install reemplaza al paquete transicional virtinst en Debian 13)
    virt-manager
    virt-viewer
    virt-install
    virt-top
    # Consola Web Cockpit y gestión de VMs
    cockpit
    cockpit-machines
    cockpit-bridge
    cockpit-ws
    cockpit-system
    # Firmware UEFI y emulación TPM 2.0 (Windows 11 / Linux Secure Boot)
    ovmf
    swtpm
    swtpm-tools
    # Herramientas de inspección de discos y metadatos de SO
    libguestfs-tools
    guestfs-tools
    libosinfo-bin
    # Compartición ultrarrápida host-guest mediante virtio-fs y red user-mode passt
    virtiofsd
    passt
    # Integración SPICE y redirección USB con helper Polkit para Virt-Manager en KDE Wayland
    spice-vdagent
    spice-client-gtk
    spice-client-glib-usb-acl-helper
    gir1.2-spiceclientgtk-3.0
    # Red virtual Libvirt (dnsmasq-base evita conflictos con systemd-resolved)
    dnsmasq-base
    iptables
    nftables
    # ACLs
    acl
)

# En portátiles KDE con power-profiles-daemon evitamos instalar tuned para no interferir con PowerDevil
if ! systemctl is-active --quiet power-profiles-daemon 2>/dev/null && ! dpkg -s power-profiles-daemon >/dev/null 2>&1; then
    PKGS_TO_INSTALL+=(tuned)
fi

MISSING_PKGS=()
for pkg in "${PKGS_TO_INSTALL[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
    echo "  📦 Instalando ${#MISSING_PKGS[@]} paquete(s) pendiente(s): ${MISSING_PKGS[*]}"
    $SUDO apt-get update -qq
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${MISSING_PKGS[@]}"
else
    echo "  ✅ Todos los paquetes requeridos ya están instalados."
fi

# ---------------------------------------------------------------------------
# 2. Controladores VirtIO para Windows (Opcional)
# ---------------------------------------------------------------------------
if [ "$WITH_WINDOWS" = true ]; then
    echo "ℹ️ [2/13] Descargando controladores VirtIO para Windows..."
    DOWNLOAD_DIR=""
    if command -v xdg-user-dir >/dev/null 2>&1; then
        DOWNLOAD_DIR=$(run_as_user xdg-user-dir DOWNLOAD 2>/dev/null || true)
    fi
    if [ -z "$DOWNLOAD_DIR" ] || [ ! -d "$DOWNLOAD_DIR" ]; then
        if [ -d "$TARGET_HOME/Descargas" ]; then
            DOWNLOAD_DIR="$TARGET_HOME/Descargas"
        elif [ -d "$TARGET_HOME/Downloads" ]; then
            DOWNLOAD_DIR="$TARGET_HOME/Downloads"
        else
            DOWNLOAD_DIR="$TARGET_HOME/Descargas"
        fi
    fi

    VIRTIO_DIR="$DOWNLOAD_DIR/virtio-drivers"
    run_as_user mkdir -p "$VIRTIO_DIR"
    if [ ! -f "$VIRTIO_DIR/virtio-win.iso" ]; then
        echo "⬇️ Descargando virtio-win.iso en $VIRTIO_DIR..."
        VIRTIO_TMP="$VIRTIO_DIR/virtio-win.iso.part"
        if run_as_user curl -fsSL -o "$VIRTIO_TMP" "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"; then
            run_as_user mv -f "$VIRTIO_TMP" "$VIRTIO_DIR/virtio-win.iso"
            echo "  ✅ virtio-win.iso descargado en $VIRTIO_DIR/virtio-win.iso"
        else
            rm -f "$VIRTIO_TMP"
            echo "  ⚠️ No se pudo descargar virtio-win.iso (verifica tu conexión a Internet)."
        fi
    else
        echo "  ✅ virtio-win.iso ya existe en $VIRTIO_DIR/virtio-win.iso"
    fi
else
    echo "ℹ️ [2/13] Omitiendo descarga de drivers Windows (usar --with-windows para activarla)."
fi

# ---------------------------------------------------------------------------
# 3. Módulos del Kernel y Virtualización Anidada (Nested KVM + AVIC)
# ---------------------------------------------------------------------------
echo "ℹ️ [3/13] Configurando optimizaciones de CPU y virtualización anidada..."
$SUDO mkdir -p /etc/modprobe.d /etc/modules-load.d

reload_kvm_module() {
    local mod="$1"
    if lsmod | grep -q "^${mod}[[:space:]]"; then
        if $SUDO modprobe -r "$mod" kvm 2>/dev/null; then
            $SUDO modprobe "$mod" 2>/dev/null || true
            echo "  ✅ Módulo $mod recargado con los nuevos parámetros."
        else
            echo "  ℹ️ $mod está en uso actualmente; los parámetros se aplicarán al reiniciar."
        fi
    else
        $SUDO modprobe "$mod" 2>/dev/null || true
    fi
}

CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}' || true)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    if [ -x "$REPO_ROOT/Setup/amd-setup.sh" ]; then
        bash "$REPO_ROOT/Setup/amd-setup.sh" --kvm
    else
        echo "  • Optimizando KVM para AMD (nested=1, avic=1, npt=1)..."
        cat <<EOF | $SUDO tee /etc/modprobe.d/kvm_amd.conf > /dev/null
# Configuración KVM para procesadores AMD
options kvm_amd nested=1 avic=1 npt=1
EOF
        reload_kvm_module "kvm_amd"
    fi
elif [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    if [ -x "$REPO_ROOT/Setup/intel-setup.sh" ]; then
        bash "$REPO_ROOT/Setup/intel-setup.sh" --kvm
    else
        echo "  • Optimizando KVM para Intel (nested=1, ept=1, vpid=1, pml=1)..."
        cat <<EOF | $SUDO tee /etc/modprobe.d/kvm_intel.conf > /dev/null
# Configuración KVM para procesadores Intel
options kvm_intel nested=1 ept=1 vpid=1 pml=1
EOF
        reload_kvm_module "kvm_intel"
    fi
fi

echo "  • Habilitando módulos de aceleración en el kernel (vhost_net, vhost_vsock, tun)..."
cat <<EOF | $SUDO tee /etc/modules-load.d/kvm-vhost.conf > /dev/null
vhost_net
vhost_vsock
tun
EOF
$SUDO modprobe vhost_net 2>/dev/null || true
$SUDO modprobe vhost_vsock 2>/dev/null || true
$SUDO modprobe tun 2>/dev/null || true

# ---------------------------------------------------------------------------
# 4. Ajustes de /etc/libvirt/qemu.conf y Permisos de GPU (3D VirGL)
# ---------------------------------------------------------------------------
echo "ℹ️ [4/13] Configurando permisos, propiedad dinámica y aceleración GPU 3D en libvirt..."
$SUDO mkdir -p /etc/libvirt
LIBVIRT_RESTART_NEEDED=false

set_libvirt_kv() {
    local file="$1"
    local key="$2"
    local value="$3"
    if [ -f "$file" ]; then
        if grep -qE "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*${value}([[:space:]]*$|#)" "$file"; then
            return 0
        fi
        if grep -qE "^#?[[:space:]]*${key}[[:space:]]*=" "$file"; then
            $SUDO sed -i -E "s|^#?[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
        else
            echo "${key} = ${value}" | $SUDO tee -a "$file" > /dev/null
        fi
    else
        echo "${key} = ${value}" | $SUDO tee "$file" > /dev/null
    fi
    LIBVIRT_RESTART_NEEDED=true
}

set_libvirt_kv "/etc/libvirt/qemu.conf" "dynamic_ownership" "1"
set_libvirt_kv "/etc/libvirt/qemu.conf" "remember_owner" "1"

# Añadir el usuario daemon libvirt-qemu al grupo render para permitir VirGL 3D
if id libvirt-qemu >/dev/null 2>&1; then
    $SUDO usermod -aG render,kvm libvirt-qemu 2>/dev/null || true
    echo "  ✅ libvirt-qemu añadido a los grupos 'render' y 'kvm' para aceleración VirGL."
fi

# ---------------------------------------------------------------------------
# 5. Backend de Firewall y Reglas UFW (nftables + Cockpit)
# ---------------------------------------------------------------------------
echo "ℹ️ [5/13] Configurando backend de red en libvirt e integrando con UFW..."

set_libvirt_kv "/etc/libvirt/network.conf" "firewall_backend" "\"nftables\""

if command -v ufw >/dev/null 2>&1 && (systemctl is-active --quiet ufw 2>/dev/null || { [ -r /etc/ufw/ufw.conf ] && grep -q "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null; } || $SUDO ufw status 2>/dev/null | grep -qi "Status: active"); then
    $SUDO ufw allow 9090/tcp comment 'Cockpit Web Console' 2>/dev/null || true
    $SUDO ufw allow in on virbr0 2>/dev/null || true
    $SUDO ufw route allow in on virbr0 2>/dev/null || true
    $SUDO ufw route allow out on virbr0 2>/dev/null || true
    $SUDO ufw reload 2>/dev/null || true
    echo "  ✅ Reglas de UFW aplicadas (Cockpit 9090/tcp, virbr0 permitido y enrutado)."
fi

# ---------------------------------------------------------------------------
# 6. Regla Polkit sin contraseñas para el grupo 'libvirt'
# ---------------------------------------------------------------------------
echo "ℹ️ [6/13] Configurando regla Polkit para administración local sin contraseña..."
$SUDO mkdir -p /etc/polkit-1/rules.d
cat <<EOF | $SUDO tee /etc/polkit-1/rules.d/50-libvirt.rules > /dev/null
/* Permitir a usuarios en el grupo libvirt gestionar la virtualización sin pedir contraseña */
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.libvirt") === 0 && subject.isInGroup("libvirt")) {
        return polkit.Result.YES;
    }
});
EOF
$SUDO chmod 644 /etc/polkit-1/rules.d/50-libvirt.rules

# ---------------------------------------------------------------------------
# 7. Verificación de capacidades KVM del Host
# ---------------------------------------------------------------------------
echo "ℹ️ [7/13] Validando capacidades de virtualización del hardware..."
virt-host-validate qemu || echo "  ⚠️ Nota: Si alguna comprobación falla, verifica que la virtualización esté activa en tu BIOS/UEFI."

# ---------------------------------------------------------------------------
# 8. Activación de Servicios de Libvirt y Cockpit
# ---------------------------------------------------------------------------
echo "ℹ️ [8/13] Habilitando servicios y sockets bajo demanda de Libvirt y Cockpit..."
LIBVIRT_SVC="libvirtd"
if systemctl is-enabled --quiet virtqemud 2>/dev/null || systemctl is-active --quiet virtqemud 2>/dev/null; then
    LIBVIRT_SVC="virtqemud"
fi

if [ "$LIBVIRT_SVC" = "libvirtd" ]; then
    $SUDO systemctl enable --now libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket 2>/dev/null || true
fi

if systemctl is-active --quiet "$LIBVIRT_SVC" 2>/dev/null; then
    if [ "$LIBVIRT_RESTART_NEEDED" = true ]; then
        $SUDO systemctl restart "$LIBVIRT_SVC" 2>/dev/null || true
    fi
else
    $SUDO systemctl enable --now "$LIBVIRT_SVC" 2>/dev/null || true
fi
$SUDO systemctl enable --now cockpit.socket 2>/dev/null || true

# ---------------------------------------------------------------------------
# 9. Configuración de Red Virtual NAT y Storage Pool (/var/lib/libvirt/images)
# ---------------------------------------------------------------------------
echo "ℹ️ [9/13] Configurando red virtual NAT por defecto (virbr0)..."
if command -v virsh >/dev/null 2>&1; then
    if ! $SUDO virsh net-info default >/dev/null 2>&1 && [ -f /usr/share/libvirt/networks/default.xml ]; then
        $SUDO virsh net-define /usr/share/libvirt/networks/default.xml 2>/dev/null || true
    fi
    $SUDO virsh net-start default 2>/dev/null || true
    $SUDO virsh net-autostart default 2>/dev/null || true
fi

echo "ℹ️ [9/13] Configurando almacenamiento de imágenes en NVMe (/var/lib/libvirt/images)..."
$SUDO mkdir -p /var/lib/libvirt/images

FS_TYPE=$(stat -f -c %T /var/lib/libvirt/images 2>/dev/null || true)
if [ "$FS_TYPE" = "btrfs" ]; then
    echo "  ⚡ Btrfs detectado en /var/lib/libvirt/images: aplicando atributo NoCoW (+C)..."
    $SUDO chattr +C /var/lib/libvirt/images 2>/dev/null || true
fi

# Asegurar que el pool de almacenamiento 'default' está definido y activo en libvirt
if command -v virsh >/dev/null 2>&1; then
    if ! $SUDO virsh pool-info default >/dev/null 2>&1; then
        $SUDO virsh pool-define-as default dir --target /var/lib/libvirt/images 2>/dev/null || true
        $SUDO virsh pool-build default 2>/dev/null || true
        echo "  ✅ Pool de almacenamiento 'default' definido en /var/lib/libvirt/images."
    fi
    $SUDO virsh pool-start default 2>/dev/null || true
    $SUDO virsh pool-autostart default 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 10. Configuración de Red: Detección Segura de Interfaz (Cableada vs Wi-Fi)
# ---------------------------------------------------------------------------
echo "ℹ️ [10/13] Analizando conectividad de red del host..."
PHYS_IFACE=$(ip -o route show default 2>/dev/null | awk '{print $5; exit}' || true)

is_wireless() {
    local iface="$1"
    [ -z "$iface" ] && return 1
    [[ "$iface" =~ ^wl ]] && return 0
    [ -d "/sys/class/net/$iface/wireless" ] && return 0
    if command -v iw >/dev/null 2>&1; then
        iw dev "$iface" info >/dev/null 2>&1 && return 0
    fi
    return 1
}

if [ "$SETUP_BRIDGE" = true ]; then
    if [ -n "$PHYS_IFACE" ]; then
        if is_wireless "$PHYS_IFACE"; then
            echo "  ⚠️ Interfaz inalámbrica detectada ('$PHYS_IFACE'). Los puentes br0 directos no son compatibles con Wi-Fi estándar 802.11."
            echo "  🛡️ Se mantiene la red virtual NAT 'virbr0' recomendada."
        elif [ "$PHYS_IFACE" != "br0" ]; then
            echo "  • Configurando bridge br0 sobre interfaz Ethernet $PHYS_IFACE..."
            if command -v nmcli >/dev/null 2>&1; then
                if ! nmcli con show br0 >/dev/null 2>&1; then
                    $SUDO nmcli con add type bridge ifname br0 con-name br0 2>/dev/null || true
                    $SUDO nmcli con add type bridge-slave ifname "$PHYS_IFACE" con-name br0-port master br0 2>/dev/null || true
                    $SUDO nmcli con modify br0 ipv4.method auto 2>/dev/null || true
                    $SUDO nmcli con up br0 2>/dev/null || true

                    TMP_BRIDGE_XML=$(mktemp)
                    cat <<EOF > "$TMP_BRIDGE_XML"
<network>
  <name>host-bridge</name>
  <forward mode='bridge'/>
  <bridge name='br0'/>
</network>
EOF
                    $SUDO virsh net-define "$TMP_BRIDGE_XML" 2>/dev/null || true
                    $SUDO virsh net-start host-bridge 2>/dev/null || true
                    $SUDO virsh net-autostart host-bridge 2>/dev/null || true
                    rm -f "$TMP_BRIDGE_XML"
                    echo "  ✅ Bridge br0 creado y registrado en libvirt como 'host-bridge'."
                else
                    echo "  ℹ️ Bridge br0 ya existente en NetworkManager."
                fi
            fi
        fi
    fi
else
    echo "  🛡️ Modo portátil seguro: Se mantiene la red NAT virtual 'virbr0' (utiliza '--setup-bridge' si requieres bridge directo en la interfaz Ethernet)."
fi

# ---------------------------------------------------------------------------
# 11. Optimización de Memoria (KSM) y Perfiles de Energía
# ---------------------------------------------------------------------------
echo "ℹ️ [11/13] Configurando deduplicación de memoria RAM (KSM) y gestión de energía..."
$SUDO mkdir -p /etc/tmpfiles.d

cat <<EOF | $SUDO tee /etc/tmpfiles.d/ksm.conf > /dev/null
# Deduplicación de páginas de memoria RAM compartidas entre VMs KVM
# sleep_millisecs=2000 optimizado para preservar batería en portátiles
w /sys/kernel/mm/ksm/run - - - - 1
w /sys/kernel/mm/ksm/sleep_millisecs - - - - 2000
w /sys/kernel/mm/ksm/pages_to_scan - - - - 100
EOF

if [ -d /sys/kernel/mm/ksm ]; then
    echo 1 | $SUDO tee /sys/kernel/mm/ksm/run > /dev/null 2>&1 || true
    echo 2000 | $SUDO tee /sys/kernel/mm/ksm/sleep_millisecs > /dev/null 2>&1 || true
    echo 100 | $SUDO tee /sys/kernel/mm/ksm/pages_to_scan > /dev/null 2>&1 || true
fi

if systemctl is-active --quiet power-profiles-daemon 2>/dev/null || dpkg -s power-profiles-daemon >/dev/null 2>&1; then
    echo "  ⚡ power-profiles-daemon detectado (KDE PowerDevil): preservando gestión de energía nativa de KDE Plasma 6."
elif [ -x "$TUNED_ADM_BIN" ]; then
    $SUDO systemctl enable --now tuned.service 2>/dev/null || true
    $SUDO "$TUNED_ADM_BIN" profile virtual-host 2>/dev/null || true
    echo "  ✅ Perfil Tuned 'virtual-host' aplicado."
fi

# ---------------------------------------------------------------------------
# 12. Permisos de Usuario, Grupos (libvirt, kvm, render) y ACLs de Acceso ISO
# ---------------------------------------------------------------------------
echo "ℹ️ [12/13] Configurando grupos de usuario (libvirt, kvm, render) y ACLs para $TARGET_USER..."
$SUDO usermod -aG libvirt,kvm,render "$TARGET_USER" 2>/dev/null || $SUDO usermod -aG libvirt,kvm "$TARGET_USER" 2>/dev/null || true

$SUDO setfacl -m u:"$TARGET_USER":rwX /var/lib/libvirt/images 2>/dev/null || true
$SUDO setfacl -d -m u:"$TARGET_USER":rwX /var/lib/libvirt/images 2>/dev/null || true

# Permitir que libvirt-qemu atraviese el directorio home del usuario para montar ISOs desde ~/Descargas en Virt-Manager/Cockpit
if id libvirt-qemu >/dev/null 2>&1 && [ -d "$TARGET_HOME" ]; then
    $SUDO setfacl -m u:libvirt-qemu:x "$TARGET_HOME" 2>/dev/null || true
    for iso_dir in "$TARGET_HOME/Descargas" "$TARGET_HOME/Downloads"; do
        if [ -d "$iso_dir" ]; then
            $SUDO setfacl -m u:libvirt-qemu:rx "$iso_dir" 2>/dev/null || true
        fi
    done
fi

# ---------------------------------------------------------------------------
# 13. Variable de Entorno LIBVIRT_DEFAULT_URI y Perfil Virt-Manager (KDE)
# ---------------------------------------------------------------------------
echo "ℹ️ [13/13] Configurando LIBVIRT_DEFAULT_URI y preferencias de Virt-Manager en el perfil de $TARGET_USER..."
configure_user_desktop

HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -n1 || echo '127.0.0.1')
echo "================================================================="
echo "✅ Entorno de Virtualización KVM/QEMU Configurado con Éxito"
echo "================================================================="
echo "🌐 1. CONSOLA WEB COCKPIT: https://$HOST_IP:9090 (o https://localhost:9090)"
echo "🖥️ 2. VIRT-MANAGER: Ejecuta 'virt-manager' en terminal o lanzador de aplicaciones KDE."
echo "================================================================="
echo "⚠️ IMPORTANTE: Si es la primera vez que añades los grupos, cierra sesión"
echo "   y vuelve a iniciarla (o ejecuta 'newgrp libvirt') para aplicarlos."
echo "================================================================="

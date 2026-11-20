# Manual de Virtualización de Alto Rendimiento (KVM/QEMU) en Debian 13 (Trixie)

> [!TIP]
> **¿Prefieres hacerlo automáticamente?** Ejecuta `./Virtualizacion/virtualization.sh` (o `just virtualization` desde la raíz) para aplicar toda esta configuración de forma segura e idempotente. Estas notas resumen qué hace el sistema paso a paso.

---

## 1. Instalación de Paquetes
Instalamos QEMU, Libvirt, Virt-Manager, Cockpit Machines, firmware UEFI (OVMF) con soporte TPM 2.0 (`swtpm`), `virtiofsd`, `passt` y dependencias SPICE/OpenGL:

```bash
sudo apt update
sudo apt install -y \
    qemu-system-x86 qemu-utils qemu-system-gui qemu-system-modules-opengl qemu-system-modules-spice qemu-block-extra \
    libvirt-daemon-system libvirt-daemon-config-network libvirt-daemon-config-nwfilter libvirt-dbus libvirt-clients \
    virt-manager virt-viewer virt-install virt-top \
    cockpit cockpit-machines cockpit-bridge cockpit-ws cockpit-system \
    ovmf swtpm swtpm-tools libguestfs-tools guestfs-tools libosinfo-bin \
    virtiofsd passt spice-vdagent spice-client-gtk spice-client-glib-usb-acl-helper gir1.2-spiceclientgtk-3.0 \
    dnsmasq-base iptables nftables acl
```

---

## 2. Aceleración del Kernel y Virtualización Anidada (Nested KVM)

### Virtualización Anidada y Flags de CPU:
- **AMD**: `/etc/modprobe.d/kvm_amd.conf` -> `options kvm_amd nested=1 avic=1 npt=1`
- **Intel**: `/etc/modprobe.d/kvm_intel.conf` -> `options kvm_intel nested=1 ept=1 vpid=1 pml=1`

### Aceleración de Red y Sockets del Kernel (`vhost_net`, `vhost_vsock`, `tun`):
```bash
cat <<EOF | sudo tee /etc/modules-load.d/kvm-vhost.conf
vhost_net
vhost_vsock
tun
EOF
sudo modprobe vhost_net vhost_vsock tun
```

---

## 3. Permisos QEMU, Aceleración 3D VirGL y PipeWire (`/etc/libvirt/qemu.conf`)
En Debian 13 con KDE Plasma 6 Wayland, `virtualization.sh` mantiene la gestión dinámica de permisos y añade `libvirt-qemu` a `render` y `kvm`:
```ini
dynamic_ownership = 1
remember_owner = 1
```
```bash
sudo usermod -aG render,kvm libvirt-qemu
```

---

## 4. Backend de Firewall Nftables en Debian 13 (`/etc/libvirt/network.conf`)
Configurado para usar `nftables` nativo en lugar de legacy iptables:
```ini
firewall_backend = "nftables"
```

---

## 5. Controladores VirtIO para Windows (`virtio-win.iso`)
Con `--with-windows`, descarga la ISO estable más reciente del proyecto Fedora en `~/Descargas/virtio-drivers/virtio-win.iso`:
```bash
curl -fsSL -o ~/Descargas/virtio-drivers/virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

---

## 6. Servicios, Polkit, KSM y Energía
- **Sockets y servicios**: `libvirtd.socket`, `libvirtd-ro.socket`, `libvirtd-admin.socket`, `libvirtd` (o `virtqemud` si ya estaba activo) y `cockpit.socket` (puerto `9090`).
- **Energía**: Si `power-profiles-daemon` no está activo, se instala `tuned` con perfil `virtual-host`.
- **Polkit sin contraseñas**: `/etc/polkit-1/rules.d/50-libvirt.rules` para el grupo `libvirt`.
- **KSM**: `/etc/tmpfiles.d/ksm.conf` (`run=1`, `sleep_millisecs=2000`, `pages_to_scan=100`).

---

## 7. Permisos de Usuario, Btrfs NoCoW y Directorio de Imágenes (ACL)

```bash
sudo usermod -aG libvirt,kvm,render $USER
sudo setfacl -R -m u:$USER:rwX /var/lib/libvirt/images
sudo setfacl -d -m u:$USER:rwX /var/lib/libvirt/images
export LIBVIRT_DEFAULT_URI="qemu:///system"
```
*(Si `/var/lib/libvirt/images` está en Btrfs, `virtualization.sh` también aplica `sudo chattr +C` para desactivar CoW en las imágenes `qcow2`.)*

---
> [!IMPORTANT]
> Recuerda reiniciar la sesión o el equipo tras la instalación para aplicar los grupos `libvirt`, `kvm` y `render` a tu usuario.

---
sidebar_position: 7
---

# Entorno de Virtualización (KVM/QEMU) en Debian GNU/Linux (KDE Plasma 6)

Esta guía explica de forma sencilla cómo instalar y usar máquinas virtuales nativas en **Golden Dog Linux (Debian 13)** con **KDE Plasma 6 (Wayland)** usando el script [`Virtualizacion/virtualization.sh`](../Virtualizacion/virtualization.sh).

> [!NOTE]
> **¿Qué es KVM/QEMU? (Explicado para principiantes)**
> Una **máquina virtual (VM)** te permite ejecutar otro sistema operativo (como Windows o Linux) dentro de una ventana de tu propio ordenador.
> - **KVM** permite usar tu procesador físico directamente para que la máquina virtual vaya casi igual de rápida que un PC real.
> - **QEMU** emula el resto del ordenador (pantalla 3D, tarjeta de red, disco duro, chip TPM 2.0 para Windows 11).
> - **Libvirt** es el servicio en segundo plano que coordina todo, y puedes manejarlo desde dos interfaces gráficas:
>   1. **Virt-Manager**: Aplicación de escritorio clásica con control total de hardware y aceleración 3D VirGL.
>   2. **Cockpit Machines**: Panel web moderno en `https://localhost:9090` (incluye soporte con `just cockpit`).

---

## 1. Instalación y Pila de Paquetes (`virtualization.sh`)

Instala KVM, QEMU, Libvirt, Virt-Manager, Cockpit Machines, firmware UEFI (`ovmf`), chip TPM 2.0 (`swtpm`), `virtiofsd` (carpetas compartidas rápidas), `passt` (red sin privilegios) y librerías gráficas SPICE/OpenGL:

```bash
just virtualization
```

> [!IMPORTANT]
> **Reinicia la sesión o el equipo** al terminar la instalación para que tu usuario reciba los permisos de los grupos `libvirt`, `kvm` y `render`.

### Opciones y banderas disponibles del script

```bash
./Virtualizacion/virtualization.sh                 # Instalación completa (modo seguro sin puente br0)
./Virtualizacion/virtualization.sh --with-windows  # Además descarga virtio-win.iso en Descargas/virtio-drivers/
./Virtualizacion/virtualization.sh --setup-bridge  # Crea puente de red br0 (solo si usas cable Ethernet)
./Virtualizacion/virtualization.sh --user-env      # Configura solo las variables y preferencias de usuario (sin sudo)
./Virtualizacion/virtualization.sh --status        # Diagnóstico completo (-s o --check)
./Virtualizacion/virtualization.sh --help          # Muestra la ayuda (-h o help)
```

---

## 2. Aceleración por Hardware y Energía

- **Virtualización Anidada (Nested KVM)**: Delega en `Setup/amd-setup.sh --kvm` o `Setup/intel-setup.sh --kvm` (o crea el archivo directamente en `/etc/modprobe.d/`):
  - **AMD (`kvm_amd.conf`)**: `options kvm_amd nested=1 avic=1 npt=1`
  - **Intel (`kvm_intel.conf`)**: `options kvm_intel nested=1 ept=1 vpid=1 pml=1`
- **Módulos de red del Kernel**: Carga `vhost_net`, `vhost_vsock` y `tun` automáticamente (`/etc/modules-load.d/kvm-vhost.conf`).
- **Aceleración 3D VirGL y permisos**: Añade tanto a tu usuario como al usuario del sistema `libvirt-qemu` a los grupos `kvm` y `render` para habilitar gráficos 3D en Wayland.
- **Perfil de energía**: Respeta `power-profiles-daemon` de KDE Plasma 6 si está activo; solo instala `tuned` (perfil `virtual-host`) si `power-profiles-daemon` no está instalado.

---

## 3. Almacenamiento Optimizado y Permisos (Btrfs NoCoW y ACLs)

- **Btrfs NoCoW (`+C`)**: Si `/var/lib/libvirt/images` está en un sistema de archivos Btrfs, aplica `chattr +C` automáticamente para evitar fragmentación en discos virtuales `.qcow2`.
- **Permisos ACL sin `sudo`**:
  - Da acceso `rwX` a tu usuario sobre `/var/lib/libvirt/images` para gestionar discos sin usar `sudo`.
  - Da acceso de solo lectura/travesía (`x`/`rx`) a `libvirt-qemu` sobre tu carpeta personal y `~/Descargas` (o `~/Downloads`) para que puedas arrancar archivos `.iso` directamente desde Descargas sin errores de permiso.

---

## 4. Red Virtual, Firewall (UFW) y Modo Seguro Wi-Fi

- **Firewall backend `nftables`**: Configura `/etc/libvirt/network.conf` con `firewall_backend = "nftables"` (estándar moderno de Debian 13).
- **Red NAT `default` (`virbr0`) + UFW**: Crea y activa la red `default` para que tus VMs tengan internet automáticamente. Si **UFW** está activo, abre `9090/tcp` (Cockpit) y permite el tráfico en `virbr0` (`ufw allow in on virbr0` y `ufw route allow in/out on virbr0`).
- **Modo seguro para portátiles (Wi-Fi)**: Por defecto (`SETUP_BRIDGE=false`), el script **no** crea puentes de red `br0` para no romper conexiones Wi-Fi. Solo si usas cable Ethernet y necesitas que la VM tenga su propia IP en tu router, pasa explícitamente `--setup-bridge`.

---

## 5. Polkit sin Contraseñas, KSM y Entorno de Usuario

- **Regla Polkit (`/etc/polkit-1/rules.d/50-libvirt.rules`)**: Permite a los miembros del grupo `libvirt` abrir Virt-Manager y controlar máquinas virtuales sin pedir contraseña de administrador cada vez.
- **Deduplicación de memoria (KSM)**: Activa `/etc/tmpfiles.d/ksm.conf` (`run=1`, `sleep_millisecs=2000`, `pages_to_scan=100`) para ahorrar RAM compartiendo páginas idénticas entre VMs.
- **Entorno de usuario y Virt-Manager**: Configura `LIBVIRT_DEFAULT_URI="qemu:///system"` en `~/.config/environment.d/10-libvirt.conf`, `~/.bashrc.d/virtualization.sh` y `~/.zshrc.d/virtualization.zsh`, además de ajustar `gsettings` en Virt-Manager (conexión automática a `qemu:///system`, editor XML, CPU `host-passthrough` y redimensionado automático).

---

## 6. Diagnóstico y Verificación

```bash
just virtualization-status
# o directamente:
./Virtualizacion/virtualization.sh --status
```

También ejecuta `virt-host-validate qemu` durante la instalación para verificar que tu hardware soporta virtualización completa.

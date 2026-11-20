---
sidebar_position: 7
---

# Virtualization Environment (KVM/QEMU) in Debian GNU/Linux (KDE Plasma 6)

This guide explains in plain terms how to install and use native virtual machines on **Golden Dog Linux (Debian 13)** with **KDE Plasma 6 (Wayland)** using [`Virtualizacion/virtualization.sh`](../Virtualizacion/virtualization.sh).

> [!NOTE]
> **What is KVM/QEMU? (Beginner-Friendly Summary)**
> A **Virtual Machine (VM)** lets you run another operating system (such as Windows or another Linux distro) inside a window on your computer.
> - **KVM** lets the VM use your physical CPU directly so it runs at near-native speed.
> - **QEMU** emulates the rest of the computer (3D display, network card, virtual disk, TPM 2.0 chip for Windows 11).
> - **Libvirt** is the background service coordinating everything, and you can manage VMs through two graphical interfaces:
>   1. **Virt-Manager**: Desktop app with full hardware control and 3D VirGL acceleration.
>   2. **Cockpit Machines**: Modern web console at `https://localhost:9090`.

---

## 1. Installation & Package Stack (`virtualization.sh`)

Installs KVM, QEMU, Libvirt, Virt-Manager, Cockpit Machines, UEFI firmware (`ovmf`), TPM 2.0 (`swtpm`), `virtiofsd` (fast shared folders), `passt` (unprivileged networking), and SPICE/OpenGL graphics libraries:

```bash
just virtualization
```

> [!IMPORTANT]
> **Log out and back in (or reboot)** after installation so your user picks up the new `libvirt`, `kvm`, and `render` group memberships.

### Available Script Flags

```bash
./Virtualizacion/virtualization.sh                 # Full setup (safe laptop mode, no br0 bridge)
./Virtualizacion/virtualization.sh --with-windows  # Also downloads virtio-win.iso into Downloads/virtio-drivers/
./Virtualizacion/virtualization.sh --setup-bridge  # Creates br0 network bridge (wired Ethernet only)
./Virtualizacion/virtualization.sh --user-env      # Configures user env vars and Virt-Manager settings only (no sudo)
./Virtualizacion/virtualization.sh --status        # Full diagnostics (-s or --check)
./Virtualizacion/virtualization.sh --help          # Show help (-h or help)
```

---

## 2. Hardware Acceleration & Power Profiles

- **Nested KVM**: Delegates to `Setup/amd-setup.sh --kvm` or `Setup/intel-setup.sh --kvm` (or writes `/etc/modprobe.d/` directly):
  - **AMD (`kvm_amd.conf`)**: `options kvm_amd nested=1 avic=1 npt=1`
  - **Intel (`kvm_intel.conf`)**: `options kvm_intel nested=1 ept=1 vpid=1 pml=1`
- **Kernel Network Modules**: Automatically loads `vhost_net`, `vhost_vsock`, and `tun` via `/etc/modules-load.d/kvm-vhost.conf`.
- **3D VirGL & Permissions**: Adds both your user and the `libvirt-qemu` system user to the `kvm` and `render` groups for 3D acceleration on Wayland.
- **Power Management**: Respects KDE Plasma 6's `power-profiles-daemon` if active; only installs `tuned` (`virtual-host` profile) when `power-profiles-daemon` is not present.

---

## 3. Storage Optimization & Permissions (Btrfs NoCoW & ACLs)

- **Btrfs NoCoW (`+C`)**: If `/var/lib/libvirt/images` resides on a Btrfs filesystem, `chattr +C` is applied automatically to prevent fragmentation and maximize `qcow2` virtual disk performance.
- **Passwordless ACLs**:
  - Grants your user `rwX` access to `/var/lib/libvirt/images` so you can manage VM disks without `sudo`.
  - Grants `libvirt-qemu` traverse/read access (`x`/`rx`) to your home directory and `~/Downloads` (or `~/Descargas`) so you can boot `.iso` installers directly from Downloads without permission errors.

---

## 4. Virtual Networking, Firewall (UFW) & Safe Wi-Fi Mode

- **`nftables` Firewall Backend**: Configures `/etc/libvirt/network.conf` with `firewall_backend = "nftables"` (Debian 13 standard).
- **Default NAT Network (`virbr0`) + UFW**: Defines and starts the `default` NAT network so VMs get internet access automatically. When **UFW** is active, opens `9090/tcp` (Cockpit) and allows `virbr0` traffic (`ufw allow in on virbr0` and `ufw route allow in/out on virbr0`).
- **Safe Laptop Mode (Wi-Fi)**: By default (`SETUP_BRIDGE=false`), the script does **not** create a `br0` bridge so wireless connections never break. Only pass `--setup-bridge` on wired Ethernet when you explicitly want VMs to receive a LAN IP from your router.

---

## 5. Passwordless Polkit, KSM & User Environment

- **Polkit Rule (`/etc/polkit-1/rules.d/50-libvirt.rules`)**: Allows `libvirt` group members to start, stop, and manage VMs without root password prompts.
- **Memory Deduplication (KSM)**: Configures `/etc/tmpfiles.d/ksm.conf` (`run=1`, `sleep_millisecs=2000`, `pages_to_scan=100`) to share identical RAM pages across VMs.
- **User Env & Virt-Manager Defaults**: Sets `LIBVIRT_DEFAULT_URI="qemu:///system"` in `~/.config/environment.d/10-libvirt.conf`, `~/.bashrc.d/virtualization.sh`, and `~/.zshrc.d/virtualization.zsh`, and configures Virt-Manager `gsettings` (`qemu:///system`, XML editor enabled, `host-passthrough` CPU, auto guest resize).

---

## 6. Diagnostics & Verification

```bash
just virtualization-status
# or directly:
./Virtualizacion/virtualization.sh --status
```

The installer also runs `virt-host-validate qemu` to verify full hardware virtualization support.

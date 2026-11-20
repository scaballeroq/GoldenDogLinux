---
sidebar_position: 1
---

# Security Hardening and Firewall in Debian GNU/Linux (KDE Plasma 6)

This guide details the security, network, and system hardening automated in [`Setup/seguridad.sh`](../Setup/seguridad.sh), optimized for a local development workstation on **Golden Dog Linux (Debian GNU/Linux)**.

---

## 1. Native Firewall (UFW)

> [!NOTE]
> **What is a firewall (UFW)? (Beginner-Friendly Summary)**
> A firewall acts like your computer's security guard: it blocks unsolicited incoming network connections while letting you browse and download normally.

In **Golden Dog Linux (Debian 13)**, **UFW** (`Uncomplicated Firewall`) comes pre-installed (and `seguridad.sh` installs it automatically if missing). The [`Setup/seguridad.sh`](../Setup/seguridad.sh) script verifies its status and applies the rules needed for a local development workstation:

1. **Enabling UFW & Default Policy**:
   ```bash
   sudo systemctl enable --now ufw
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw --force enable
   ```

2. **Rules for Golden Dog Linux, KDE Plasma 6, and Development**:
   - **Cockpit Web Console (`9090/tcp`)**: Allows local and LAN access to the web administration console at `https://localhost:9090`.
   - **KDE Connect (`1714:1764` TCP/UDP)**: Enables notification sync, media controls, shared clipboard, and file transfer between your phone and PC.
   - **Local Discovery (`5353/udp` mDNS/Avahi)**: Enables printer discovery and local network services.
   - **Remote Access (`ssh`)**: Allowed automatically if `ssh` or `sshd` is active.
   - **Virtual Machines & Containers**:
     - Podman bridge (`podman0`): `ufw allow in on podman0` and `ufw route allow in on podman0`.
     - KVM virtualization bridge (`virbr0`): `ufw allow in on virbr0`, `ufw route allow in on virbr0`, and `ufw route allow out on virbr0`.
   - **Local Development Ports (`--dev-ports` / `just dev-ports`)**: Optionally opens ports `5173/tcp` (Vite), `3000/tcp` (Next.js/React), `8000/tcp` (FastAPI), and `8080/tcp`.

---

## 2. Network and Kernel Tuning (Sysctl) for Development

Applies Kernel settings in `/etc/sysctl.d/99-dev-network.conf` to guarantee full compatibility with rootless Podman and KVM virtual machines:

```ini
# /etc/sysctl.d/99-dev-network.conf

# Packet forwarding for containers and VMs
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Preserve IPv6 Router Advertisements (SLAAC) with forwarding enabled
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2

# Allow Rootless Podman to bind standard HTTP/HTTPS ports (>=80) without root
net.ipv4.ip_unprivileged_port_start = 80

# Allow ICMP (ping) in unprivileged containers
net.ipv4.ping_group_range = 0 2147483647

# Full support for user namespaces
user.max_user_namespaces = 262144
```

---

## 3. Home LAN Optimization

For a development workstation on a private home network:
- **DHCP Stability**: Avoid MAC randomization to prevent changing the machine's local IP address and breaking static DHCP reservations.
- **No Fail2ban Overhead**: Kept inactive on home LANs where ports are not publicly exposed to the internet.

---

## 4. Execution and Diagnostics with Just

```bash
# Apply security and network setup
just security

# Open local dev ports (5173, 3000, 8000, 8080)
just dev-ports

# Inspect UFW, network interfaces, and sysctl parameters
just security-status
```

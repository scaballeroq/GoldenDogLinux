---
sidebar_position: 1
---

# Endurecimiento de Seguridad y Cortafuegos en Debian GNU/Linux (KDE Plasma 6)

Esta guía detalla el proceso de seguridad, red y endurecimiento del sistema (hardening) automatizado en [`Setup/seguridad.sh`](../Setup/seguridad.sh), optimizado para una estación de trabajo y desarrollo local con **Golden Dog Linux (Debian GNU/Linux)**.

---

## 1. Cortafuegos Nativo (UFW)

> [!NOTE]
> **¿Qué es un cortafuegos (UFW)? (Para principiantes)**
> Un cortafuegos actúa como el portero de tu ordenador: bloquea cualquier conexión entrante que no hayas pedido desde internet o tu red, mientras te deja navegar y descargar con normalidad.

En **Golden Dog Linux (Debian 13)**, **UFW** (`Uncomplicated Firewall`) ya viene preinstalado y activo de serie junto con las interfaces gráficas **Goldendog Firewall** (`goldendog-firewall`) y **KDE Plasma Firewall** (`plasma-firewall`). El script [`Setup/seguridad.sh`](../Setup/seguridad.sh) verifica su estado de forma idempotente y añade únicamente las reglas faltantes para una estación de trabajo y desarrollo local (todas con sintaxis numérica compatible con `goldendog-firewall`):

1. **Activación y Política Base de UFW**:
   ```bash
   sudo systemctl enable --now ufw
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw --force enable
   ```

2. **Reglas para Golden Dog Linux, KDE Plasma 6 y Desarrollo**:
   - **Cockpit Web Console (`9090/tcp`)**: Permite el acceso local y en LAN a la consola web de administración en `https://localhost:9090`.
   - **KDE Connect (`1714:1764` TCP/UDP)**: Permite la sincronización de notificaciones, control multimedia, portapapeles compartido y transferencia de archivos entre tu teléfono y tu PC.
   - **Descubrimiento Local (`5353/udp` mDNS/Avahi)**: Permite detectar impresoras, dispositivos multimedia y servicios locales.
   - **Acceso Remoto (`22/tcp`)**: Si el servicio `ssh` o `sshd` está activo, se autoriza automáticamente en UFW usando puerto numérico (`22/tcp`) para que sea editable desde `goldendog-firewall`.
   - **Máquinas Virtuales y Contenedores**:
     - Puente de contenedores Podman (`podman0`): `ufw allow in on podman0` y `ufw route allow in on podman0`.
     - Puente de virtualización KVM (`virbr0`): `ufw allow in on virbr0`, `ufw route allow in on virbr0` y `ufw route allow out on virbr0`.
   - **Puertos Locales de Desarrollo (`--dev-ports` / `just dev-ports`)**: Abre opcionalmente los puertos `5173/tcp` (Vite), `3000/tcp` (Next.js/React), `8000/tcp` (FastAPI) y `8080/tcp` (y `--close-dev-ports` los cierra).

---

## 2. Optimización de Red y Kernel (Sysctl) para Desarrollo

Complementa el perfil base de endurecimiento de Golden Dog Linux (`/etc/sysctl.d/90-goldendog.conf`) aplicando configuraciones en `/etc/sysctl.d/99-dev-network.conf` —y sincronizando el IP forwarding en `/etc/ufw/sysctl.conf` para que no se pierda al guardar reglas desde `goldendog-firewall`— con el fin de garantizar compatibilidad completa con Podman Rootless y máquinas virtuales KVM:

```ini
# /etc/sysctl.d/99-dev-network.conf

# Reenvío de paquetes para contenedores y VMs
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1

# Preservar recepción de Router Advertisements (SLAAC) con forwarding activo
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2

# Permitir a Podman Rootless enlazar puertos HTTP/HTTPS estándar (>=80) sin root
net.ipv4.ip_unprivileged_port_start = 80

# Permitir operaciones ICMP (ping) en contenedores sin privilegios
net.ipv4.ping_group_range = 0 2147483647

# Garantizar soporte de user namespaces sin privilegios en Debian 13 (Podman / Flatpak)
kernel.unprivileged_userns_clone = 1
```

---

## 3. Saneamiento para Red Local Doméstica

Para una estación de trabajo de desarrollo en red local de hogar:
- **Estabilidad DHCP y Reservas de IP**: Se evita la aleatorización de MAC para prevenir que el router cambie la dirección IP local del equipo y rompa reservas estáticas.
- **Sin sobrecarga de Fail2ban**: Desactivado en LAN privada donde no hay servicios expuestos directamente a internet pública.

---

## 4. Ejecución y Diagnóstico con Just

```bash
# Aplicar configuración de seguridad y red
just security

# Abrir puertos locales de desarrollo (5173, 3000, 8000, 8080)
just dev-ports

# Diagnosticar estado de UFW, interfaces y parámetros sysctl
just security-status
```

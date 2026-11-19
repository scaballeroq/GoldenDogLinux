---
sidebar_position: 5
---

# Entornos de Desarrollo (IDEs) y Herramientas de IA en Golden Dog Linux (Debian 13)

Esta guía detalla la instalación, actualización y diagnóstico de los entornos de desarrollo y agentes de programación gestionados en la carpeta `IDE/`.

Todos los instaladores están optimizados para **Golden Dog Linux (Debian 13 Trixie)** sobre **KDE Plasma 6 (Wayland)**, integrando lanzadores nativos con soporte Ozone Wayland, variables en `~/.config/environment.d/` y menús contextuales en **Dolphin** (`~/.local/share/kio/servicemenus/`).

---

## 1. Google Antigravity Desktop 2.0 (`IDE/antigravity.sh`)

Instala la aplicación de escritorio oficial **Google Antigravity Desktop 2.0** en `/opt/antigravity` con enlace en `/usr/local/bin/antigravity`:

* **Características**:
  - Inspección de versión local vs remota 100% rootless (`--status` y `--check`).
  - Actualizador atómico `/usr/local/bin/update-antigravity` con rollback automático y configuración de `chrome-sandbox` (SUID 4755).
  - Extracción del icono nativo 512x512 desde `app.asar`.
  - Lanzador de escritorio con flags `--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations`.
  - Menú contextual en Dolphin: *"Abrir con Antigravity"*.

* **Comandos**:
  ```bash
  just antigravity               # Instala o actualiza Antigravity Desktop
  ./IDE/antigravity.sh --status  # Diagnóstico rápido sin sudo
  ```

---

## 2. Google Antigravity CLI (`IDE/antigravity-cli.sh`)

Instala la interfaz de línea de comandos **`agy`** de forma 100% rootless en `~/.local/bin/agy`:

* **Características**:
  - Consulta directa al manifiesto oficial y descarga solo si existe una versión nueva.
  - Fallback automático al instalador oficial (`https://antigravity.google/cli/install.sh`).
  - Integración automática de `~/.local/bin` en `~/.bashrc.d/antigravity-cli.sh` y `~/.config/environment.d/10-antigravity-cli.conf`.

* **Comandos**:
  ```bash
  just antigravity-cli               # Instala o actualiza agy CLI
  ./IDE/antigravity-cli.sh --status  # Verifica versión local y remota
  ```

---

## 3. Google Antigravity IDE (`IDE/antigravity-ide.sh`)

Instala el motor **Google Antigravity IDE** en `/opt/antigravity-ide` con su helper `/usr/local/bin/update-antigravity-ide` y menú contextual en Dolphin (*"Abrir con Antigravity IDE"*):

```bash
just antigravity-ide               # Instala o actualiza Antigravity IDE
./IDE/antigravity-ide.sh --status  # Muestra el estado de la instalación
```

---

## 4. OpenCode AI CLI (`IDE/opencode.sh`)

Gestiona el agente de terminal **OpenCode AI** en espacio de usuario a través de **Mise**:

* **Características**:
  - Instalación idempotente (`mise use --global opencode@latest`) o fijación de versión específica (`--version <ver>`).
  - Limpieza automática de binarios heredados en `~/.opencode/bin` para evitar conflictos de `PATH`.
  - Propagación de shims de Mise a la sesión gráfica KDE Plasma 6 (`~/.config/environment.d/10-opencode.conf`).

* **Comandos**:
  ```bash
  just opencode               # Instala OpenCode vía Mise
  ./IDE/opencode.sh --status  # Diagnóstico de Mise y OpenCode
  ./IDE/opencode.sh --update  # Actualiza a la última versión
  ```

---

## 5. Instalación Conjunta y Diagnóstico

```bash
just ides         # Instala Antigravity Desktop, CLI, IDE y OpenCode
just ides-status  # Muestra el estado de todas las herramientas de desarrollo
```

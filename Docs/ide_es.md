---
sidebar_position: 5
---

# Entornos de Desarrollo (IDEs) y Herramientas de IA en Golden Dog Linux (Debian 13)

Esta guía explica de forma sencilla qué instala y cómo se usa cada script de la carpeta `IDE/` para programar con editores modernos y asistentes de Inteligencia Artificial.

> [!NOTE]
> **¿Qué es un IDE y qué hace esta carpeta? (Para principiantes)**
> - Un **IDE** (*Entorno de Desarrollo Integrado*) es el programa donde escribes y pruebas código (como un procesador de textos avanzado para programar).
> - Una herramienta **CLI** (*Command Line Interface*) es un programa que se usa directamente desde la terminal.
> - Todos los instaladores están optimizados para **Golden Dog Linux (Debian 13 Trixie)** con **KDE Plasma 6 (Wayland)**, activando gráficos nítidos en Wayland y menús contextuales en el gestor de archivos **Dolphin** (clic derecho -> *Abrir con...*).

---

## 1. Google Antigravity Desktop 2.0 (`IDE/antigravity.sh`)

Instala la aplicación de escritorio oficial **Google Antigravity Desktop 2.0** en `/opt/antigravity` con acceso directo en el menú de aplicaciones y comando `antigravity` en `/usr/local/bin/antigravity`:

* **Qué hace por debajo**:
  - Comprueba e instala las librerías gráficas necesarias (compatibles con Debian 13 `t64`).
  - Descarga e instala el paquete oficial de forma atómica con copia de seguridad y rollback automático mediante el ayudante `/usr/local/bin/update-antigravity`.
  - Configura `chrome-sandbox` con permisos `4755`, extrae el icono 512x512 nativo, crea el lanzador Wayland (`--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations`) y añade el menú contextual de Dolphin en `/usr/share/kio/servicemenus/open-in-antigravity.desktop` (con respaldo en `~/.local/share/kio/servicemenus/`).
  - Detecta si existe una instalación heredada por APT que pueda causar conflicto.

* **Comandos disponibles**:
  ```bash
  just antigravity                  # Instala o actualiza Antigravity Desktop
  ./IDE/antigravity.sh --status     # Diagnóstico rápido sin sudo (-s)
  ./IDE/antigravity.sh --check      # Comprueba si hay nueva versión (0 = al día, 1 = actualización) (-c)
  ./IDE/antigravity.sh --force      # Fuerza la reinstalación aunque esté actualizado (-f)
  ./IDE/antigravity.sh --url <URL>  # Instala desde una URL personalizada
  ./IDE/antigravity.sh --uninstall  # Desinstala la aplicación y sus enlaces
  ./IDE/antigravity.sh --help       # Muestra la ayuda (-h)
  ```

---

## 2. Google Antigravity CLI (`IDE/antigravity-cli.sh`)

Instala la herramienta de terminal **`agy`** sin necesidad de permisos de administrador (*100% rootless*) en `~/.local/bin/agy`:

* **Qué hace por debajo**:
  - Consulta el manifiesto oficial y descarga la nueva versión solo si estás desactualizado (con respaldo al instalador oficial `https://antigravity.google/cli/install.sh`).
  - Crea el enlace de actualización `~/.local/bin/update-antigravity-cli`.
  - Añade `~/.local/bin` automáticamente a tu sesión gráfica y terminal mediante `~/.config/environment.d/10-antigravity-cli.conf`, `~/.bashrc.d/antigravity-cli.sh` y `~/.zshrc.d/antigravity-cli.zsh` (si usas Zsh).

* **Comandos disponibles**:
  ```bash
  just antigravity-cli                  # Instala o actualiza agy CLI
  ./IDE/antigravity-cli.sh --status     # Verifica versión local y remota (-s)
  ./IDE/antigravity-cli.sh --check      # Comprueba actualizaciones (-c: 0 al día, 1 disponible, 2 error)
  ./IDE/antigravity-cli.sh --update     # Actualiza a la última versión (-u)
  ./IDE/antigravity-cli.sh --force      # Fuerza la reinstalación (-f)
  ./IDE/antigravity-cli.sh --url <URL>  # Instala desde una URL específica
  ./IDE/antigravity-cli.sh --uninstall  # Elimina agy y su integración de shell
  ./IDE/antigravity-cli.sh --help       # Muestra la ayuda (-h)
  ```

---

## 3. Google Antigravity IDE (`IDE/antigravity-ide.sh`)

Instala el editor **Google Antigravity IDE** en `/opt/antigravity-ide` junto con su actualizador `/usr/local/bin/update-antigravity-ide`, lanzador Wayland y menú contextual en Dolphin (`/usr/share/kio/servicemenus/open-in-antigravity-ide.desktop` -> *"Abrir con Antigravity IDE"*):

```bash
just antigravity-ide                  # Instala o actualiza Antigravity IDE
./IDE/antigravity-ide.sh --status     # Muestra el estado de la instalación (-s o status)
./IDE/antigravity-ide.sh --url <URL>  # Instala desde un tarball oficial específico
./IDE/antigravity-ide.sh --uninstall  # Desinstala Antigravity IDE
./IDE/antigravity-ide.sh --help       # Muestra la ayuda (-h o help)
```

---

## 4. OpenCode AI CLI (`IDE/opencode.sh`)

Instala y gestiona el asistente de programación en terminal **OpenCode AI** dentro de tu usuario usando **Mise** (un gestor moderno de herramientas):

* **Qué hace por debajo**:
  - Si `mise` no está instalado todavía, ejecuta automáticamente `../ProgrammingLanguages/mise.sh` para instalarlo.
  - Instala `opencode@latest` (o la versión que elijas) de forma global en Mise (`mise use --global`).
  - Limpia binarios antiguos (`~/.opencode/bin/opencode`, `~/.local/bin/opencode`, `~/.bashrc.d/opencode.sh`, `~/.zshrc.d/opencode.zsh`) para evitar conflictos de `PATH`.
  - Propaga el `PATH` de Mise a KDE Plasma 6 mediante `~/.config/environment.d/10-opencode.conf`, `systemctl --user` y `dbus`.

* **Comandos disponibles**:
  ```bash
  just opencode                         # Instala OpenCode vía Mise (-i / --install)
  ./IDE/opencode.sh --version 1.18.13   # Instala una versión concreta (-v o pasando la versión directa)
  ./IDE/opencode.sh --update            # Actualiza OpenCode a la última versión (-u)
  ./IDE/opencode.sh --force             # Fuerza la reinstalación (-f)
  ./IDE/opencode.sh --status            # Diagnóstico de Mise y OpenCode (-s)
  ./IDE/opencode.sh --uninstall         # Desinstala OpenCode conservando tu configuración (-r)
  ./IDE/opencode.sh --help              # Muestra la ayuda (-h)
  ```

---

## 5. Instalación Conjunta y Diagnóstico

```bash
just ides         # Instala Antigravity Desktop, CLI, IDE y OpenCode de una vez
just ides-status  # Comprueba el estado de las 4 herramientas
```

---
sidebar_position: 4
---

# Configuración de Git en Golden Dog Linux (Debian 13)

Esta guía explica de forma sencilla cómo funciona el entorno de control de versiones instalado con [`IDE/git.sh`](../IDE/git.sh) (`just git-setup`).

> [!NOTE]
> **¿Qué son estas herramientas? (Explicado para principiantes)**
> - **Git**: El sistema estándar para guardar el historial de cambios de tu código o documentos y colaborar sin sobrescribir archivos.
> - **Git-Delta**: Un visor mejorado para la terminal que muestra qué líneas se han añadido o borrado con colores claros y números de línea.
> - **Lazygit**: Una interfaz visual dentro de la propia terminal para usar Git con atajos de teclado y ratón sin memorizar comandos largos.
> - **GitHub CLI (`gh`)**: La herramienta oficial para conectarte a tu cuenta de GitHub, crear *Pull Requests* o clonar repositorios directamente desde la terminal.

---

## 1. ¿Qué instala y configura `IDE/git.sh`?

El script [`IDE/git.sh`](../IDE/git.sh) es **idempotente** (puedes ejecutarlo varias veces sin romper nada; solo instala lo que falte) y realiza lo siguiente:

1. **Instalación base (`git`, `git-delta`, `curl`, `ca-certificates`)**:
   Comprueba si faltan estos paquetes y, solo si es necesario, los instala mediante `apt-get`.
2. **GitHub CLI (`gh`) y Lazygit**:
   - Instala `gh` desde los repositorios oficiales de Debian 13 (y, si no está disponible, añade automáticamente el repositorio oficial de `cli.github.com`).
   - Instala `lazygit` desde los repositorios de Debian 13 (y, si no está disponible, descarga la última versión oficial de GitHub Releases en `/usr/local/bin/lazygit`).
3. **Configuración global recomendada (`git config --global` para tu usuario)**:
   - **Rama principal moderna**: `init.defaultBranch main` (crea ramas llamadas `main` en lugar de `master`).
   - **Sincronización limpia**: `pull.rebase true`, `rebase.autoStash true` y `push.autoSetupRemote true` (evita commits de mezcla innecesarios al descargar cambios y guarda temporalmente tus cambios locales).
   - **Resolución de conflictos más clara**: `merge.conflictstyle zdiff3` (muestra también el código original común cuando hay un conflicto).
   - **Editor por defecto**: `core.editor` se ajusta automáticamente a `nvim` si está instalado, o a `nano` en caso contrario.
4. **Visor visual con Git-Delta**:
   Activa `delta` como paginador por defecto en modo oscuro unificado:
   ```bash
   git config --global core.pager "delta"
   git config --global interactive.diffFilter "delta --color-only"
   git config --global delta.navigate true
   git config --global delta.light false
   git config --global delta.line-numbers true
   git config --global delta.side-by-side false
   ```
5. **Identidad automática opcional mediante variables de entorno**:
   Si defines `GIT_USER_NAME` y/o `GIT_USER_EMAIL` antes de ejecutar el script, configurará automáticamente `user.name` y `user.email` en Git:
   ```bash
   GIT_USER_NAME="Tu Nombre" GIT_USER_EMAIL="tu@correo.com" ./IDE/git.sh
   ```

---

## 2. Comandos disponibles y verificación

Puedes ejecutarlo usando `just` (desde la raíz del repositorio) o llamando al script directamente:

```bash
# Con Just
just git-setup            # Instala y configura Git, Delta, Lazygit y GitHub CLI
just git-status           # Muestra diagnóstico de versiones, identidad y sesión en GitHub
just git-setup --help     # Muestra la ayuda del script

# Directamente con el script
./IDE/git.sh              # Instalación/configuración completa
./IDE/git.sh --status     # También acepta -s o status
./IDE/git.sh --help       # También acepta -h o help
```

### Primeros pasos después de instalar
- **Configurar tu nombre y correo** (si no usaste las variables de entorno):
  ```bash
  git config --global user.name "Tu Nombre"
  git config --global user.email "tu@correo.com"
  ```
- **Git-Delta**: Ejecuta `git diff` dentro de cualquier repositorio con cambios para ver las diferencias coloreadas.
- **Lazygit**: Escribe `lazygit` dentro de una carpeta con Git para abrir la interfaz visual en terminal.
- **GitHub CLI**: Ejecuta `gh auth login` y sigue los pasos en pantalla para iniciar sesión en GitHub.

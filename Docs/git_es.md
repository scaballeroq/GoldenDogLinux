---
sidebar_position: 4
---

# Configuración de Git en Golden Dog Linux (Debian 13)

Esta guía detalla el entorno de control de versiones y el conjunto de herramientas optimizadas mediante [`IDE/git.sh`](../IDE/git.sh) (`just git-setup`).

El entorno incluye **Git**, el formateador visual de diferencias **Git-Delta**, la interfaz TUI **Lazygit** y la utilidad oficial **GitHub CLI (`gh`)**.

---

## 1. Automatización de Git, Delta, Lazygit y GitHub CLI (`IDE/git.sh`)

El script unificado [`IDE/git.sh`](../IDE/git.sh) automatiza la instalación de forma idempotente y define las mejores prácticas de control de versiones:

1. **Instalación de Git y Git-Delta**:
   ```bash
   sudo apt-get update -qq
   sudo apt-get install -y git git-delta curl ca-certificates
   ```

2. **GitHub CLI (`gh`) y Lazygit**:
   - Instala `gh` desde los repositorios oficiales de Debian 13 (con fallback al repositorio oficial de GitHub CLI).
   - Instala `lazygit` desde los repositorios oficiales de Debian 13 (con fallback al binario oficial de GitHub Releases en `/usr/local/bin/lazygit`).

3. **Buenas Prácticas Modernas**:
   - Rama predeterminada: `main` (`init.defaultBranch main`).
   - Sincronización limpia: Rebase y autostash por defecto (`pull.rebase true`, `rebase.autoStash true`, `push.autoSetupRemote true`).
   - Estilo de resolución de conflictos: `zdiff3` (`merge.conflictstyle zdiff3`).

4. **Resaltado Visual (Git-Delta)**:
   Mejora significativamente la legibilidad de las diferencias en consola reemplazando el paginador nativo y activando colores semánticos y números de línea:
   ```bash
   git config --global core.pager "delta"
   git config --global interactive.diffFilter "delta --color-only"
   git config --global delta.navigate true
   git config --global delta.light false
   git config --global delta.line-numbers true
   ```

---

## 2. Comandos con Just y Verificación

```bash
just git-setup   # Instala y configura Git, Delta, Lazygit y GitHub CLI
just git-status  # Muestra diagnóstico de versiones, identidad y autenticación en GitHub
```

- **Git-Delta**: Ejecuta `git diff` en cualquier repositorio con cambios locales.
- **Lazygit**: Ejecuta `lazygit` dentro de un repositorio de Git.
- **GitHub CLI**: Ejecuta `gh auth login` para iniciar sesión en GitHub.

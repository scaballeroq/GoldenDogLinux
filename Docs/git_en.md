---
sidebar_position: 4
---

# Git Configuration on Golden Dog Linux (Debian 13)

This guide details the version control environment and optimized tools configured via [`IDE/git.sh`](../IDE/git.sh) (`just git-setup`).

The environment includes **Git**, the **Git-Delta** syntax-highlighting diff pager, the **Lazygit** terminal UI, and the official **GitHub CLI (`gh`)** utility.

---

## 1. Git, Delta, Lazygit & GitHub CLI Automation (`IDE/git.sh`)

The unified [`IDE/git.sh`](../IDE/git.sh) script automates idempotent package installation and defines modern version control best practices:

1. **Git and Git-Delta Installation**:
   ```bash
   sudo apt-get update -qq
   sudo apt-get install -y git git-delta curl ca-certificates
   ```

2. **GitHub CLI (`gh`) and Lazygit**:
   - Installs `gh` directly from Debian 13 official repositories (with fallback to the official GitHub CLI APT repository).
   - Installs `lazygit` from Debian 13 official repositories (with fallback to the latest GitHub Release binary in `/usr/local/bin/lazygit`).

3. **Modern Best Practices**:
   - Default branch: `main` (`init.defaultBranch main`).
   - Clean syncing: Rebase and autostash by default (`pull.rebase true`, `rebase.autoStash true`, `push.autoSetupRemote true`).
   - Conflict style: `zdiff3` (`merge.conflictstyle zdiff3`).

4. **Visual Enhancements (Git-Delta)**:
   Significantly improves diff readability in the console by replacing the native pager, activating semantic colors and line numbers:
   ```bash
   git config --global core.pager "delta"
   git config --global interactive.diffFilter "delta --color-only"
   git config --global delta.navigate true
   git config --global delta.light false
   git config --global delta.line-numbers true
   ```

---

## 2. Commands with Just & Verification

```bash
just git-setup   # Install and configure Git, Delta, Lazygit, and GitHub CLI
just git-status  # Show version diagnostics, identity, and GitHub auth status
```

- **Git-Delta**: Run `git diff` inside any repository with local changes.
- **Lazygit**: Run `lazygit` inside a Git repository.
- **GitHub CLI**: Run `gh auth login` to authenticate your GitHub account.

---
sidebar_position: 4
---

# Git Configuration on Golden Dog Linux (Debian 13)

This guide explains in plain terms how the version control environment installed by [`IDE/git.sh`](../IDE/git.sh) (`just git-setup`) works.

> [!NOTE]
> **What are these tools? (Beginner-Friendly Summary)**
> - **Git**: The standard system for tracking changes in your code or documents and collaborating without overwriting files.
> - **Git-Delta**: An enhanced terminal diff viewer that highlights added and removed lines with clear colors and line numbers.
> - **Lazygit**: A visual terminal UI that lets you use Git with keyboard shortcuts and mouse clicks instead of memorizing long commands.
> - **GitHub CLI (`gh`)**: The official command-line tool to log into GitHub, open Pull Requests, or clone repositories straight from the terminal.

---

## 1. What `IDE/git.sh` Installs and Configures

[`IDE/git.sh`](../IDE/git.sh) is **idempotent** (safe to run multiple times; it only installs missing components) and performs the following steps:

1. **Base packages (`git`, `git-delta`, `curl`, `ca-certificates`)**:
   Checks whether any of these packages are missing and installs them via `apt-get` only when needed.
2. **GitHub CLI (`gh`) and Lazygit**:
   - Installs `gh` from Debian 13 official repositories (falling back to the official `cli.github.com` APT repository if unavailable).
   - Installs `lazygit` from Debian 13 official repositories (falling back to the latest official GitHub Release binary at `/usr/local/bin/lazygit`).
3. **Recommended global settings (`git config --global` for your user)**:
   - **Modern default branch**: `init.defaultBranch main`.
   - **Clean syncing**: `pull.rebase true`, `rebase.autoStash true`, and `push.autoSetupRemote true` (avoids unnecessary merge commits and safely stashes local changes while pulling).
   - **Clearer conflict resolution**: `merge.conflictstyle zdiff3` (also displays the common original code block during merge conflicts).
   - **Default editor**: `core.editor` is automatically set to `nvim` if installed, or `nano` otherwise.
4. **Visual diff pager (Git-Delta)**:
   Enables `delta` as the default dark-mode unified diff viewer:
   ```bash
   git config --global core.pager "delta"
   git config --global interactive.diffFilter "delta --color-only"
   git config --global delta.navigate true
   git config --global delta.light false
   git config --global delta.line-numbers true
   git config --global delta.side-by-side false
   ```
5. **Optional automatic identity via environment variables**:
   If you set `GIT_USER_NAME` and/or `GIT_USER_EMAIL` before running the script, it automatically configures `user.name` and `user.email`:
   ```bash
   GIT_USER_NAME="Your Name" GIT_USER_EMAIL="you@example.com" ./IDE/git.sh
   ```

---

## 2. Available Commands & Verification

You can run it via `just` (from the repository root) or directly:

```bash
# Using Just
just git-setup            # Install and configure Git, Delta, Lazygit, and GitHub CLI
just git-status           # Show version diagnostics, identity, and GitHub auth status
just git-setup --help     # Show script help

# Running the script directly
./IDE/git.sh              # Full installation/configuration
./IDE/git.sh --status     # Also accepts -s or status
./IDE/git.sh --help       # Also accepts -h or help
```

### First steps after installation
- **Set your name and email** (if you didn't pass environment variables):
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  ```
- **Git-Delta**: Run `git diff` inside any repository with local changes to see colorized diffs.
- **Lazygit**: Run `lazygit` inside a Git folder to open the visual terminal interface.
- **GitHub CLI**: Run `gh auth login` and follow the prompts to authenticate your GitHub account.

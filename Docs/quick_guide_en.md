---
sidebar_position: 0
---

# 🐕 Beginner-Friendly Step-by-Step Guide

Welcome to **Golden Dog Linux**! If you just installed the system or don't have much experience with the Linux terminal, this guide is written specifically for you.

Here you will learn **what this project does**, **how to set up your computer with a single command**, and **how to use its everyday tools** without technical jargon.

---

## 1. What is this project and why is it useful?

**Golden Dog Linux** is a fast, clean, and modern operating system based on **Debian 13** with the **KDE Plasma** desktop. When you install a fresh system, you usually have to spend hours installing apps, setting up video codecs, tuning performance, or preparing work tools.

This project is an **"automated assistant"** that does all that work for you in just a few minutes:

* 🎨 **100% Preserves Your Desktop Look**: It never changes your Golden Dog Linux wallpaper, colors, icons, cursors, or panels. It only adds practical improvements under the hood.
* 🎬 **Multimedia Ready Out-of-the-Box**: Installs all audio/video codecs so you can play any media file and see video thumbnail previews inside the **Dolphin** file manager.
* 🚀 **Faster Computer**: Configures ultra-fast compressed RAM swap (**ZRAM**) so your system stays smooth even with dozens of browser tabs or heavy apps open.
* 🛡️ **Secure from Day One**: Configures the built-in firewall (**UFW**) to protect your PC while keeping phone sync (**KDE Connect**) and the web dashboard (**Cockpit**) working seamlessly.
* 📦 **App Store Ready**: Connects the **KDE Discover** software center to **Flathub** so you can install apps like VLC, Spotify, LibreOffice, Telegram, or Discord with a single click.

> [!NOTE]
> **Which computers are supported?**
> Any desktop or laptop powered by **AMD** or **Intel** processors and graphics. *(Note: Dedicated Nvidia graphics cards are excluded from these scripts).*

---

## 2. Before You Start: How to Open the Terminal & Download the Assistant

You only need to copy and paste **3 commands** to get started.

1. Open your **Terminal** (look for *"Konsole"* in the application menu at the bottom-left corner).
2. Copy and paste the following command to install the two basic tools (`git` to download the project and `just` to run the easy commands):

```bash
sudo apt update && sudo apt install -y git just
```
*(It will ask for your user password. For security, no asterisks are shown while typing—just type your password and press `Enter`).*

3. Download this project and enter its folder:

```bash
mkdir -p ~/Workspace/Repositorios
cd ~/Workspace/Repositorios
git clone https://github.com/GoldendogLinux/GoldenDogLinux.git
cd GoldenDogLinux
```
*(If you already have the folder downloaded on your computer, simply enter it with `cd ~/Workspace/Repositorios/GoldenDogLinux`).*

---

## 3. The Easy Way: Set Up Everything with One Command

This project uses a tool called **`just`**. Think of `just` as a remote control with quick buttons: instead of memorizing long commands, you simply type `just` followed by what you want to do.

### Option A: "Do Everything for Me!" (Recommended)

If you want your computer fully configured (AMD/Intel drivers, video codecs, Google Chrome, enhanced terminal, fonts, security, and development tools), run:

```bash
just setup-all
```

The assistant will automatically detect whether your CPU/GPU is **AMD** or **Intel** and configure everything step by step (base system, multimedia, Flatpak, Chrome, tuning, KDE, shell, security, fonts, Fastfetch, Kitty, IDEs, Git, languages, and Podman). When it finishes, **restart your computer** and enjoy!

*(Note: Optional extras such as `firefox`, `zsh`, `starship`, `yt-dlp`, `virtualization`, and `kodi` —or optimizing/extending the preinstalled `cockpit` console— are not part of `setup-all` and can be run individually whenever you want.)*

---

### Option B: Pick Only What You Need (À la Carte)

If you aren't a programmer or prefer installing only specific features, you can run individual commands:

| What do you want to do? | Command to run | What does it do in plain English? |
| :--- | :--- | :--- |
| **1. Basic setup & hardware drivers** | `just post-install` | Updates the system, installs AMD or Intel microcode/graphics drivers, enables PipeWire audio, and sets up fast ZRAM memory. |
| **2. Play any video & music** | `just multimedia` | Installs all media codecs (MP4, MKV, MP3, FLAC...), enables GPU video acceleration, and video thumbnails in folders. |
| **3. Improve the file manager** | `just kde-setup` | Sets Dolphin to detailed view with media thumbnails and enables `Ctrl + Alt + T` to open the terminal. **Leaves your visual theme untouched**. |
| **4. Speed up the system** | `just tuning` | Tunes Linux internals for smoother multitasking, fast shutdowns, and better SSD and RAM usage. |
| **5. Configure the firewall** | `just security` | Configures the **UFW** firewall to protect your PC while allowing KDE Connect and the Cockpit web console. |
| **6. Install Google Chrome** | `just chrome` | Installs the official Google Chrome browser optimized for Wayland hardware video acceleration. |
| **7. Install Mozilla Firefox** | `just firefox` | Installs the latest official Mozilla Firefox `.deb` browser *(note: currently includes the Spanish `firefox-l10n-es-es` pack; use `./Setup/flatpak.sh --web` if you prefer the multilingual Flatpak)*. |
| **8. Set up Flatpak apps** | `just flatpak` | Connects Flathub and installs essential tools to manage your apps (**Flatseal** and **Warehouse**). |
| **9. Modern GPU Terminal (Kitty)** | `just kitty` | Installs the **Kitty** terminal with blurred glass background and a comfortable dark color palette. |

---

## 4. How to Install Your Favorite Apps (VLC, Spotify, LibreOffice, etc.)

Once you have run `just flatpak` (or `just multimedia`), you have two easy ways to install everyday apps:

### Way 1: Using your mouse in the graphical store (KDE Discover)
1. Open the KDE Application Launcher and open **Discover** (the software center).
2. Search for any app (e.g., *Telegram*, *VLC*, *Spotify*, *LibreOffice*, *OBS Studio*, *Kdenlive*) and click **Install**.

### Way 2: From the terminal by name or category
The Flatpak helper lets you install individual apps or whole bundles at once:

```bash
# Install a single app by name:
./Setup/flatpak.sh install vlc
./Setup/flatpak.sh install spotify
./Setup/flatpak.sh install libreoffice
./Setup/flatpak.sh install telegram
./Setup/flatpak.sh install discord
./Setup/flatpak.sh install obsidian

# Or install whole categories of apps:
./Setup/flatpak.sh --multimedia     # Installs VLC, OBS Studio, Kdenlive, Spotify, Kodi, etc.
./Setup/flatpak.sh --productivity   # Installs LibreOffice, Obsidian, LocalSend, and Pika Backup
./Setup/flatpak.sh --comms          # Installs Discord (Vesktop) and Telegram
./Setup/flatpak.sh --graphics       # Installs GIMP and Inkscape
```

---

## 5. How to Check That Everything Is Working (Safe Diagnostics)

Every module includes a **status check** (`status`). These commands **only read information** (they never change or break anything) and show green checkmarks (`✅`) when everything is healthy:

```bash
just status              # Full overview of system performance, security, KDE, and Cockpit
just multimedia-status   # Checks if codecs and GPU video acceleration are active
just security-status     # Shows if the UFW firewall is active and protecting your PC
just cockpit-status      # Checks the Cockpit web administration console
just flatpak-status      # Lists which Flatpak apps are installed
```

---

## 6. Useful Everyday Shortcuts & Tricks

### ⌨️ On the KDE Plasma Desktop (with `just kde-setup` / `just kitty`)
* **`Ctrl + Alt + T`**: Opens your terminal immediately from anywhere.
* **Right-click inside any folder (Dolphin)**: You'll see new context menu actions like **"Open in Kitty"** or **"Open in Antigravity"** to open a terminal or editor directly in that folder.

### 🌐 Web Control Panel (Cockpit)
Golden Dog Linux includes **Cockpit**, a visual dashboard you can open in your web browser to inspect RAM, disks, updates, containers, and virtual machines:
* Run `just cockpit-open` in the terminal, or open your browser and go to: **`https://localhost:9090`**
* Log in using the **same username and password** you use to log into your computer. *(Note: If your browser warns about a self-signed certificate, click "Advanced" -> "Proceed to localhost" — this is completely normal because it is running locally on your own PC).*

### 🐚 Handy Terminal Shortcuts (with `just shell`)
When you open the terminal, you can type these short commands:

| Shortcut | What does it do? |
| :--- | :--- |
| `ff` or `sysinfo` | Displays a clean visual summary of your computer hardware and OS (Fastfetch). |
| `upgrade` | Updates all Debian system packages (`sudo apt update && sudo apt upgrade -y`). |
| `clean` | Removes old unused packages to free up disk space. |
| `ll` or `la` | Lists files in the current folder with icons, colors, and details. |
| `..` / `...` | Moves up one folder (`..`) or two folders (`...`) without typing `cd`. |
| `extract file.zip` | Automatically extracts any archive (`.zip`, `.rar`, `.tar.gz`, `.7z`...). |
| `duh` | Shows how much disk space each folder takes, sorted by size. |
| `files` | Opens the current folder in the graphical **Dolphin** file manager. |
| `fw-status` | Shows the status of the UFW firewall. |
| `ytvideo <url>` | Downloads a video in 1080p MP4 format (if you ran `just yt-dlp`). |
| `ytaudio <url>` | Downloads only the audio track of a video in MP3 format. |

---

## 7. Maintenance: How Do I Keep My Computer Updated?

To keep your Golden Dog Linux system clean and up to date once a week, you only need two commands:

```bash
# 1. Update the entire Debian base system and clean up old packages:
just update

# 2. Update all your Flatpak applications and clean unused runtimes:
just flatpak-update
just flatpak-clean
```

---

## 8. Frequently Asked Questions (FAQ)

### ❓ Will this delete my personal files or change how my desktop looks?
**No.** None of the scripts delete personal documents or modify Golden Dog Linux's visual themes, wallpapers, or icons.

### ❓ What happens if I run the same command twice by mistake?
**Nothing bad at all.** All scripts are *idempotent*: if they detect that a program or setting is already installed, they simply show `✅ Already installed` and skip downloading it again.

### ❓ I have one Intel PC and one AMD PC—which command should I use?
You can use `just post-install` (or `just setup-all`) on both: the script automatically checks your processor and applies the right configuration (`amd-setup.sh` or `intel-setup.sh`).

### ❓ Where can I find the advanced technical documentation?
If you want to dive deeper into Podman containers, KVM virtual machines, or software development (Python, Rust, Node.js, Java), check out the detailed guides in [`Docs/`](./):
* [System Setup (`setup_en.md`)](./setup_en.md)
* [Security & UFW Firewall (`seguridad_en.md`)](./seguridad_en.md)
* [Flatpak Applications (`apps_en.md`)](./apps_en.md)
* [Bash & Zsh Terminal (`bash_en.md`)](./bash_en.md)
* [Programming Languages (`languages_en.md`)](./languages_en.md)
* [IDEs & AI Tools (`ide_en.md`)](./ide_en.md) & [Git (`git_en.md`)](./git_en.md)
* [Podman Containers (`podman_en.md`)](./podman_en.md) & [KVM Virtualization (`virtualization_en.md`)](./virtualization_en.md)

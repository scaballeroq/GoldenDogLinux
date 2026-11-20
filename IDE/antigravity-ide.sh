#!/usr/bin/env bash
# ==============================================================================
# antigravity-ide.sh - Gestor e Instalador de Google Antigravity IDE
# Sistema: Golden Dog Linux (Debian 13 Trixie) | Escritorio: KDE Plasma 6 Wayland
# ==============================================================================

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "❌ Error: 'sudo' no está disponible y el script no se ejecuta como root." >&2
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

TARGET_URL=""
ACTION="install"

is_pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

show_help() {
    cat <<EOF
🪐 Gestor e Instalador de Google Antigravity IDE - Golden Dog Linux (Debian 13)

Uso:
  $0 [OPCIÓN]

Opciones:
  (sin argumentos)    Instala o actualiza Google Antigravity IDE de forma idempotente.
  --url <URL>         Usa una URL oficial directa (.tar.gz de edgedl.me.gvt1.com) si la
                      descarga automática desde antigravity.google/download falla.
  --status, -s        Muestra el estado de la instalación, versión, sandbox, Wayland y Dolphin.
  --uninstall         Desinstala Antigravity IDE y elimina sus accesos e integración de Dolphin.
  --help, -h          Muestra este mensaje de ayuda.
EOF
}

show_status() {
    local install_root="/opt/antigravity-ide"
    local command_link="/usr/local/bin/antigravity-ide"
    local desktop_file="/usr/share/applications/antigravity-ide.desktop"
    local kio_sys_file="/usr/share/kio/servicemenus/open-in-antigravity-ide.desktop"
    local sandbox_path="$install_root/Antigravity-IDE/chrome-sandbox"
    local helper_path="/usr/local/bin/update-antigravity-ide"
    local installed_v distro_pretty distro_codename cpu_model gpu_model
    installed_v=$(cat "$install_root/.linuxcapable-version" 2>/dev/null || echo "")
    distro_pretty=$(grep -oP '^PRETTY_NAME="\K[^"]+' /etc/os-release 2>/dev/null || echo "Debian GNU/Linux")
    distro_codename=$(grep -oP '^VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null || echo "trixie")
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs || echo "Desconocido")
    gpu_model=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -n1 | cut -d: -f3 | xargs || echo "Mesa Wayland")

    echo "================================================================="
    echo "🔍 ESTADO DE GOOGLE ANTIGRAVITY IDE - GOLDEN DOG LINUX (DEBIAN 13)"
    echo "================================================================="
    echo "• Sistema:              $distro_pretty [Debian $distro_codename] (${XDG_SESSION_TYPE:-wayland})"
    echo "• Hardware:             $cpu_model | $gpu_model"
    if [ -n "$installed_v" ] && [ -x "$install_root/Antigravity-IDE/antigravity-ide" ]; then
        echo "• Estado App:           ✅ Instalado (v$installed_v)"
        echo "• Binario nativo:       $install_root/Antigravity-IDE/antigravity-ide"
    elif [ -L "$command_link" ] && [ -f "$desktop_file" ]; then
        echo "• Estado App:           ✅ Instalado ($(readlink "$command_link"))"
    else
        echo "• Estado App:           ❌ No instalado"
    fi
    echo "• Enlace en PATH:       $(if [ -L "$command_link" ]; then echo "✅ $command_link -> $(readlink "$command_link")"; else echo "❌ No presente"; fi)"
    echo "• Lanzador Desktop:     $(if [ -f "$desktop_file" ]; then echo "✅ $desktop_file"; else echo "❌ No presente"; fi)"
    if [ -f "$desktop_file" ]; then
        if grep -q -- '--ozone-platform-hint=auto' "$desktop_file"; then
            echo "• Soporte Wayland:      ✅ Nativo (Ozone auto + WaylandWindowDecorations)"
        else
            echo "• Soporte Wayland:      ⚠️ Sin flags Ozone en .desktop (ejecuta el script para actualizar)"
        fi
    fi
    echo "• Menú Dolphin (KIO):   $(if [ -f "$kio_sys_file" ]; then echo "✅ Activo ($kio_sys_file)"; else echo "ℹ️ No instalado"; fi)"
    if [ -f "$sandbox_path" ] && [ ! -L "$sandbox_path" ]; then
        local sb_perm
        sb_perm=$(stat -c '%U:%G:%a' "$sandbox_path" 2>/dev/null || true)
        if [ "$sb_perm" = "root:root:4755" ]; then
            echo "• Chrome Sandbox:       ✅ root:root:4755"
        else
            echo "• Chrome Sandbox:       ⚠️ Permisos incorrectos ($sb_perm)"
        fi
    fi
    echo "• Helper actualización: $(if [ -x "$helper_path" ]; then echo "✅ $helper_path"; else echo "❌ No presente"; fi)"
    echo "================================================================="
}

uninstall_ide() {
    echo "🗑️ Desinstalando Google Antigravity IDE..."
    $SUDO rm -rf /opt/antigravity-ide
    $SUDO rm -f /usr/local/bin/antigravity-ide \
        /usr/local/bin/update-antigravity-ide \
        /usr/share/applications/antigravity-ide.desktop \
        /usr/share/icons/hicolor/512x512/apps/antigravity-ide.png \
        /usr/share/kio/servicemenus/open-in-antigravity-ide.desktop
    command -v update-desktop-database >/dev/null 2>&1 && $SUDO update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 && $SUDO gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
    echo "✅ Google Antigravity IDE desinstalado correctamente."
}

while [ $# -gt 0 ]; do
    case "$1" in
        --status|-s|status)
            show_status
            exit 0
            ;;
        --uninstall)
            uninstall_ide
            exit 0
            ;;
        --help|-h|help)
            show_help
            exit 0
            ;;
        --url)
            if [ -z "${2:-}" ]; then
                echo "❌ Error: --url requiere una URL." >&2
                exit 1
            fi
            TARGET_URL="$2"
            shift 2
            ;;
        *)
            echo "❌ Opción desconocida: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

echo "=== Google Antigravity IDE Installer (Golden Dog Linux / Debian 13) ==="

# --- Dependencies ---
echo "[1/4] Checking dependencies (Debian 13 Trixie / Electron / Wayland)..."
base_pkgs=(
    ca-certificates curl tar desktop-file-utils python3
    libnss3 libdrm2 libxkbcommon0 libxcomposite1
    libxdamage1 libxrandr2 libgbm1 libsecret-1-0
)
missing_pkgs=()
for pkg in "${base_pkgs[@]}"; do
    if ! is_pkg_installed "$pkg"; then
        missing_pkgs+=("$pkg")
    fi
done
! is_pkg_installed "libasound2t64" && ! is_pkg_installed "libasound2" && missing_pkgs+=("libasound2t64")
! is_pkg_installed "libcups2t64" && ! is_pkg_installed "libcups2" && missing_pkgs+=("libcups2t64")
! is_pkg_installed "libatk1.0-0t64" && ! is_pkg_installed "libatk1.0-0" && missing_pkgs+=("libatk1.0-0t64")
! is_pkg_installed "libatk-bridge2.0-0t64" && ! is_pkg_installed "libatk-bridge2.0-0" && missing_pkgs+=("libatk-bridge2.0-0t64")

if [ ${#missing_pkgs[@]} -gt 0 ]; then
    $SUDO apt-get update -qq
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_pkgs[@]}"
fi

# --- Helper script ---
echo "[2/4] Creating update helper..."
helper_path='/usr/local/bin/update-antigravity-ide'
helper_marker='# LinuxCapable-Managed: google-antigravity-ide-helper-v1'

if [ -L "$helper_path" ] || { [ -e "$helper_path" ] && [ ! -f "$helper_path" ]; }; then
  printf '%s is not a regular helper file; move it before continuing.\n' "$helper_path" >&2
  exit 1
fi
recognized_old_helper=no
if [ -f "$helper_path" ] &&
   $SUDO grep -Fqx 'download_page="https://antigravity.google/download"' "$helper_path" &&
   $SUDO grep -Fqx 'install_root="/opt/antigravity-ide"' "$helper_path" &&
   $SUDO grep -Fqx 'command_link="/usr/local/bin/antigravity-ide"' "$helper_path"; then
  recognized_old_helper=yes
fi
if [ -f "$helper_path" ] &&
   ! $SUDO grep -Fqx "$helper_marker" "$helper_path" &&
   [ "$recognized_old_helper" != yes ]; then
  printf '%s is not a recognized LinuxCapable helper; move it before continuing.\n' "$helper_path" >&2
  exit 1
fi

helper_tmp=$(mktemp "${TMPDIR:-/tmp}/update-antigravity-ide.XXXXXX")
trap 'rm -f -- "$helper_tmp"' EXIT
cat >"$helper_tmp" <<'EOF'
#!/usr/bin/env bash
# LinuxCapable-Managed: google-antigravity-ide-helper-v1
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo: sudo update-antigravity-ide" >&2
	exit 1
fi

download_page="https://antigravity.google/download"
install_root="/opt/antigravity-ide"
command_link="/usr/local/bin/antigravity-ide"
desktop_file="/usr/share/applications/antigravity-ide.desktop"
icon_file="/usr/share/icons/hicolor/512x512/apps/antigravity-ide.png"
managed_id="google-antigravity-ide-v1"
root_marker="$install_root/.linuxcapable-managed"
sandbox_path="$install_root/Antigravity-IDE/chrome-sandbox"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/antigravity-ide-update.XXXXXX")
archive="$tmpdir/antigravity-ide.tar.gz"
archive_list="$tmpdir/archive.list"
desktop_staged="$tmpdir/antigravity-ide.desktop"
stage_root=''
backup_root=''
committed=no
new_root_installed=no
root_owned=no
root_legacy_owned=no
desktop_legacy_owned=no

cleanup() {
	status=$?
	trap - EXIT
	if [ "$status" -ne 0 ] && [ "$new_root_installed" = yes ] && [ -n "$backup_root" ] && [ -d "$backup_root" ]; then
		rm -rf "$install_root"
		mv "$backup_root" "$install_root"
		backup_root=''
	fi
	rm -rf "$tmpdir"
	if [ -n "$stage_root" ]; then
		rm -rf "$stage_root"
	fi
	if [ "$committed" = yes ] && [ -n "$backup_root" ] && [ -d "$backup_root" ]; then
		rm -rf "$backup_root"
	fi
	exit "$status"
}
trap cleanup EXIT

arch=$(uname -m)
case "$arch" in
x86_64) platform="linux-x64" ;;
aarch64 | arm64) platform="linux-arm64" ;;
*)
	echo "Unsupported architecture: $arch" >&2
	exit 1
	;;
esac

html_file="$tmpdir/download.html"
if [ -n "${ANTIGRAVITY_URL:-}" ]; then
	download_url=$(
		python3 - "$platform" "$ANTIGRAVITY_URL" <<'PY'
import sys, urllib.parse

platform, raw_url = sys.argv[1:]
parsed = urllib.parse.urlsplit(raw_url.strip())
decoded_path = urllib.parse.unquote(parsed.path)
if parsed.scheme != "https" or parsed.netloc != "edgedl.me.gvt1.com":
    raise SystemExit(f"Unsafe or unsupported Antigravity URL host: {raw_url}")
if "antigravity/stable/" not in parsed.path or f"/{platform}/" not in decoded_path:
    raise SystemExit(f"URL does not match expected platform ({platform}): {raw_url}")
print(raw_url.strip())
PY
	)
else
	curl -fsSL --compressed --proto '=https' --proto-redir '=https' --retry 3 "$download_page" > "$html_file"
	download_url=$(
		python3 - "$platform" "$html_file" <<'PY'
import html, re, sys, urllib.parse

platform = sys.argv[1]
html_file = sys.argv[2]
with open(html_file, encoding="utf-8", errors="replace") as f:
    content = f.read()

raw_urls = re.findall(r'href="([^"]+)"', content)
raw_urls += re.findall(r'https://edgedl\.me\.gvt1\.com/[^"\'\s<>]+', content)

candidates = []
for href in raw_urls:
    url = urllib.parse.urljoin("https://antigravity.google/download", html.unescape(href))
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or parsed.netloc != "edgedl.me.gvt1.com":
        continue
    if "antigravity/stable/" not in parsed.path:
        continue
    decoded_path = urllib.parse.unquote(parsed.path)
    if f"/{platform}/" not in decoded_path:
        continue
    if "Antigravity IDE" not in decoded_path and "Antigravity%20IDE" not in parsed.path:
        continue
    if url not in candidates:
        candidates.append(url)

if not candidates:
    raise SystemExit("No Antigravity IDE download URL found (try --url <official-tar-gz-url>)")

print(candidates[0])
PY
	)
fi

version=$(
	python3 - "$download_url" "$platform" <<'PY'
import re, sys, urllib.parse

url, platform = sys.argv[1:]
path = urllib.parse.unquote(urllib.parse.urlsplit(url).path)
match = re.search(r'/antigravity/stable/([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9]+)?)/', path)
if not match:
    raise SystemExit(f"Could not parse Antigravity IDE version from URL: {url}")

print(match.group(1))
PY
)

archive_top_dir="Antigravity IDE"
install_dir="Antigravity-IDE"
expected_target="$install_root/$install_dir/antigravity-ide"
legacy_expected_target="$install_root/antigravity-ide"

if [ -L "$command_link" ]; then
	:
elif [ -e "$command_link" ]; then
	echo "$command_link is not a symlink. Move it before rerunning this helper." >&2
	exit 1
fi

desktop_exec="$command_link --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations %U"

if [ -L "$desktop_file" ]; then
	echo "$desktop_file is a symlink. Move it before rerunning this helper." >&2
	exit 1
elif [ -f "$desktop_file" ]; then
	if grep -Fqx "X-LinuxCapable-Managed=$managed_id" "$desktop_file"; then
		:
	elif grep -Fq "Exec=$command_link" "$desktop_file" &&
		grep -q '^Icon=antigravity-ide$' "$desktop_file" &&
		grep -q '^StartupWMClass=antigravity-ide$' "$desktop_file"; then
		desktop_legacy_owned=yes
	else
		echo "$desktop_file is not a recognized LinuxCapable desktop file. Move it before rerunning this helper." >&2
		exit 1
	fi
fi

if [ -L "$install_root" ]; then
	echo "$install_root is a symlink. Move it before rerunning this helper." >&2
	exit 1
elif [ -d "$install_root" ]; then
	if [ -f "$root_marker" ] && [ "$(cat "$root_marker")" = "$managed_id" ]; then
		root_owned=yes
	elif [ -f "$install_root/.linuxcapable-version" ] &&
		{ [ -x "$expected_target" ] || [ -x "$legacy_expected_target" ]; }; then
		root_owned=yes
		root_legacy_owned=yes
	else
		echo "$install_root is not a recognized LinuxCapable install. Move it before rerunning this helper." >&2
		exit 1
	fi
fi

installed_version=$(cat "$install_root/.linuxcapable-version" 2>/dev/null || true)
desktop_matches=no
if [ -f "$desktop_file" ] &&
	grep -Fqx "Exec=$desktop_exec" "$desktop_file" &&
	grep -q '^Icon=antigravity-ide$' "$desktop_file" &&
	grep -q '^StartupWMClass=antigravity-ide$' "$desktop_file"; then
	desktop_matches=yes
fi
payload_permissions_ok=no
if [ -d "$install_root/$install_dir" ] &&
	! find "$install_root/$install_dir" -xdev \
		\( -type d ! -perm -0005 -o -type f ! -perm -0004 \) \
		-print -quit | grep -q . &&
	find "$expected_target" -maxdepth 0 -type f -perm -0001 -print -quit | grep -q .; then
	payload_permissions_ok=yes
fi
kio_sys_file="/usr/share/kio/servicemenus/open-in-antigravity-ide.desktop"
install_kio_servicemenu() {
	mkdir -p "$(dirname "$kio_sys_file")"
	cat <<KIO_EOF > "$kio_sys_file"
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
X-KDE-ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;
Actions=openInAntigravityIDE;
X-KDE-Priority=TopLevel

[Desktop Action openInAntigravityIDE]
Name=Abrir con Antigravity IDE
Name[es]=Abrir con Antigravity IDE
Name[en]=Open in Antigravity IDE
Icon=antigravity-ide
Exec=$command_link --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations %F
KIO_EOF
	chmod 0755 "$kio_sys_file"
}

if [ "$installed_version" = "$version" ] &&
	[ -x "$expected_target" ] &&
	[ "$(stat -c '%U:%G:%a' "$install_root/$install_dir")" = "root:root:755" ] &&
	[ "$payload_permissions_ok" = yes ] &&
	[ -L "$command_link" ] &&
	[ "$(readlink -f "$command_link")" = "$expected_target" ] &&
	[ "$desktop_matches" = yes ] &&
	[ -f "$icon_file" ]; then
	if [ -f "$sandbox_path" ] && [ ! -L "$sandbox_path" ] &&
	   [ "$(stat -c '%U:%G:%a' "$sandbox_path")" = "root:root:4755" ]; then
		if [ "$root_legacy_owned" = yes ]; then
			printf '%s\n' "$managed_id" >"$root_marker"
		fi
		if [ "$desktop_legacy_owned" = yes ]; then
			printf 'X-LinuxCapable-Managed=%s\n' "$managed_id" >>"$desktop_file"
		fi
		install_kio_servicemenu
		printf 'Antigravity IDE %s is already installed at %s\n' "$version" "$install_root/$install_dir"
		exit 0
	fi
fi

printf 'Downloading Antigravity IDE %s for %s...\n' "$version" "$platform"
curl -fsSL --proto '=https' --proto-redir '=https' --retry 3 -o "$archive" "$download_url"
python3 - "$archive" "$archive_top_dir" <<'PY'
import sys
import tarfile
from pathlib import PurePosixPath

archive_path, expected_top = sys.argv[1:]
top_dirs = set()
with tarfile.open(archive_path, "r:gz") as archive:
    for member in archive.getmembers():
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or not path.parts:
            raise SystemExit(f"Unsafe archive member: {member.name}")
        top_dirs.add(path.parts[0])
        if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
            raise SystemExit(f"Unsupported archive member type: {member.name}")
        if member.issym() or member.islnk():
            target = PurePosixPath(member.linkname)
            if target.is_absolute() or ".." in target.parts:
                raise SystemExit(f"Unsafe archive link: {member.name} -> {member.linkname}")
if top_dirs != {expected_top}:
    raise SystemExit(f"Unexpected archive roots: {sorted(top_dirs)}")
PY
tar -tzf "$archive" >"$archive_list"
top_dir=$(sed -n '1{s#/.*##;p;q}' "$archive_list")
if [ "$top_dir" != "$archive_top_dir" ]; then
	echo "Unexpected archive directory: $top_dir" >&2
	exit 1
fi

tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$tmpdir"
chmod -R a-s -- "$tmpdir/$archive_top_dir"
if find "$tmpdir/$archive_top_dir" -xdev -perm /6000 -print -quit | grep -q .; then
	echo 'The extracted Antigravity IDE archive still contains a set-ID path.' >&2
	exit 1
fi
if [ ! -x "$tmpdir/$archive_top_dir/antigravity-ide" ]; then
	echo "The Antigravity IDE launcher was not found in the archive." >&2
	exit 1
fi

icon_source="$tmpdir/$archive_top_dir/resources/app/resources/linux/code.png"
if [ ! -f "$icon_source" ]; then
	echo "The Antigravity IDE icon was not found in the archive." >&2
	exit 1
fi

cat >"$desktop_staged" <<DESKTOP
[Desktop Entry]
Name=Antigravity IDE
Comment=Google Antigravity IDE
Exec=$desktop_exec
Icon=antigravity-ide
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=x-scheme-handler/antigravity-ide;application/x-antigravity-workspace;
StartupNotify=true
StartupWMClass=antigravity-ide
X-LinuxCapable-Managed=$managed_id
DESKTOP
desktop-file-validate "$desktop_staged"

stage_root=$(mktemp -d "${install_root}.new.XXXXXX")
chmod 0755 "$stage_root"
printf '%s\n' "$managed_id" >"$stage_root/.linuxcapable-managed"
mkdir -p "$stage_root/$install_dir"
cp -a "$tmpdir/$archive_top_dir/." "$stage_root/$install_dir/"
chmod -R a+rX -- "$stage_root/$install_dir"
chown root:root "$stage_root/$install_dir"
chmod 0755 "$stage_root/$install_dir"
printf '%s\n' "$version" >"$stage_root/.linuxcapable-version"
if [ ! -f "$stage_root/$install_dir/chrome-sandbox" ] || [ -L "$stage_root/$install_dir/chrome-sandbox" ]; then
	echo 'The staged Antigravity IDE Chromium sandbox helper is missing or invalid.' >&2
	exit 1
fi
chown root:root "$stage_root/$install_dir/chrome-sandbox"
chmod 4755 "$stage_root/$install_dir/chrome-sandbox"
if [ ! -x "$stage_root/$install_dir/antigravity-ide" ]; then
	echo 'The staged Antigravity IDE launcher is not executable.' >&2
	exit 1
fi
if [ -d "$install_root" ]; then
	backup_root=$(mktemp -d "${install_root}.previous.XXXXXX")
	rmdir -- "$backup_root"
	mv -- "$install_root" "$backup_root"
fi
mv -- "$stage_root" "$install_root"
stage_root=''
new_root_installed=yes
ln -sfn "$install_root/$install_dir/antigravity-ide" "$command_link"

mkdir -p "$(dirname "$icon_file")"
install -m 0644 "$icon_source" "$icon_file"
install -m 0644 "$desktop_staged" "$desktop_file"
install_kio_servicemenu

if command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
	gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
fi

payload_permissions_ok=no
if ! find "$install_root/$install_dir" -xdev \
	\( -type d ! -perm -0005 -o -type f ! -perm -0004 \) \
	-print -quit | grep -q . &&
	find "$install_root/$install_dir/antigravity-ide" -maxdepth 0 \
		-type f -perm -0001 -print -quit | grep -q .; then
	payload_permissions_ok=yes
fi
if [ ! -x "$install_root/$install_dir/antigravity-ide" ] ||
   [ "$(stat -c '%U:%G:%a' "$install_root/$install_dir")" != "root:root:755" ] ||
   [ "$payload_permissions_ok" != yes ] ||
   [ ! -L "$command_link" ] ||
   [ "$(readlink -f "$command_link")" != "$install_root/$install_dir/antigravity-ide" ] ||
   ! grep -Fqx "X-LinuxCapable-Managed=$managed_id" "$desktop_file" ||
   [ ! -f "$icon_file" ]; then
  echo 'Final Antigravity IDE integration checks failed.' >&2
  exit 1
fi
if [ ! -f "$sandbox_path" ] || [ -L "$sandbox_path" ] ||
   [ "$(stat -c '%U:%G:%a' "$sandbox_path")" != 'root:root:4755' ]; then
  echo 'Final Antigravity IDE sandbox check failed.' >&2
  exit 1
fi

committed=yes
printf 'Installed Antigravity IDE %s at %s\n' "$version" "$install_root/$install_dir"
EOF

bash -n "$helper_tmp"
$SUDO install -m 0755 "$helper_tmp" "$helper_path"
echo "Helper installed at $helper_path"

# --- Install / Update Antigravity IDE ---
echo "[3/4] Installing Antigravity IDE..."
if [ -n "$TARGET_URL" ]; then
    $SUDO env ANTIGRAVITY_URL="$TARGET_URL" "$helper_path"
else
    $SUDO "$helper_path"
fi

# --- Verification ---
echo "[4/4] Verifying installation..."
launcher=$(readlink -f /usr/local/bin/antigravity-ide)
if test -x "$launcher"; then
  echo "  Launcher: $launcher (OK)"
else
  echo "  Launcher: NOT FOUND" >&2
  exit 1
fi

if test -f /usr/share/icons/hicolor/512x512/apps/antigravity-ide.png; then
  echo "  Icon: installed (OK)"
else
  echo "  Icon: NOT FOUND" >&2
  exit 1
fi

echo ""
echo "Desktop file entries:"
grep -E '^(Name|Exec|Icon|Categories|StartupWMClass)=' /usr/share/applications/antigravity-ide.desktop

echo ""
echo "Sandbox permissions:"
stat -c '%U %G %a %n' /opt/antigravity-ide/Antigravity-IDE/chrome-sandbox

echo ""
echo "=== Antigravity IDE installed successfully ==="

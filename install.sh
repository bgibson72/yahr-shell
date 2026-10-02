#!/usr/bin/env bash
# Yahr Shell installer — unattended, for a minimal Arch Linux system.
# Clone the repo and run ./install.sh. It installs the desktop, fonts,
# themes, and wallpapers, then signs you in through the SDDM greeter.
# No prompts. Works from any clone path and any username.
set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $*"; }
ok()      { echo -e "${GREEN}[ok]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[x]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
MINIMAL=false
SKIP_PACKAGES=false
PRINT_PLAN=false
AUR_HELPER=""
MULTILIB=false
HYPR_PAUSED=false
SUDO_TIMEOUT_INSTALLED=false
# Pinned Google Fonts file. The AUR ttf-manrope package still points at
# https://r2.fontsource.org/fonts/manrope@5.2.5/download.zip, which 404s.
MANROPE_COMMIT="b31870aff700ab7a1d74fa0c6887d95beb9e0037"
MANROPE_SHA256="3ae11c49db0455a3cc33e37d380f20fdb8c7f8b41dc07625c177e3d87a9d6ae6"
MANROPE_URL="https://raw.githubusercontent.com/google/fonts/${MANROPE_COMMIT}/ofl/manrope/Manrope%5Bwght%5D.ttf"

usage() {
    cat <<EOF
Usage: ./install.sh [options]

Install a complete Yahr Shell from this clone. The default run is
unattended: packages, fonts, bundled themes, wallpapers, and the SDDM
greeter are all installed. Reboot and sign in on the Yahr greeter.

  --minimal        Skip Firefox (the shell itself is still installed)
  --skip-packages  Refresh configs, themes, and wallpapers only
  --print-plan     Print the package list and exit
  --help           Show this message

Clone root is detected as: $REPO_ROOT
EOF
}

if [ "${YAHR_INSTALL_SOURCE_ONLY:-0}" != 1 ]; then
    while [ $# -gt 0 ]; do
        case "$1" in
            --yolo|--with-sddm) ;;
            --minimal) MINIMAL=true ;;
            --skip-packages) SKIP_PACKAGES=true ;;
            --print-plan) PRINT_PLAN=true ;;
            --help|-h) usage; exit 0 ;;
            *) err "Unknown option: $1"; usage; exit 1 ;;
        esac
        shift
    done

    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        err "Do not run as root. The script will sudo when needed."
        exit 1
    fi
fi

command_exists() { command -v "$1" >/dev/null 2>&1; }

is_arch() {
    if [ -f /etc/arch-release ]; then
        return 0
    fi
    if [ ! -f /etc/os-release ]; then
        return 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
        arch:*|*:*arch*|cachyos:*|endeavouros:*) return 0 ;;
    esac
    return 1
}

gpu_text() {
    lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' || true
}

require_arch() {
    if is_arch; then
        return 0
    fi
    if [ "$SKIP_PACKAGES" = true ] || [ "$PRINT_PLAN" = true ]; then
        warn "Not Arch Linux (${PRETTY_NAME:-unknown}). Continuing because this run does not install packages."
        return 0
    fi
    err "This installer requires Arch Linux (pacman). Detected: ${PRETTY_NAME:-unknown}."
    err "On Arch: git clone the repo and run ./install.sh"
    exit 1
}

preflight() {
    if [ ! -f "$REPO_ROOT/theme-engine/yahr-theme" ] || [ ! -d "$REPO_ROOT/quickshell" ] || [ ! -d "$REPO_ROOT/hypr" ]; then
        err "Run this script from a yahr-shell clone (missing theme-engine/, quickshell/, or hypr/)."
        exit 1
    fi
    if [ ! -d "$REPO_ROOT/themes" ] || [ ! -d "$REPO_ROOT/wallpapers" ]; then
        err "This clone is missing themes/ or wallpapers/."
        exit 1
    fi

    if [ "$SKIP_PACKAGES" = true ] || [ "$PRINT_PLAN" = true ]; then
        export PATH="$HOME/.local/bin:$PATH"
        return 0
    fi

    if ! command_exists sudo; then
        err "sudo is required."
        exit 1
    fi
    if ! sudo -v; then
        err "Could not obtain sudo credentials."
        exit 1
    fi
    hold_sudo

    export PATH="$HOME/.local/bin:$PATH"
}

# Exit trap. A failed command must not change the installer's exit status,
# and must not sit on a sudo or Hyprland prompt.
cleanup() {
    local status=$?
    if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    if [ "${SUDO_TIMEOUT_INSTALLED:-false}" = true ]; then
        sudo -n rm -f /etc/sudoers.d/99-yahr-install-timeout 2>/dev/null || true
    fi
    if [ "${HYPR_PAUSED:-false}" = true ]; then
        resume_hypr_reload
    fi
    exit "$status"
}

hold_sudo() {
    local tmp user
    user="$(id -un)"
    tmp="$(mktemp)"
    # Default sudo tickets expire while a font package compiles. makepkg then
    # blocks on "sudo: timed out reading password". Stretch the ticket for
    # this user and remove the rule when the installer exits.
    printf 'Defaults:%s timestamp_timeout=120\n' "$user" > "$tmp"
    if sudo visudo -c -f "$tmp" >/dev/null 2>&1; then
        sudo cp "$tmp" /etc/sudoers.d/99-yahr-install-timeout
        sudo chmod 0440 /etc/sudoers.d/99-yahr-install-timeout
        SUDO_TIMEOUT_INSTALLED=true
    fi
    rm -f "$tmp"
    sudo -v
    ( while true; do sudo -n -v; sleep 20; kill -0 "$$" || exit; done ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
}

enable_multilib() {
    if [ ! -f /etc/pacman.conf ]; then
        return 1
    fi
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        MULTILIB=true
        return 0
    fi
    info "Enabling the multilib repository…"
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        MULTILIB=true
        return 0
    fi
    warn "Could not enable multilib. 32-bit GPU libraries will be skipped."
    return 1
}

install_aur_helper() {
    if command_exists yay; then AUR_HELPER=yay; return; fi
    if command_exists paru; then AUR_HELPER=paru; return; fi
    info "Installing yay…"
    sudo pacman -S --needed --noconfirm git base-devel
    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    if ! command_exists yay; then
        err "Failed to install yay."
        exit 1
    fi
    AUR_HELPER=yay
}

pkg_install() {
    if [ "$#" -eq 0 ]; then
        return 0
    fi
    # Refresh the ticket immediately before a build. --sudoloop keeps it
    # alive while makepkg is compiling, which is when a bare keepalive loses
    # the race and sudo sits until "timed out reading password".
    sudo -v
    # --aur keeps these names off the repository provider search. Without it,
    # yay treats an installed mesa-rk35xx-git as the provider of mesa and
    # rebuilds that Rockchip fork.
    if [ "$AUR_HELPER" = "yay" ]; then
        yay -S --aur --needed --noconfirm \
            --answerdiff None --answeredit None --answerclean All --answerupgrade None \
            --sudoloop --removemake "$@"
    else
        paru -S --aur --needed --noconfirm --skipreview --sudoloop "$@"
    fi
}

# Official-repo packages. Order is not significant.
repo_packages() {
    local pkgs=(
        git base-devel curl pciutils
        mesa vulkan-icd-loader
        wayland xorg-xwayland libinput xf86-input-libinput seatd polkit
        # QML modules the shell and greeter import. quickshell and sddm do not
        # depend on qt6-5compat; Settings and the greeter import
        # Qt5Compat.GraphicalEffects, which lives in that package.
        qt6-base qt6-declarative qt6-wayland qt6-svg qt6-imageformats \
        qt6-5compat qt6-shadertools
        hyprland quickshell ghostty mako libnotify swww
        hyprlock hypridle hyprshot hyprpolkitagent grim slurp
        thunar tumbler gvfs ffmpegthumbnailer
        thunar-archive-plugin thunar-media-tags-plugin thunar-volman file-roller
        papirus-icon-theme adw-gtk-theme
        qt6ct nwg-look
        xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
        pipewire pipewire-pulse pipewire-alsa wireplumber libpulse pavucontrol
        networkmanager bluez bluez-utils blueman upower accountsservice
        brightnessctl cliphist wl-clipboard playerctl jq imagemagick
        python python-gobject gtk3 xdg-utils
        lm_sensors pacman-contrib
        starship xdg-user-dirs sddm
        ttf-nerd-fonts-symbols noto-fonts-emoji ttf-jetbrains-mono-nerd
        inter-font adobe-source-sans-fonts ttf-roboto ttf-ibm-plex
        otf-overpass otf-overpass-nerd
    )
    if [ "$MINIMAL" = false ]; then
        pkgs+=(firefox)
    fi
    if [ "$MULTILIB" = true ]; then
        pkgs+=(lib32-mesa)
    fi

    local gpu headers kern
    gpu="$(gpu_text)"
    headers=()
    if echo "$gpu" | grep -qi nvidia; then
        for kern in linux linux-lts linux-zen linux-hardened; do
            if pacman -Q "$kern" &>/dev/null; then
                headers+=("${kern}-headers")
            fi
        done
        if [ "${#headers[@]}" -eq 0 ]; then
            headers+=(linux-headers)
        fi
        pkgs+=(nvidia-dkms nvidia-utils nvidia-settings "${headers[@]}")
        if [ "$MULTILIB" = true ]; then
            pkgs+=(lib32-nvidia-utils)
        fi
    fi
    if echo "$gpu" | grep -qiE 'amd|radeon|advanced micro'; then
        pkgs+=(vulkan-radeon mesa-vdpau libva-mesa-driver)
        if [ "$MULTILIB" = true ]; then
            pkgs+=(lib32-vulkan-radeon lib32-mesa-vdpau)
        fi
    fi
    if echo "$gpu" | grep -qi intel; then
        pkgs+=(vulkan-intel intel-media-driver)
        if [ "$MULTILIB" = true ]; then
            pkgs+=(lib32-vulkan-intel)
        fi
    fi
    printf '%s\n' "${pkgs[@]}"
}

# AUR packages the shell needs that are not in the official repos.
# Roboto Flex is not installed: the settings catalog falls back to Roboto
# (ttf-roboto). Manrope is downloaded separately; the AUR PKGBUILD 404s.
aur_packages() {
    printf '%s\n' \
        papirus-folders-git \
        bibata-cursor-theme \
        otf-space-grotesk
}

# pacman --noconfirm answers "no" to "Remove <package>?", then aborts.
# Drop the conflicting -git builds first so the repository packages can
# take their place. mesa-rk35xx-git provides mesa, but it is a Rockchip
# fork whose Rust build does not finish on this desktop.
replace_conflicting_packages() {
    if ! command_exists pacman; then
        return 0
    fi
    local pkg replacement
    local -a swaps=(
        "quickshell-git:quickshell"
        "mesa-rk35xx-git:mesa"
    )
    for pkg in "${swaps[@]}"; do
        replacement="${pkg#*:}"
        pkg="${pkg%%:*}"
        if pacman -Q "$pkg" &>/dev/null; then
            info "Replacing $pkg with the repository $replacement package…"
            sudo pacman -Rdd --noconfirm "$pkg"
        fi
    done
}

install_manrope_font() {
    if command_exists fc-list && fc-list : family 2>/dev/null | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -qx 'Manrope'; then
        ok "Manrope is already installed."
        return 0
    fi
    info "Installing Manrope…"
    local tmp dest got
    tmp="$(mktemp)"
    dest="${YAHR_MANROPE_FONT_DIR:-/usr/share/fonts/manrope}"
    if ! curl -fsSL -o "$tmp" "$MANROPE_URL"; then
        rm -f "$tmp"
        err "Could not download Manrope from $MANROPE_URL"
        exit 1
    fi
    got="$(sha256sum "$tmp" | awk 'NR==1 { print $1 }')"
    if [ "$got" != "$MANROPE_SHA256" ]; then
        rm -f "$tmp"
        err "Manrope checksum did not match (got $got)."
        exit 1
    fi
    sudo mkdir -p "$dest"
    sudo install -m 0644 "$tmp" "$dest/Manrope[wght].ttf"
    rm -f "$tmp"
    if command_exists fc-cache; then
        fc-cache -f "$dest" >/dev/null 2>&1 || true
    fi
    ok "Manrope installed."
}

install_packages() {
    info "Refreshing pacman databases…"
    enable_multilib || true
    sudo pacman -Sy --noconfirm || warn "pacman -Sy failed; continuing with existing sync databases."

    install_aur_helper
    ok "AUR helper: $AUR_HELPER"

    replace_conflicting_packages
    local repo aur
    mapfile -t repo < <(repo_packages)
    mapfile -t aur < <(aur_packages)
    # Repository packages go through pacman. yay would also search the AUR
    # and can select mesa-rk35xx-git as the provider of mesa.
    info "Installing repository packages…"
    if ! sudo pacman -S --needed --noconfirm "${repo[@]}"; then
        err "Package installation failed."
        exit 1
    fi
    info "Installing AUR packages…"
    if ! pkg_install "${aur[@]}"; then
        err "Package installation failed."
        exit 1
    fi
    install_manrope_font
    ok "Packages installed."
}

configure_nvidia() {
    local gpu
    gpu="$(gpu_text)"
    if ! echo "$gpu" | grep -qi nvidia; then
        return 0
    fi
    info "Configuring NVIDIA modeset for Hyprland…"
    echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null
    if [ -f /etc/mkinitcpio.conf ] && ! grep -q '^MODULES=.*nvidia_drm' /etc/mkinitcpio.conf; then
        sudo sed -i -E 's/^MODULES=\(([^)]*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P || warn "mkinitcpio failed. Rebuild the initramfs before rebooting."
    fi
    ok "NVIDIA modeset configured. Reboot before the first Hyprland session."
}

# nvidia.lua is machine-local. Write it after the config sync so the sync
# cannot delete it, and drop a stale copy on machines without NVIDIA.
write_nvidia_lua() {
    local gpu dest
    dest="$HOME/.config/hypr/nvidia.lua"
    gpu="$(gpu_text)"
    if [ -z "$gpu" ]; then
        return 0
    fi
    if echo "$gpu" | grep -qi nvidia; then
        mkdir -p "$HOME/.config/hypr"
        cat > "$dest" <<'EOF'
-- Written by the Yahr installer when an NVIDIA GPU is present.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
EOF
        return 0
    fi
    rm -f "$dest"
}

install_sudoers() {
    local user tmp dest
    user="$(id -un)"
    dest="/etc/sudoers.d/yahr-shell"
    tmp="$(mktemp)"
    cat > "$tmp" <<EOF
# Yahr Shell: greeter theme sync and Papirus folder colors.
$user ALL=(ALL) NOPASSWD: /usr/bin/cp * /usr/share/sddm/themes/yahr-theme/*
$user ALL=(ALL) NOPASSWD: /usr/bin/tee /usr/share/sddm/themes/yahr-theme/theme.conf
$user ALL=(ALL) NOPASSWD: /usr/bin/cp * /usr/share/sddm/faces/*
$user ALL=(ALL) NOPASSWD: /usr/bin/papirus-folders
EOF
    sudo cp "$tmp" "$dest"
    sudo chmod 0440 "$dest"
    rm -f "$tmp"
    if sudo visudo -c -f "$dest" >/dev/null; then
        ok "Passwordless sudo for the greeter theme and Papirus folders."
    else
        sudo rm -f "$dest"
        warn "Rejected the Yahr sudoers file. Theme sync may ask for a password."
    fi
}

hyprctl_cmd() {
    if command_exists timeout; then
        timeout 10 hyprctl "$@"
    else
        hyprctl "$@"
    fi
}

# Hyprland ≥ 0.55 reloads Lua as soon as a watched file changes. Removing
# ~/.config/hypr, even for the moment between rm and cp, makes it try to
# open hyprland.lua, fail, and stay in emergency mode.
pause_hypr_reload() {
    HYPR_PAUSED=false
    if ! command_exists hyprctl; then
        return 0
    fi
    if hyprctl_cmd eval 'hl.config({ misc = { disable_autoreload = true }, debug = { suppress_errors = true } })' >/dev/null 2>&1 \
        || hyprctl_cmd keyword misc:disable_autoreload true >/dev/null 2>&1; then
        HYPR_PAUSED=true
    fi
}

resume_hypr_reload() {
    if ! command_exists hyprctl; then
        HYPR_PAUSED=false
        return 0
    fi
    if [ -s "$HOME/.config/hypr/hyprland.lua" ]; then
        if hyprctl_cmd reload >/dev/null 2>&1; then
            ok "Hyprland reloaded."
        fi
    fi
    hyprctl_cmd eval 'hl.config({ misc = { disable_autoreload = false }, debug = { suppress_errors = false } })' >/dev/null 2>&1 \
        || hyprctl_cmd keyword misc:disable_autoreload false >/dev/null 2>&1 \
        || true
    HYPR_PAUSED=false
}

# Copy src onto dest without deleting dest first. Extra files in dest that
# are not in src are removed afterwards. Names passed after dest are kept
# even when src does not have them (nvidia.lua).
sync_tree() {
    local src="$1" dest="$2"
    shift 2
    local path rel kept k list
    mkdir -p "$dest"
    cp -a "${src}/." "${dest}/"
    # Snapshot the tree before deleting. find running alongside rm misses files.
    list="$(mktemp)"
    find "$dest" -mindepth 1 -depth -print0 > "$list"
    while IFS= read -r -d '' path; do
        rel="${path#"${dest}"/}"
        kept=false
        for k in "$@"; do
            if [ "$rel" = "$k" ]; then
                kept=true
                break
            fi
        done
        if [ "$kept" = false ] && [ ! -e "${src}/${rel}" ]; then
            rm -rf "$path"
        fi
    done < "$list"
    rm -f "$list"
}

install_configs() {
    info "Installing configs, themes, and wallpapers into \$HOME…"
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/yahr-shell" \
        "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers" "$HOME/.cache/yahr" \
        "$HOME/.local/share/fonts"

    pause_hypr_reload
    sync_tree "$REPO_ROOT/hypr" "$HOME/.config/hypr" nvidia.lua
    write_nvidia_lua
    sync_tree "$REPO_ROOT/quickshell" "$HOME/.config/quickshell"
    sync_tree "$REPO_ROOT/ghostty" "$HOME/.config/ghostty"
    sync_tree "$REPO_ROOT/mako" "$HOME/.config/mako"
    if [ ! -s "$HOME/.config/hypr/hyprland.lua" ]; then
        err "Hyprland config is missing at $HOME/.config/hypr/hyprland.lua"
        exit 1
    fi
    mkdir -p "$HOME/.config/Thunar"
    cp -a "$REPO_ROOT/thunar/." "$HOME/.config/Thunar/" 2>/dev/null || true

    mkdir -p "$HOME/.config/qt6ct/colors" "$HOME/.config/yahr/themes" \
        "$HOME/.local/share/yahr-shell/themes" "$HOME/.local/share/yahr-shell/wallpapers"
    cp -a "$REPO_ROOT/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"
    cp -a "$REPO_ROOT/yahr/settings.json" "$HOME/.config/yahr/settings.json"
    cp -a "$REPO_ROOT/themes/." "$HOME/.local/share/yahr-shell/themes/"
    cp -a "$REPO_ROOT/wallpapers/." "$HOME/Pictures/Wallpapers/"
    cp -a "$REPO_ROOT/wallpapers/." "$HOME/.local/share/yahr-shell/wallpapers/"

    printf '%s\n' "$REPO_ROOT" > "$HOME/.config/yahr/repo-root"

    if [ -f "$REPO_ROOT/hypr/scripts/lock-info.py" ]; then
        install -m 0755 "$REPO_ROOT/hypr/scripts/lock-info.py" "$HOME/.config/yahr/lock-info.py"
    fi

    if [ -d "$REPO_ROOT/sddm" ]; then
        mkdir -p "$HOME/.local/share/yahr-shell/sddm"
        cp -a "$REPO_ROOT/sddm/." "$HOME/.local/share/yahr-shell/sddm/"
    fi

    mkdir -p "$HOME/.local/share/yahr-shell/theme-engine"
    cp -a "$REPO_ROOT/theme-engine/yahr_theme" "$HOME/.local/share/yahr-shell/theme-engine/"
    cat > "$HOME/.local/bin/yahr-theme" <<'WRAP'
#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.insert(0, str(Path.home() / ".local/share/yahr-shell/theme-engine"))
from yahr_theme.cli import main
if __name__ == "__main__":
    raise SystemExit(main())
WRAP
    chmod +x "$HOME/.local/bin/yahr-theme"

    chmod +x "$HOME/.config/quickshell/scripts/"* 2>/dev/null || true
    chmod +x "$HOME/.config/hypr/scripts/"* 2>/dev/null || true

    install -m 0755 "$REPO_ROOT/quickshell/scripts/yahr-calendar" "$HOME/.local/bin/yahr-calendar"
    install -m 0755 "$REPO_ROOT/quickshell/scripts/yahr-calculator" "$HOME/.local/bin/yahr-calculator"
    install -m 0755 "$REPO_ROOT/quickshell/scripts/yahr-keybinds" "$HOME/.local/bin/yahr-keybinds"

    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/yahr-calendar.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Yahr Calendar
Comment=Month, week, and day calendar with ICS import
Exec=$HOME/.local/bin/yahr-calendar
TryExec=$HOME/.local/bin/yahr-calendar
Icon=office-calendar
Terminal=false
Categories=Office;Calendar;Utility;
StartupNotify=false
Keywords=calendar;ics;ical;schedule;event;
EOF
    cat > "$HOME/.local/share/applications/yahr-calculator.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Yahr Calculator
Comment=Yahr calculator
Exec=$HOME/.local/bin/yahr-calculator
TryExec=$HOME/.local/bin/yahr-calculator
Icon=accessories-calculator
Terminal=false
Categories=Utility;Calculator;
StartupNotify=false
Keywords=calculator;calc;math;
EOF
    cat > "$HOME/.local/share/applications/yahr-keybinds.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Yahr Keybinds
Comment=View and customize Hyprland keybinds
Exec=$HOME/.local/bin/yahr-keybinds
TryExec=$HOME/.local/bin/yahr-keybinds
Icon=input-keyboard
Terminal=false
Categories=Settings;Utility;
StartupNotify=false
Keywords=keyboard;shortcuts;keybinds;hotkeys;hyprland;
EOF

    local bryan_home="/home/bryan"
    if command_exists find && command_exists sed; then
        while IFS= read -r -d '' f; do
            sed -i \
                -e "s|$bryan_home|$HOME|g" \
                -e "s|\$HOME/Projects/yahr-shell/quickshell|$HOME/.config/quickshell|g" \
                -e "s|$HOME/Projects/yahr-shell/quickshell|$HOME/.config/quickshell|g" \
                "$f" 2>/dev/null || true
        done < <(find "$HOME/.config/hypr" "$HOME/.config/quickshell" "$HOME/.config/yahr" \
            -type f \( -name '*.lua' -o -name '*.conf' -o -name '*.qml' -o -name '*.py' -o -name '*.sh' -o -name 'yahr-ipc' \) \
            -print0 2>/dev/null)
    fi

    if command_exists xdg-user-dirs-update; then
        xdg-user-dirs-update || true
    fi
    ok "Configs, themes, and wallpapers installed."
}

install_sddm_theme() {
    if [ ! -d "$REPO_ROOT/sddm/yahr-theme" ]; then
        err "SDDM theme missing from clone."
        exit 1
    fi
    info "Installing the Yahr SDDM greeter…"
    sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
    sudo rm -rf /usr/share/sddm/themes/yahr-theme
    sudo cp -a "$REPO_ROOT/sddm/yahr-theme" /usr/share/sddm/themes/yahr-theme
    echo -e "[Theme]\nCurrent=yahr-theme" | sudo tee /etc/sddm.conf.d/yahr.conf >/dev/null
    sudo systemctl enable sddm.service
    ok "SDDM will start the Yahr greeter on boot."
}

apply_default_theme() {
    export YAHR_THEMES="$HOME/.local/share/yahr-shell/themes"
    export PATH="$HOME/.local/bin:$PATH"
    info "Applying the Catppuccin theme…"
    if "$HOME/.local/bin/yahr-theme" apply catppuccin --no-reload; then
        ok "Catppuccin applied."
    else
        err "yahr-theme apply failed."
        exit 1
    fi
}

ensure_local_bin_path() {
    export PATH="$HOME/.local/bin:$PATH"
    # shellcheck disable=SC2016 # Keep $HOME literal for the user's shell rc.
    local line='export PATH="$HOME/.local/bin:$PATH"'
    local profile="$HOME/.bashrc"
    touch "$profile"
    if ! grep -qF '.local/bin' "$profile" 2>/dev/null; then
        printf '\n# Yahr Shell\n%s\n' "$line" >> "$profile"
    fi
}

ensure_starship() {
    if ! command_exists starship; then
        return 0
    fi
    local bashrc="$HOME/.bashrc"
    touch "$bashrc"
    if ! grep -q 'starship init bash' "$bashrc"; then
        # shellcheck disable=SC2016 # Keep the command substitution for the user's shell.
        printf '\n# Yahr Shell\neval "$(starship init bash)"\n' >> "$bashrc"
    fi
    if [ -f "$HOME/.zshrc" ] || command_exists zsh; then
        touch "$HOME/.zshrc"
        if ! grep -q 'starship init zsh' "$HOME/.zshrc"; then
            # shellcheck disable=SC2016 # Keep the command substitution for the user's shell.
            printf '\n# Yahr Shell\neval "$(starship init zsh)"\n' >> "$HOME/.zshrc"
        fi
    fi
}

enable_user_services() {
    local unit
    for unit in NetworkManager.service bluetooth.service upower.service; do
        if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
            sudo systemctl enable "$unit" || warn "Could not enable $unit"
        fi
    done
    local group
    for group in video input seat; do
        if getent group "$group" >/dev/null 2>&1; then
            sudo usermod -aG "$group" "$(id -un)" || true
        fi
    done
}

configure_session() {
    if [ "$SKIP_PACKAGES" = true ]; then
        return 0
    fi
    enable_user_services
    fc-cache -f >/dev/null 2>&1 || true
}

print_plan() {
    MULTILIB=true
    echo "Yahr Shell install plan"
    echo "Clone: $REPO_ROOT"
    echo "GPU:"
    gpu_text | sed 's/^/  /' || true
    echo "Official packages:"
    repo_packages | sed 's/^/  /'
    echo "AUR packages:"
    aur_packages | sed 's/^/  /'
    echo "Manrope:"
    echo "  $MANROPE_URL"
    echo "User content:"
    echo "  themes:     $(find "$REPO_ROOT/themes" -name '*.json' ! -name schema.json | wc -l) palettes"
    echo "  wallpapers: $(find "$REPO_ROOT/wallpapers" -type f | wc -l) files"
    echo "Greeter: SDDM theme yahr-theme, enabled on boot"
    echo "Session: Hyprland from the greeter (no TTY prompt)"
}

main() {
    trap cleanup EXIT
    echo ""
    echo "  Yahr Shell installer"
    echo "  Unattended Hyprland + Quickshell setup"
    echo "  Clone: $REPO_ROOT"
    echo "  Home:  $HOME"
    echo ""

    require_arch
    preflight

    if [ "$PRINT_PLAN" = true ]; then
        print_plan
        exit 0
    fi

    if [ "$SKIP_PACKAGES" = false ]; then
        install_packages
        configure_nvidia
        install_sudoers
    else
        ok "Skipping package install (--skip-packages)"
    fi

    install_configs
    if [ "$SKIP_PACKAGES" = false ]; then
        install_sddm_theme
    fi
    ensure_local_bin_path
    ensure_starship
    apply_default_theme
    resume_hypr_reload
    configure_session

    local themes wallpapers
    themes="$(find "$HOME/.local/share/yahr-shell/themes" -name '*.json' ! -name schema.json | wc -l)"
    wallpapers="$(find "$HOME/Pictures/Wallpapers" -type f | wc -l)"

    echo ""
    ok "Yahr Shell is installed."
    echo "  Themes:     $themes palettes in ~/.local/share/yahr-shell/themes"
    echo "  Wallpapers: $wallpapers files in ~/Pictures/Wallpapers"
    echo "  Quickshell: ~/.config/quickshell"
    echo "  Hyprland:   ~/.config/hypr"
    echo "  Theme CLI:  ~/.local/bin/yahr-theme"
    echo ""
    if [ "$SKIP_PACKAGES" = false ]; then
        echo "  Reboot, then sign in on the Yahr greeter. The session is Hyprland."
    else
        echo "  Configs were refreshed. Packages were left as they are."
    fi
    echo "  Super+T switches themes. Super+Return opens Ghostty."
    echo ""
}

if [ "${YAHR_INSTALL_SOURCE_ONLY:-0}" != 1 ]; then
    main
fi

#!/usr/bin/env bash
# Yahr Shell installer — Arch Linux, Hyprland + Quickshell daily driver.
# Works from any clone path and any username (no hardcoded ~/Projects or /home/$USER).
set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $*"; }
ok()      { echo -e "${GREEN}[ok]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[x]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
YOLO=false
MINIMAL=false
SKIP_PACKAGES=false
WITH_SDDM=false
AUR_HELPER=""

usage() {
    cat <<EOF
Usage: ./install.sh [options]

Install Yahr Shell from this clone into \$HOME (any username / clone path).

  --yolo           Unattended core install (yay, proprietary NVIDIA if needed)
  --minimal        Skip optional packages (Firefox, Neovim, Blueman, …)
  --skip-packages  Only install/link configs (assume deps already present)
  --with-sddm      Also deploy the optional SDDM theme (needs sudo)
  --help           Show this message

Clone root is detected as: $REPO_ROOT
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yolo) YOLO=true ;;
        --minimal) MINIMAL=true ;;
        --skip-packages) SKIP_PACKAGES=true ;;
        --with-sddm) WITH_SDDM=true ;;
        --help|-h) usage; exit 0 ;;
        *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    err "Do not run as root. The script will sudo when needed."
    exit 1
fi

ask() {
    local prompt="$1" default="${2:-y}"
    if [ "$YOLO" = true ]; then
        [ "$default" = "y" ]
        return
    fi
    local reply
    read -r -p "$prompt " reply
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[Yy]$ ]]
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

preflight() {
    if [ ! -f /etc/arch-release ] && [ ! -f /etc/os-release ]; then
        warn "Could not confirm Arch Linux; continuing anyway."
    elif [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}:${ID_LIKE:-}" in
            arch:*|*:*arch*|cachyos:*|endeavouros:*) ;;
            *)
                warn "This installer targets Arch (pacman/AUR). Detected: ${PRETTY_NAME:-unknown}."
                if ! ask "Continue anyway? [y/N]" n; then
                    exit 1
                fi
                ;;
        esac
    fi

    if [ ! -f "$REPO_ROOT/theme-engine/yahr-theme" ] || [ ! -d "$REPO_ROOT/quickshell" ] || [ ! -d "$REPO_ROOT/hypr" ]; then
        err "Run this script from a yahr-shell clone (missing theme-engine/, quickshell/, or hypr/)."
        exit 1
    fi

    if ! command_exists sudo; then
        err "sudo is required."
        exit 1
    fi
    if ! sudo -v; then
        err "Could not obtain sudo credentials."
        exit 1
    fi

    # Keep sudo alive during long AUR builds
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill '"$SUDO_KEEPALIVE_PID"' 2>/dev/null || true' EXIT

    export PATH="$HOME/.local/bin:$PATH"
}

ensure_local_bin_path() {
    export PATH="$HOME/.local/bin:$PATH"
    local line='export PATH="$HOME/.local/bin:$PATH"'
    local profile
    for profile in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$profile" ] || [ "$profile" = "$HOME/.profile" ]; then
            mkdir -p "$(dirname "$profile")"
            touch "$profile"
            if ! grep -qF '.local/bin' "$profile" 2>/dev/null; then
                printf '\n# Yahr Shell\n%s\n' "$line" >> "$profile"
                ok "Added ~/.local/bin to PATH in $profile"
            fi
            break
        fi
    done
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) warn "Add ~/.local/bin to PATH for new shells." ;;
    esac
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
    $AUR_HELPER -S --needed --noconfirm "$@"
}

detect_gpu_packages() {
    local gpu
    gpu="$(lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' || true)"
    local pkgs=()
    if echo "$gpu" | grep -qi nvidia; then
        pkgs+=(nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings)
    fi
    if echo "$gpu" | grep -qiE 'amd|radeon|advanced micro'; then
        pkgs+=(vulkan-radeon lib32-vulkan-radeon mesa-vdpau)
    fi
    if echo "$gpu" | grep -qi intel; then
        pkgs+=(vulkan-intel lib32-vulkan-intel intel-media-driver)
    fi
    pkgs+=(mesa vulkan-icd-loader)
    printf '%s\n' "${pkgs[@]}"
}

link_or_copy() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    cp -a "$src" "$dest"
}

install_packages() {
    info "Refreshing pacman databases…"
    sudo pacman -Sy --noconfirm || warn "pacman -Sy failed; continuing with existing sync DBs."

    install_aur_helper
    ok "AUR helper: $AUR_HELPER"

    info "Installing GPU / graphics stack…"
    mapfile -t GPU_PKGS < <(detect_gpu_packages)
    pkg_install "${GPU_PKGS[@]}" \
        wayland xorg-xwayland qt5-wayland qt6-wayland libinput seatd polkit \
        hyprpolkitagent

    info "Installing core desktop…"
    # hyprland is installed even if already present (--needed). imagemagick is
    # used by sddm-apply.py for wallpaper blur.
    pkg_install \
        hyprland quickshell-git ghostty mako libnotify swww \
        thunar tumbler gvfs thunar-archive-plugin file-roller \
        papirus-icon-theme papirus-folders-git bibata-cursor-theme adw-gtk-theme \
        qt6ct nwg-look \
        ttf-nerd-fonts-symbols noto-fonts-emoji ttf-inter \
        adobe-source-sans-fonts ttf-roboto ttf-ibm-plex otf-overpass \
        ttf-jetbrains-mono-nerd \
        pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol \
        networkmanager brightnessctl \
        hyprlock hypridle hyprshot grim slurp \
        cliphist wl-clipboard \
        python playerctl jq imagemagick \
        xdg-desktop-portal-hyprland

    if [ "$MINIMAL" = false ]; then
        $AUR_HELPER -S --needed --noconfirm ttf-maple ttf-inter ttf-manrope ttf-space-grotesk ttf-roboto-flex || true
        if ask "Install recommended extras (Firefox, blueman)? [Y/n]" y; then
            pkg_install firefox blueman bluez bluez-utils
        fi
        if ask "Install Neovim? [y/N]" n; then
            pkg_install neovim
        fi
    fi
}

install_configs() {
    info "Installing configs from $REPO_ROOT → \$HOME…"
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/yahr-shell" \
        "$HOME/Pictures/Screenshots" "$HOME/.cache/yahr"

    link_or_copy "$REPO_ROOT/hypr" "$HOME/.config/hypr"
    link_or_copy "$REPO_ROOT/quickshell" "$HOME/.config/quickshell"
    link_or_copy "$REPO_ROOT/ghostty" "$HOME/.config/ghostty"
    link_or_copy "$REPO_ROOT/mako" "$HOME/.config/mako"
    mkdir -p "$HOME/.config/Thunar"
    cp -a "$REPO_ROOT/thunar/." "$HOME/.config/Thunar/" 2>/dev/null || true

    mkdir -p "$HOME/.config/qt6ct/colors" "$HOME/.config/yahr/themes" \
        "$HOME/.local/share/yahr-shell/themes" "$HOME/Pictures/Wallpapers"
    cp -a "$REPO_ROOT/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"
    cp -a "$REPO_ROOT/yahr/settings.json" "$HOME/.config/yahr/settings.json"
    cp -a "$REPO_ROOT/themes/." "$HOME/.local/share/yahr-shell/themes/"
    if [ -d "$REPO_ROOT/wallpapers" ]; then
        cp -a "$REPO_ROOT/wallpapers/." "$HOME/Pictures/Wallpapers/"
    fi

    # Record clone root for optional tooling (never required at runtime).
    printf '%s\n' "$REPO_ROOT" > "$HOME/.config/yahr/repo-root"

    # lock-info must live under ~/.config/yahr for hyprlock (theme apply also copies it).
    if [ -f "$REPO_ROOT/hypr/scripts/lock-info.py" ]; then
        install -m 0755 "$REPO_ROOT/hypr/scripts/lock-info.py" "$HOME/.config/yahr/lock-info.py"
    fi

    # Optional SDDM helpers in share prefix for discoverability.
    if [ -d "$REPO_ROOT/sddm" ]; then
        mkdir -p "$HOME/.local/share/yahr-shell/sddm"
        cp -a "$REPO_ROOT/sddm/." "$HOME/.local/share/yahr-shell/sddm/"
    fi

    mkdir -p "$HOME/.local/share/yahr-shell/theme-engine"
    cp -a "$REPO_ROOT/theme-engine/yahr_theme" "$HOME/.local/share/yahr-shell/theme-engine/"
    # Rewrite the installed wrapper so it finds the package after copy
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

    # Make scripts executable (glob may be empty on partial trees)
    chmod +x "$HOME/.config/quickshell/scripts/"* 2>/dev/null || true
    chmod +x "$HOME/.config/hypr/scripts/"* 2>/dev/null || true

    install -m 0755 "$REPO_ROOT/quickshell/scripts/yahr-calendar" "$HOME/.local/bin/yahr-calendar"
    install -m 0755 "$REPO_ROOT/quickshell/scripts/yahr-calculator" "$HOME/.local/bin/yahr-calculator"
    install -m 0755 "$REPO_ROOT/quickshell/scripts/yahr-keybinds" "$HOME/.local/bin/yahr-keybinds"

    mkdir -p "$HOME/.local/share/applications"
    # Absolute Exec paths so .desktop works even when DE PATH lacks ~/.local/bin
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

    # Safety net: rewrite any leftover hardcoded bryan / Projects paths in installed configs.
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
}

install_sddm_theme() {
    if [ ! -d "$REPO_ROOT/sddm/yahr-theme" ]; then
        warn "SDDM theme missing from clone; skipping."
        return
    fi
    info "Deploying SDDM theme…"
    pkg_install sddm || warn "Could not install sddm package."
    sudo mkdir -p /usr/share/sddm/themes
    sudo cp -a "$REPO_ROOT/sddm/yahr-theme" /usr/share/sddm/themes/
    if [ -x "$REPO_ROOT/sddm/setup-sudoers.sh" ]; then
        info "Configuring passwordless sudo for SDDM theme sync…"
        "$REPO_ROOT/sddm/setup-sudoers.sh" || warn "setup-sudoers.sh failed; run it manually later."
    fi
    if [ -d /etc/sddm.conf.d ] || sudo mkdir -p /etc/sddm.conf.d; then
        echo -e "[Theme]\nCurrent=yahr-theme" | sudo tee /etc/sddm.conf.d/yahr.conf >/dev/null
    fi
    sudo systemctl enable sddm.service 2>/dev/null || true
    ok "SDDM theme installed (log out / reboot to use the greeter)."
}

apply_default_theme() {
    export YAHR_THEMES="$HOME/.local/share/yahr-shell/themes"
    export PATH="$HOME/.local/bin:$PATH"
    info "Applying default theme (Catppuccin)…"
    if "$HOME/.local/bin/yahr-theme" apply catppuccin --no-reload; then
        ok "Theme applied (hyprlock paths use \$HOME; lock-info installed)."
    else
        warn "Theme apply wrote what it could; reload after login if needed."
    fi
}

configure_session() {
    sudo systemctl enable --now NetworkManager.service 2>/dev/null || true

    if ! grep -q 'Hyprland' "$HOME/.bash_profile" 2>/dev/null \
        && ! grep -q 'Hyprland' "$HOME/.zprofile" 2>/dev/null \
        && ! grep -q 'Hyprland' "$HOME/.profile" 2>/dev/null; then
        if ask "Start Hyprland automatically from TTY1 on login? [Y/n]" y; then
            local profile="$HOME/.zprofile"
            if [ -f "$HOME/.zshrc" ] || [ -n "${ZSH_VERSION:-}" ]; then
                profile="$HOME/.zprofile"
            elif [ -f "$HOME/.bashrc" ] || [ -n "${BASH_VERSION:-}" ]; then
                profile="$HOME/.bash_profile"
            else
                profile="$HOME/.profile"
            fi
            mkdir -p "$(dirname "$profile")"
            touch "$profile"
            cat >> "$profile" <<'EOF'

# Yahr Shell — start Hyprland on TTY1
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" = 1 ]; then
    exec Hyprland
fi
EOF
            ok "Added Hyprland autostart to $profile"
        fi
    fi
}

main() {
    echo ""
    echo "  Yahr Shell installer"
    echo "  Hyprland + Quickshell with a single theme engine"
    echo "  Clone: $REPO_ROOT"
    echo "  Home:  $HOME"
    echo ""

    preflight

    if [ "$SKIP_PACKAGES" = false ]; then
        install_packages
    else
        ok "Skipping package install (--skip-packages)"
        if command_exists yay; then AUR_HELPER=yay
        elif command_exists paru; then AUR_HELPER=paru
        else AUR_HELPER=""
        fi
    fi

    install_configs
    ensure_local_bin_path
    apply_default_theme

    if [ "$WITH_SDDM" = true ] || { [ "$MINIMAL" = false ] && ask "Install optional SDDM greeter theme? [y/N]" n; }; then
        install_sddm_theme
    fi

    configure_session

    echo ""
    ok "Yahr Shell is installed."
    echo "  Quickshell config: ~/.config/quickshell"
    echo "  Hyprland config:   ~/.config/hypr"
    echo "  Theme CLI:         ~/.local/bin/yahr-theme"
    echo "  Clone recorded:    ~/.config/yahr/repo-root"
    echo ""
    echo "  Log in on TTY1 (or run Hyprland), then Super+T to switch themes."
    echo "  Custom palettes: Settings → Theme, or: yahr-theme save --name …"
    if [ ! -d /usr/share/sddm/themes/yahr-theme ]; then
        echo "  Optional SDDM: re-run with --with-sddm, or:"
        echo "    $REPO_ROOT/sddm/setup-sudoers.sh"
    fi
    echo ""
}

main

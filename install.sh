#!/usr/bin/env bash
# Yahr Shell installer — Arch Linux, Hyprland + Quickshell daily driver.
set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $*"; }
ok()      { echo -e "${GREEN}[ok]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[x]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YOLO=false
MINIMAL=false
AUR_HELPER=""

usage() {
    cat <<EOF
Usage: ./install.sh [--yolo] [--minimal] [--help]

  --yolo      Unattended core install (yay, proprietary NVIDIA if needed)
  --minimal   Skip optional packages (Firefox, Neovim, Blueman, …)
  --help      Show this message
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yolo) YOLO=true ;;
        --minimal) MINIMAL=true ;;
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
    AUR_HELPER=yay
}

pkg_install() {
    $AUR_HELPER -S --needed --noconfirm "$@"
}

detect_gpu_packages() {
    local gpu
    gpu="$(lspci | grep -Ei 'VGA|3D|Display' || true)"
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

main() {
    echo ""
    echo "  Yahr Shell installer"
    echo "  Hyprland + Quickshell with a single theme engine"
    echo ""

    install_aur_helper
    ok "AUR helper: $AUR_HELPER"

    info "Installing GPU / graphics stack…"
    mapfile -t GPU_PKGS < <(detect_gpu_packages)
    pkg_install "${GPU_PKGS[@]}" \
        wayland xorg-xwayland qt5-wayland qt6-wayland libinput seatd polkit \
        hyprpolkitagent

    info "Installing core desktop…"
    pkg_install \
        hyprland quickshell-git kitty mako libnotify swww \
        thunar tumbler gvfs thunar-archive-plugin file-roller \
        papirus-icon-theme papirus-folders-git adw-gtk-theme \
        qt6ct nwg-look \
        ttf-nerd-fonts-symbols noto-fonts-emoji ttf-inter \
        ttf-jetbrains-mono-nerd \
        pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol \
        networkmanager brightnessctl \
        hyprlock hypridle hyprshot grim slurp \
        cliphist wl-clipboard \
        python playerctl jq \
        xdg-desktop-portal-hyprland

    if [ "$MINIMAL" = false ]; then
        $AUR_HELPER -S --needed --noconfirm ttf-maple || true
        if ask "Install recommended extras (Firefox, blueman, fastfetch)? [Y/n]" y; then
            pkg_install firefox blueman bluez bluez-utils fastfetch
        fi
        if ask "Install Neovim? [y/N]" n; then
            pkg_install neovim
        fi
    fi

    info "Installing configs…"
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/yahr-shell" \
        "$HOME/Pictures/Screenshots"

    link_or_copy "$SCRIPT_DIR/hypr" "$HOME/.config/hypr"
    link_or_copy "$SCRIPT_DIR/quickshell" "$HOME/.config/quickshell"
    link_or_copy "$SCRIPT_DIR/kitty" "$HOME/.config/kitty"
    link_or_copy "$SCRIPT_DIR/mako" "$HOME/.config/mako"
    mkdir -p "$HOME/.config/Thunar"
    cp -a "$SCRIPT_DIR/thunar/." "$HOME/.config/Thunar/" 2>/dev/null || true

    mkdir -p "$HOME/.config/qt6ct/colors" "$HOME/.config/yahr/themes" \
        "$HOME/.local/share/yahr-shell/themes" "$HOME/Pictures/Wallpapers"
    cp -a "$SCRIPT_DIR/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"
    cp -a "$SCRIPT_DIR/yahr/settings.json" "$HOME/.config/yahr/settings.json"
    cp -a "$SCRIPT_DIR/themes/." "$HOME/.local/share/yahr-shell/themes/"
    cp -a "$SCRIPT_DIR/wallpapers/." "$HOME/Pictures/Wallpapers/"

    install -m 0755 "$SCRIPT_DIR/theme-engine/yahr-theme" "$HOME/.local/bin/yahr-theme"
    mkdir -p "$HOME/.local/share/yahr-shell/theme-engine"
    cp -a "$SCRIPT_DIR/theme-engine/yahr_theme" "$HOME/.local/share/yahr-shell/theme-engine/"
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
    chmod +x "$HOME/.config/quickshell/scripts/"*.py "$HOME/.config/quickshell/scripts/yahr-ipc"

    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) warn "Add ~/.local/bin to PATH (echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc)" ;;
    esac

    export YAHR_THEMES="$HOME/.local/share/yahr-shell/themes"
    info "Applying default theme (Catppuccin)…"
    "$HOME/.local/bin/yahr-theme" apply catppuccin --no-reload || warn "Theme apply wrote files; reload after login."

    sudo systemctl enable --now NetworkManager.service 2>/dev/null || true

    if ! grep -q 'Hyprland' "$HOME/.bash_profile" 2>/dev/null && ! grep -q 'Hyprland' "$HOME/.zprofile" 2>/dev/null; then
        if ask "Start Hyprland automatically from TTY1 on login? [Y/n]" y; then
            profile="$HOME/.zprofile"
            [ -f "$HOME/.zshrc" ] || [ -n "${ZSH_VERSION:-}" ] || profile="$HOME/.bash_profile"
            mkdir -p "$(dirname "$profile")"
            cat >> "$profile" <<'EOF'

# Yahr Shell — start Hyprland on TTY1
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" = 1 ]; then
    exec Hyprland
fi
EOF
            ok "Added Hyprland autostart to $profile"
        fi
    fi

    echo ""
    ok "Yahr Shell is installed."
    echo "  Log in on TTY1 (or run Hyprland), then Super+T to switch themes."
    echo "  Custom palettes: Settings → Theme, or: yahr-theme save --name …"
    echo ""
}

main

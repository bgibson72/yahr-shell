"""Filesystem locations for bundled palettes, user themes, and generated files."""

from __future__ import annotations

import os
from pathlib import Path


def home() -> Path:
    return Path(os.environ.get("HOME", str(Path.home())))


def repo_root() -> Path:
    """theme-engine/yahr_theme/paths.py -> checkout root, or share prefix when installed.

    After install the package lives at ~/.local/share/yahr-shell/theme-engine/,
    so parents[2] is the share prefix (themes/ present; hypr/quickshell are not).
    Prefer quickshell_dir() / lock_info_source() for scripts that only exist in
    the live config tree or a full git checkout.
    """
    return Path(__file__).resolve().parents[2]


def share_root() -> Path:
    return home() / ".local/share/yahr-shell"


def bundled_themes() -> Path:
    env = os.environ.get("YAHR_THEMES")
    if env:
        return Path(env)
    share = share_root() / "themes"
    if share.is_dir():
        return share
    return repo_root() / "themes"


def user_themes() -> Path:
    return home() / ".config/yahr/themes"


def yahr_config() -> Path:
    return home() / ".config/yahr"


def current_json() -> Path:
    return yahr_config() / "current.json"


def last_wallpaper() -> Path:
    return yahr_config() / "last-wallpaper"


def hypr_dir() -> Path:
    return home() / ".config/hypr"


def hypr_theme_lua() -> Path:
    return hypr_dir() / "theme.lua"


def quickshell_dir() -> Path:
    """Live Quickshell tree: ~/.config/quickshell after install, else checkout."""
    cfg = home() / ".config/quickshell"
    if (cfg / "shell.qml").is_file() or (cfg / "scripts").is_dir():
        return cfg
    checkout = repo_root() / "quickshell"
    if (checkout / "shell.qml").is_file() or (checkout / "scripts").is_dir():
        return checkout
    return cfg


def quickshell_script(name: str) -> Path:
    """Resolve a Quickshell helper script.

    Prefer the git checkout recorded in ~/.config/yahr/repo-root so wallpaper
    / SDDM sync picks up pulled fixes even when ~/.config/quickshell is an
    install.sh copy that has not been reinstalled.
    """
    repo_root_file = yahr_config() / "repo-root"
    if repo_root_file.is_file():
        try:
            root = Path(repo_root_file.read_text().strip()).expanduser()
            candidate = root / "quickshell" / "scripts" / name
            if candidate.is_file():
                return candidate
        except OSError:
            pass
    return quickshell_dir() / "scripts" / name


def lock_info_source() -> Path:
    """Best source of lock-info.py for install/copy into ~/.config/yahr/."""
    candidates = (
        hypr_dir() / "scripts" / "lock-info.py",
        repo_root() / "hypr" / "scripts" / "lock-info.py",
        yahr_config() / "lock-info.py",
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return hypr_dir() / "scripts" / "lock-info.py"


def starship_toml() -> Path:
    return home() / ".config/starship.toml"


def ghostty_dir() -> Path:
    return home() / ".config/ghostty"


def ghostty_config() -> Path:
    return ghostty_dir() / "config"


def ghostty_theme() -> Path:
    return ghostty_dir() / "themes" / "yahr"


def mako_config() -> Path:
    return home() / ".config/mako/config"


def hyprlock_conf() -> Path:
    return hypr_dir() / "hyprlock.conf"


def gtk3_css() -> Path:
    return home() / ".config/gtk-3.0/gtk.css"


def gtk3_settings() -> Path:
    return home() / ".config/gtk-3.0/settings.ini"


def gtk4_css() -> Path:
    return home() / ".config/gtk-4.0/gtk.css"


def cursor_settings_json() -> Path:
    return home() / ".config/Cursor/User/settings.json"


def qt6ct_colors() -> Path:
    return home() / ".config/qt6ct/colors/yahr.conf"


def wallpaper_root() -> Path:
    pictures = home() / "Pictures/Wallpapers"
    if pictures.is_dir():
        return pictures
    share = share_root() / "wallpapers"
    if share.is_dir():
        return share
    return repo_root() / "wallpapers"

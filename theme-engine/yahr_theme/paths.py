"""Filesystem locations for bundled palettes, user themes, and generated files."""

from __future__ import annotations

import os
from pathlib import Path


def home() -> Path:
    return Path(os.environ.get("HOME", str(Path.home())))


def repo_root() -> Path:
    """theme-engine/yahr_theme/paths.py -> yahr-shell/."""
    return Path(__file__).resolve().parents[2]


def bundled_themes() -> Path:
    env = os.environ.get("YAHR_THEMES")
    if env:
        return Path(env)
    share = home() / ".local/share/yahr-shell/themes"
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


def kitty_theme() -> Path:
    return home() / ".config/kitty/current-theme.conf"


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


def qt6ct_colors() -> Path:
    return home() / ".config/qt6ct/colors/yahr.conf"


def wallpaper_root() -> Path:
    pictures = home() / "Pictures/Wallpapers"
    if pictures.is_dir():
        return pictures
    return repo_root() / "wallpapers"

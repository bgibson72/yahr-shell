"""Load palettes and fan them out to Hyprland, GTK, Kitty, Mako, icons, lock, Qt."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

from . import paths, templates
from .colors import nearest_papirus, strip_hash


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text())


def iter_theme_files() -> list[Path]:
    files: dict[str, Path] = {}
    bundled = paths.bundled_themes()
    if bundled.is_dir():
        for p in bundled.glob("*.json"):
            if p.name == "schema.json":
                continue
            files[p.stem] = p
    user = paths.user_themes()
    if user.is_dir():
        for p in user.glob("*.json"):
            files[p.stem] = p  # user overrides bundled
    return sorted(files.values(), key=lambda p: p.stem)


def find_theme(theme_id: str) -> Path:
    needle = theme_id.strip().lower()
    for path in iter_theme_files():
        data = _read_json(path)
        if data.get("id", path.stem).lower() == needle or path.stem.lower() == needle:
            return path
        if data.get("name", "").lower() == needle:
            return path
    raise FileNotFoundError(f"theme not found: {theme_id}")


def list_themes() -> list[dict]:
    out = []
    current_id = None
    current = paths.current_json()
    if current.is_file():
        try:
            current_id = _read_json(current).get("id")
        except json.JSONDecodeError:
            current_id = None
    for path in iter_theme_files():
        data = _read_json(path)
        out.append({
            "id": data.get("id", path.stem),
            "name": data.get("name", path.stem),
            "custom": bool(data.get("custom")),
            "path": str(path),
            "active": data.get("id", path.stem) == current_id,
        })
    return out


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def _run(cmd: list[str], check: bool = False) -> subprocess.CompletedProcess | None:
    try:
        return subprocess.run(cmd, check=check, capture_output=True, text=True)
    except FileNotFoundError:
        return None


def _gsettings(schema: str, key: str, value: str) -> None:
    _run(["gsettings", "set", schema, key, value])


def _pick_wallpaper(palette: dict, previous: dict | None) -> Path | None:
    root = paths.wallpaper_root()
    folder = root / palette.get("wallpaperDir", palette.get("name", ""))
    if not folder.is_dir():
        return None
    images = sorted(
        p for p in folder.iterdir()
        if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp", ".gif"}
    )
    if not images:
        return None

    last = paths.last_wallpaper()
    current_file = last.read_text().strip() if last.is_file() else ""
    prev_dir = (previous or {}).get("wallpaperDir")
    if current_file:
        current_path = Path(current_file)
        # Keep a user-chosen wallpaper unless it belonged to the previous theme folder
        if current_path.is_file():
            if prev_dir and prev_dir in current_path.parts:
                return images[0]
            if palette.get("wallpaperDir") in current_path.parts:
                return current_path
            return current_path
    return images[0]


def apply_palette(palette: dict, *, reload: bool = True) -> None:
    previous = None
    if paths.current_json().is_file():
        try:
            previous = _read_json(paths.current_json())
        except json.JSONDecodeError:
            previous = None

    paths.yahr_config().mkdir(parents=True, exist_ok=True)
    _write(paths.current_json(), json.dumps(palette, indent=2) + "\n")
    _write(paths.hypr_theme_lua(), templates.hypr_theme_lua(palette))
    _write(paths.kitty_theme(), templates.kitty_theme(palette))
    _write(paths.mako_config(), templates.mako_config(palette))
    _write(paths.hyprlock_conf(), templates.hyprlock_conf(palette))
    css = templates.gtk_css(palette)
    _write(paths.gtk3_css(), css)
    _write(paths.gtk4_css(), css)
    _write(paths.gtk3_settings(), templates.gtk_settings_ini())
    gtk4_ini = paths.home() / ".config/gtk-4.0/settings.ini"
    _write(gtk4_ini, templates.gtk_settings_ini())
    _write(paths.qt6ct_colors(), templates.qt6ct_colors(palette))

    _gsettings("org.gnome.desktop.interface", "gtk-theme", "adw-gtk3-dark")
    _gsettings("org.gnome.desktop.interface", "icon-theme", "Papirus-Dark")
    _gsettings("org.gnome.desktop.interface", "color-scheme", "prefer-dark")
    _gsettings("org.gnome.desktop.interface", "accent-color", "blue")

    folder_color = nearest_papirus(palette["accentBlue"])
    papirus = shutil.which("papirus-folders")
    if papirus:
        result = _run(["papirus-folders", "-C", folder_color, "--theme", "Papirus-Dark"])
        if result and result.returncode != 0:
            _run(["sudo", "-n", papirus, "-C", folder_color, "--theme", "Papirus-Dark"])

    wallpaper = _pick_wallpaper(palette, previous)
    if wallpaper:
        paths.last_wallpaper().write_text(str(wallpaper) + "\n")
        if reload:
            _run(["swww", "img", str(wallpaper), "--transition-type", "fade", "--transition-duration", "0.6"])

    if not reload:
        return

    _run(["hyprctl", "reload"])
    _run(["makoctl", "reload"])
    _run(["kitty", "@", "set-colors", "--all", "--configured", str(paths.kitty_theme())])
    _run(["killall", "-SIGUSR1", "kitty"])
    # Thunar daemon picks up GTK CSS after a restart
    _run(["thunar", "-q"])
    _run(["killall", "thunar"])


def apply_id(theme_id: str, *, reload: bool = True) -> dict:
    path = find_theme(theme_id)
    palette = _read_json(path)
    apply_palette(palette, reload=reload)
    return palette


def save_palette(palette: dict, *, apply_now: bool = True) -> Path:
    dest = paths.user_themes()
    dest.mkdir(parents=True, exist_ok=True)
    path = dest / f"{palette['id']}.json"
    _write(path, json.dumps(palette, indent=2) + "\n")
    if apply_now:
        apply_palette(palette)
    return path


def delete_theme(theme_id: str) -> None:
    path = find_theme(theme_id)
    if path.parent.resolve() != paths.user_themes().resolve():
        raise PermissionError("only user-saved custom themes can be deleted")
    path.unlink()

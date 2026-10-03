"""Load palettes and fan them out to Hyprland, GTK, Ghostty, Starship, Mako, icons, lock, Qt."""

from __future__ import annotations

import json
import os
import random
import re
import shutil
import subprocess
import sys
from pathlib import Path

from . import paths, templates
from .colors import PAPIRUS_FOLDERS, PAPIRUS_TO_GNOME, nearest_gnome_accent, palette_mode, papirus_folder_for

# v1 shipped full GTK3 theme packages in ~/.themes (Materia forks).
# adw-gtk3 is not installed here, so we keep mapping palettes onto those.
GTK_THEME_MAP = {
    "catppuccin": "Catppuccin-Dark",
    "dracula": "Dracula",
    "eldritch": "Eldritch",
    "everforest": "Everforest-Dark",
    "gruvbox": "Gruvbox-Dark",
    "kanagawa": "Kanagawa-Dark-Dragon",
    "material": "Material-Dark-Palenight",
    "nightfox": "Nightfox-Dark-Duskfox",
    "nord": "Nordic",
    "rose-pine": "Rosepine-Dark",
    "solarized": "Osaka-Dark",
    "tokyo-night": "Tokyonight-Dark",
    "monochrome": "Catppuccin-Dark",
}


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
            "mode": palette_mode(data),
            "bgBase": data.get("bgBase", "#1e1e2e"),
            "fgPrimary": data.get("fgPrimary", "#cdd6f4"),
            "fgTertiary": data.get("fgTertiary", "#a6adc8"),
            "accentBlue": data.get("accentBlue", "#89b4fa"),
            "border0": data.get("border0", "#6c7086"),
        })
    return out


def _settings() -> dict:
    path = paths.yahr_config() / "settings.json"
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError, TypeError):
        return {}


def _ui_font() -> str:
    return str(_settings().get("general", {}).get("uiFont") or "Inter")


_IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}


def _wallpaper_images(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    return sorted(
        (p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in _IMAGE_EXTS),
        key=lambda p: p.name.lower(),
    )


def _theme_wallpaper_folder(palette: dict) -> Path | None:
    name = str(palette.get("wallpaperDir") or "").strip()
    if not name:
        return None
    configured = (_settings().get("wallpaper") or {}).get("directory") or "~/Pictures/Wallpapers"
    root = Path(os.path.expanduser(str(configured)))
    for candidate in (root / name, paths.wallpaper_root() / name):
        if candidate.is_dir():
            return candidate
    return None


def _path_in_folder(path: str, folder: Path) -> Path | None:
    if not path:
        return None
    try:
        resolved = Path(os.path.expanduser(path)).resolve()
        if resolved.is_file() and resolved.parent == folder.resolve():
            return resolved
    except OSError:
        return None
    return None


def _remember_wallpaper(path: Path) -> None:
    settings_path = paths.yahr_config() / "settings.json"
    if not settings_path.is_file():
        return
    try:
        data = json.loads(settings_path.read_text())
        if not isinstance(data, dict):
            return
    except (OSError, json.JSONDecodeError, TypeError):
        return
    data.setdefault("wallpaper", {})["current"] = str(path)
    settings_path.write_text(json.dumps(data, indent=2) + "\n")


def _apply_theme_wallpaper(palette: dict) -> None:
    folder = _theme_wallpaper_folder(palette)
    if folder is None:
        return
    images = _wallpaper_images(folder)
    if not images:
        return
    wallpaper = _settings().get("wallpaper") or {}
    last = ""
    try:
        last = paths.last_wallpaper().read_text().strip()
    except OSError:
        last = ""
    keep = _path_in_folder(str(wallpaper.get("current") or ""), folder) or _path_in_folder(last, folder)
    chosen = keep if keep is not None else random.choice(images)
    transition = str(wallpaper.get("transition") or "fade")
    script = paths.quickshell_script("set-wallpaper.py")
    if script.is_file():
        _run([sys.executable, str(script), str(chosen), transition])
    else:
        paths.last_wallpaper().parent.mkdir(parents=True, exist_ok=True)
        paths.last_wallpaper().write_text(str(chosen) + "\n")
    _remember_wallpaper(chosen)


def _sync_sddm() -> None:
    """Push the current palette, clock, and wallpaper into the SDDM greeter."""
    script = paths.quickshell_script("sddm-apply.py")
    if not script.is_file():
        return
    sddm = _settings().get("sddm") or {}
    blur = 0 if not sddm.get("blurEnabled", True) else int(sddm.get("blurAmount", 20) or 0)
    opacity = sddm.get("loginOpacity", 0.75)
    wallpaper = "desktop" if sddm.get("followDesktop", True) else (sddm.get("customWallpaper") or "none")
    _run([
        sys.executable,
        str(script),
        "--opacity",
        f"{float(opacity):.2f}",
        "--blur",
        str(blur),
        "--wallpaper",
        str(wallpaper),
    ])


def _install_lock_info() -> None:
    src = paths.lock_info_source()
    dest = paths.yahr_config() / "lock-info.py"
    if not src.is_file():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.resolve() != dest.resolve():
        shutil.copy2(src, dest)
        dest.chmod(0o755)
    _run([str(dest), "render"])


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


def _firefox_roots() -> list[Path]:
    home = paths.home()
    return [
        home / ".mozilla" / "firefox",
        home / ".mozilla" / "firefox-esr",
        home / ".mozilla" / "firefox-dev",
        home / ".config" / "mozilla" / "firefox",
        home / ".librewolf",
        home / ".zen",
        home / ".floorp",
        home / ".waterfox",
        home / ".var" / "app" / "org.mozilla.firefox" / ".mozilla" / "firefox",
        home / ".var" / "app" / "org.mozilla.firefox" / ".mozilla" / "firefox-esr",
        home / ".var" / "app" / "io.gitlab.librewolf-community" / ".librewolf",
        home / ".var" / "app" / "app.zen_browser.zen" / ".zen",
        home / "snap" / "firefox" / "common" / ".mozilla" / "firefox",
    ]


def _resolve_ini_profile(root: Path, raw: str) -> Path | None:
    value = raw.strip().strip('"').strip("'")
    if not value:
        return None
    dest = Path(value).expanduser()
    if not dest.is_absolute():
        dest = root / value
    try:
        dest = dest.resolve()
    except OSError:
        return None
    return dest if dest.is_dir() else None


def _profiles_from_ini(root: Path) -> list[Path]:
    found: list[Path] = []
    for name in ("profiles.ini", "installs.ini"):
        ini = root / name
        if not ini.is_file():
            continue
        try:
            lines = ini.read_text().splitlines()
        except OSError:
            continue
        for line in lines:
            key, _, value = line.partition("=")
            key = key.strip().lower()
            raw = value.strip()
            if key == "path":
                dest = _resolve_ini_profile(root, raw)
            elif key == "default" and name == "installs.ini":
                # installs.ini Default=<profile path>; profiles.ini Default=1 is a flag.
                dest = _resolve_ini_profile(root, raw)
            else:
                continue
            if dest is not None:
                found.append(dest)
    return found


def _profiles_from_scan(root: Path) -> list[Path]:
    """Fallback: any child directory that looks like a live Firefox profile."""
    found: list[Path] = []
    if not root.is_dir():
        return found
    try:
        children = list(root.iterdir())
    except OSError:
        return found
    for child in children:
        if not child.is_dir() or child.name.startswith("."):
            continue
        if (child / "prefs.js").is_file() or (child / "times.json").is_file():
            found.append(child.resolve())
    return found


def _firefox_profile_dirs() -> list[Path]:
    found: list[Path] = []
    seen: set[Path] = set()
    for root in _firefox_roots():
        if not root.is_dir():
            continue
        for dest in _profiles_from_ini(root) + _profiles_from_scan(root):
            if dest in seen:
                continue
            seen.add(dest)
            found.append(dest)
    return found


def _upsert_firefox_user_js(path: Path, *, light: bool) -> None:
    block = templates.firefox_user_js(light=light).strip() + "\n"
    text = path.read_text() if path.is_file() else ""
    start = "// >>> yahr-theme"
    end = "// <<< yahr-theme"
    if start in text and end in text:
        before = text.split(start, 1)[0]
        after = text.split(end, 1)[1]
        if after.startswith("\n"):
            after = after[1:]
        text = before.rstrip() + "\n\n" + block + after
    else:
        text = (text.rstrip() + "\n\n" + block) if text.strip() else block
    path.write_text(text)


def _install_firefox_theme(palette: dict) -> list[Path]:
    """Write userChrome.css + user.js into every discovered profile.

    Returns the profile directories that were updated. Empty means Firefox
    chrome could not be installed (caller should surface that).
    """
    light = palette_mode(palette) == "light"
    chrome = templates.firefox_user_chrome(palette)
    updated: list[Path] = []
    for profile in _firefox_profile_dirs():
        chrome_dir = profile / "chrome"
        chrome_dir.mkdir(parents=True, exist_ok=True)
        _write(chrome_dir / "userChrome.css", chrome)
        _upsert_firefox_user_js(profile / "user.js", light=light)
        updated.append(profile)
    return updated


def _install_cursor_theme(palette: dict) -> None:
    path = paths.cursor_settings_json()
    try:
        data = json.loads(path.read_text()) if path.is_file() else {}
    except (OSError, json.JSONDecodeError):
        return
    if not isinstance(data, dict):
        return
    light = palette_mode(palette) == "light"
    data["workbench.colorCustomizations"] = templates.cursor_color_customizations(palette)
    data["editor.tokenColorCustomizations"] = templates.cursor_token_customizations(palette)
    if light:
        data["workbench.preferredLightColorTheme"] = data.get("workbench.preferredLightColorTheme") or "Cursor Light"
    else:
        data["workbench.preferredDarkColorTheme"] = data.get("workbench.preferredDarkColorTheme") or "Cursor Dark"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=4) + "\n")


def _upsert_hash_block(path: Path, body: str) -> None:
    start = "# >>> yahr-theme"
    end = "# <<< yahr-theme"
    block = f"{start}\n{body.rstrip()}\n{end}\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    text = path.read_text() if path.is_file() else ""
    if start in text and end in text:
        before = text.split(start, 1)[0]
        after = text.split(end, 1)[1]
        if after.startswith("\n"):
            after = after[1:]
        text = before.rstrip() + "\n\n" + block + after
    else:
        text = (text.rstrip() + "\n\n" + block) if text.strip() else block
    path.write_text(text)


def _window_opacity() -> float:
    hypr = _settings().get("hypr") or {}
    if hypr.get("windowTransparent") is not True:
        return 1.0
    try:
        return max(0.5, min(1.0, float(hypr.get("windowOpacity") or 0.92)))
    except (TypeError, ValueError):
        return 0.92


def _ghostty_config_block(*, light: bool) -> str:
    return templates.ghostty_config_block(
        light=light,
        background_opacity=_window_opacity(),
        gtk_css_path=str(paths.ghostty_gtk_css()),
    )


def sync_ghostty_opacity() -> None:
    palette: dict = {}
    try:
        palette = json.loads(paths.current_json().read_text())
        if not isinstance(palette, dict):
            palette = {}
    except (OSError, json.JSONDecodeError, TypeError):
        palette = {}
    light = palette_mode(palette) == "light" if palette else False
    conf = paths.ghostty_config()
    if not conf.is_file():
        return
    # Keep the gtk.css file in sync even on opacity-only refreshes.
    _write(paths.ghostty_gtk_css(), templates.ghostty_gtk_css())
    _upsert_hash_block(conf, _ghostty_config_block(light=light))


def _install_ghostty_theme(palette: dict) -> None:
    theme_path = paths.ghostty_theme()
    theme_path.parent.mkdir(parents=True, exist_ok=True)
    _write(theme_path, templates.ghostty_theme(palette))
    _write(paths.ghostty_gtk_css(), templates.ghostty_gtk_css())
    conf = paths.ghostty_config()
    if not conf.is_file() or not conf.read_text().strip():
        _write(conf, templates.ghostty_config_base())
    light = palette_mode(palette) == "light"
    _upsert_hash_block(conf, _ghostty_config_block(light=light))


def _theme_installed(name: str) -> bool:
    home = paths.home()
    for root in (home / ".themes", home / ".local/share/themes", Path("/usr/share/themes")):
        if (root / name).is_dir():
            return True
    return False


def resolve_gtk_theme(palette: dict) -> str:
    tid = str(palette.get("id") or "").strip().lower()
    mapped = GTK_THEME_MAP.get(tid)
    if mapped is None:
        for key in sorted(GTK_THEME_MAP, key=len, reverse=True):
            if tid == key or tid.startswith(key + "-"):
                mapped = GTK_THEME_MAP[key]
                break
    light = palette_mode(palette) == "light"
    if mapped and _theme_installed(mapped) and not light:
        return mapped
    if light:
        if _theme_installed("adw-gtk3"):
            return "adw-gtk3"
        return "Adwaita"
    if _theme_installed("adw-gtk3-dark"):
        return "adw-gtk3-dark"
    if _theme_installed("Catppuccin-Dark"):
        return "Catppuccin-Dark"
    if _theme_installed("Dracula"):
        return "Dracula"
    return "Adwaita-dark"


def _ensure_pointer_themes() -> None:
    dest_dir = paths.home() / ".local/share/icons"
    dest_dir.mkdir(parents=True, exist_ok=True)
    for name in (templates.POINTER_THEME_DARK, templates.POINTER_THEME_LIGHT):
        src = Path("/usr/share/icons") / name
        dest = dest_dir / name
        if src.is_dir() and not dest.exists():
            dest.symlink_to(src)


def _update_xsettingsd(gtk_theme: str, icon_theme: str, *, cursor_theme: str) -> None:
    conf = paths.home() / ".config/xsettingsd/xsettingsd.conf"
    if not conf.is_file():
        return
    text = conf.read_text()

    def set_quoted(src: str, key: str, value: str) -> str:
        line = f'{key} "{value}"'
        pattern = rf"(?m)^{re.escape(key)}\s+.*$"
        if re.search(pattern, src):
            return re.sub(pattern, line, src, count=1)
        return src.rstrip() + "\n" + line + "\n"

    def set_plain(src: str, key: str, value: str) -> str:
        line = f"{key} {value}"
        pattern = rf"(?m)^{re.escape(key)}\s+.*$"
        if re.search(pattern, src):
            return re.sub(pattern, line, src, count=1)
        return src.rstrip() + "\n" + line + "\n"

    text = set_quoted(text, "Net/ThemeName", gtk_theme)
    text = set_quoted(text, "Net/IconThemeName", icon_theme)
    text = set_quoted(text, "Gtk/CursorThemeName", cursor_theme)
    text = set_plain(text, "Gtk/CursorThemeSize", str(templates.POINTER_SIZE))
    conf.write_text(text)
    _run(["killall", "-HUP", "xsettingsd"])


def apply_palette(palette: dict, *, reload: bool = True) -> None:
    paths.yahr_config().mkdir(parents=True, exist_ok=True)
    light = palette_mode(palette) == "light"
    gtk_theme = resolve_gtk_theme(palette)
    icon_theme = "Papirus" if light else "Papirus-Dark"
    color_scheme = "prefer-light" if light else "prefer-dark"

    _write(paths.current_json(), json.dumps(palette, indent=2) + "\n")
    _apply_theme_wallpaper(palette)
    _sync_sddm()
    _write(paths.hypr_theme_lua(), templates.hypr_theme_lua(palette))
    _install_ghostty_theme(palette)
    _write(paths.starship_toml(), templates.starship_toml(palette))
    _write(paths.mako_config(), templates.mako_config(palette, **templates.mako_style(palette, _settings())))
    _install_lock_info()
    _write(paths.hyprlock_conf(), templates.hyprlock_conf(palette))
    css = templates.gtk_css(palette)
    _write(paths.gtk3_css(), css)
    _write(paths.gtk4_css(), css)
    ini = templates.gtk_settings_ini(gtk_theme, icon_theme, light=light)
    _write(paths.gtk3_settings(), ini)
    _write(paths.home() / ".config/gtk-4.0/settings.ini", ini)
    _write(paths.home() / ".gtkrc-2.0", templates.gtkrc2(gtk_theme, icon_theme, light=light))
    _write(paths.home() / ".config/gtk-3.0/gtk-theme-env.sh", templates.gtk_theme_env(gtk_theme, icon_theme, light=light))
    _write(paths.qt6ct_colors(), templates.qt6ct_colors(palette))
    pointer = templates.pointer_theme(light=light)
    _ensure_pointer_themes()
    _update_xsettingsd(gtk_theme, icon_theme, cursor_theme=pointer)

    _gsettings("org.gnome.desktop.interface", "gtk-theme", gtk_theme)
    _gsettings("org.gnome.desktop.interface", "icon-theme", icon_theme)
    _gsettings("org.gnome.desktop.interface", "color-scheme", color_scheme)
    folder_color = papirus_folder_for(palette)
    gnome_accent = PAPIRUS_TO_GNOME.get(folder_color) or nearest_gnome_accent("#" + PAPIRUS_FOLDERS.get(folder_color, "5294e2"))
    _gsettings("org.gnome.desktop.interface", "accent-color", gnome_accent)
    _gsettings("org.gnome.desktop.interface", "cursor-theme", pointer)
    _gsettings("org.gnome.desktop.interface", "cursor-size", str(templates.POINTER_SIZE))
    _run(["hyprctl", "eval", f'hl.env("GTK_THEME", "{gtk_theme}")'])
    _run(["hyprctl", "eval", f'hl.env("XCURSOR_THEME", "{pointer}")'])
    _run(["hyprctl", "eval", f'hl.env("HYPRCURSOR_THEME", "{pointer}")'])
    _run(["hyprctl", "setcursor", pointer, str(templates.POINTER_SIZE)])

    papirus = shutil.which("papirus-folders")
    if papirus:
        result = _run(["papirus-folders", "-C", folder_color, "--theme", icon_theme])
        if result and result.returncode != 0:
            _run(["sudo", "-n", papirus, "-C", folder_color, "--theme", icon_theme])

    firefox_profiles = _install_firefox_theme(palette)
    _install_cursor_theme(palette)

    if not firefox_profiles:
        roots = ", ".join(str(r) for r in _firefox_roots() if r.is_dir()) or "(none present)"
        print(
            "firefox: no profiles found — userChrome.css was not written. "
            f"Checked: {roots}",
            file=sys.stderr,
        )
    else:
        for profile in firefox_profiles:
            print(f"firefox: wrote {profile / 'chrome' / 'userChrome.css'}")

    if not reload:
        return

    _run(["hyprctl", "reload"])
    _run(["makoctl", "reload"])
    # Thunar daemon picks up GTK CSS / theme after a restart
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

#!/usr/bin/env python3
"""Sync the YAHR SDDM greeter with the current palette, clock, and wallpaper.

Writes colors from ~/.config/yahr/current.json, clock/date formats from
settings.json, then copies a sharp wallpaper into
/usr/share/sddm/themes/yahr-theme. Full-screen blur is applied at runtime by
the greeter (FastBlur); the left-panel hero always uses the sharp image.
Needs the yahr-sddm sudoers rule.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

THEME_DIR = Path("/usr/share/sddm/themes/yahr-theme")
CONF = THEME_DIR / "theme.conf"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}
HOME = Path(os.environ.get("HOME", str(Path.home())))


def load_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError, TypeError):
        return {}


def resolve_wallpaper(arg: str) -> Path | None:
    if arg in ("", "none"):
        return None
    if arg == "desktop":
        last = HOME / ".config/yahr/last-wallpaper"
        if last.is_file():
            path = Path(os.path.expanduser(last.read_text().strip()))
            if path.is_file():
                return path
        settings = load_json(HOME / ".config/yahr/settings.json")
        current = (settings.get("wallpaper") or {}).get("current") or ""
        path = Path(os.path.expanduser(current))
        return path if path.is_file() else None
    path = Path(os.path.expanduser(arg))
    return path if path.is_file() else None


def clock_formats(settings: dict) -> tuple[str, str]:
    g = settings.get("general") or {}
    if g.get("clockFormat24hr"):
        time_fmt = "HH:mm:ss" if g.get("showSeconds") else "HH:mm"
    else:
        time_fmt = "h:mm:ss AP" if g.get("showSeconds") else "h:mm AP"
    dmy = g.get("dateFormat") == "DMY"
    if g.get("dateLong"):
        date_fmt = "d MMMM yyyy" if dmy else "MMMM d, yyyy"
    else:
        date_fmt = "dd/MM/yyyy" if dmy else "MM/dd/yyyy"
    date_fmt = f"ddd  {date_fmt}"
    return time_fmt, date_fmt


def ui_font(settings: dict) -> str:
    return str((settings.get("general") or {}).get("uiFont") or "Inter")


def set_key(text: str, key: str, value: str, quoted: bool = False) -> str:
    line = f'{key}="{value}"' if quoted else f"{key}={value}"
    pattern = rf"(?m)^{re.escape(key)}=.*$"
    if re.search(pattern, text):
        return re.sub(pattern, line, text, count=1)
    return text.rstrip() + "\n" + line + "\n"


def sudo_cp(src: Path, dest: Path) -> bool:
    result = subprocess.run(
        ["sudo", "-n", "cp", str(src), str(dest)],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def sudo_write(dest: Path, text: str) -> bool:
    result = subprocess.run(
        ["sudo", "-n", "tee", str(dest)],
        input=text,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def resize_wallpaper(src: Path, dest: Path) -> bool:
    """Write a resized, sharp copy of src to dest via sudo cp."""
    magick = shutil.which("magick") or shutil.which("convert")
    suffix = dest.suffix if dest.suffix.lower() in IMAGE_EXTS else ".png"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        if magick:
            cmd = [
                magick, str(src),
                "-resize", "2560x1440^",
                "-gravity", "center",
                "-extent", "2560x1440",
                str(tmp_path),
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                shutil.copy2(src, tmp_path)
            return sudo_cp(tmp_path, dest)
        shutil.copy2(src, tmp_path)
        return sudo_cp(tmp_path, dest)
    finally:
        tmp_path.unlink(missing_ok=True)


def find_theme_main() -> Path | None:
    """Locate Main.qml from the git clone or installed share tree."""
    candidates: list[Path] = []
    repo_root_file = HOME / ".config/yahr/repo-root"
    if repo_root_file.is_file():
        try:
            root = Path(repo_root_file.read_text().strip()).expanduser()
            if root.is_dir():
                candidates.append(root / "sddm" / "yahr-theme" / "Main.qml")
        except OSError:
            pass
    here = Path(__file__).resolve()
    # repo/quickshell/scripts → repo/sddm/...
    candidates.append(here.parents[2] / "sddm" / "yahr-theme" / "Main.qml")
    candidates.append(HOME / ".local/share/yahr-shell/sddm/yahr-theme/Main.qml")
    for path in candidates:
        if path.is_file():
            return path
    return None


def apply_palette(text: str, settings: dict) -> str:
    palette = load_json(HOME / ".config/yahr/current.json")
    mapping = {
        "ThemeColor": palette.get("accentBlue", "#6db3ce"),
        "AccentColor": palette.get("accentPurple", "#a78cfa"),
        "BgBase": palette.get("bgBase", "#181625"),
        "BgSurface": palette.get("surface0", "#2b2837"),
        "FgPrimary": palette.get("fgPrimary", "#cdcbe0"),
        "FgSecondary": palette.get("fgSecondary", "#aeafca"),
        "FailColor": palette.get("accentRed", "#eb746b"),
    }
    for key, value in mapping.items():
        text = set_key(text, key, str(value), quoted=True)
    font = ui_font(settings)
    text = set_key(text, "Font", font, quoted=True)
    text = set_key(text, "TitleFont", f"{font} ExtraBold", quoted=True)
    time_fmt, date_fmt = clock_formats(settings)
    text = set_key(text, "TimeFormat", time_fmt, quoted=True)
    text = set_key(text, "DateFormat", date_fmt, quoted=True)
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply YAHR SDDM wallpaper, blur, and palette")
    parser.add_argument("--opacity", required=True)
    parser.add_argument("--blur", required=True, type=int)
    parser.add_argument("--wallpaper", default="desktop")
    args = parser.parse_args()

    if not re.fullmatch(r"[0-9]+(\.[0-9]+)?", args.opacity):
        print("BAD_VALUE")
        return 1
    if args.blur < 0 or args.blur > 64:
        print("BAD_VALUE")
        return 1
    if not CONF.is_file():
        print("MISSING_THEME")
        return 1

    settings = load_json(HOME / ".config/yahr/settings.json")
    wallpaper = resolve_wallpaper(args.wallpaper)
    dest_name = None
    hero_name = None
    # Blur is applied at runtime on the full-screen layer only; assets stay sharp.
    runtime_blur = args.blur
    if wallpaper is not None:
        ext = wallpaper.suffix.lower()
        if ext not in IMAGE_EXTS:
            ext = ".png"
        dest_name = f"login-background{ext}"
        hero_name = f"login-hero{ext}"
        dest = THEME_DIR / dest_name
        hero_dest = THEME_DIR / hero_name
        if not resize_wallpaper(wallpaper, dest):
            print("FAIL")
            return 1
        if not resize_wallpaper(wallpaper, hero_dest):
            print("FAIL")
            return 1

    face = HOME / ".face.icon"
    if face.is_file():
        sudo_cp(face, Path("/usr/share/sddm/faces") / f"{HOME.name}.face.icon")

    theme_main = find_theme_main()
    if theme_main is not None:
        sudo_cp(theme_main, THEME_DIR / "Main.qml")

    text = CONF.read_text()
    text = set_key(text, "WidgetOpacity", args.opacity)
    text = set_key(text, "BackgroundBlur", str(runtime_blur))
    text = set_key(text, "ShowHostname", "false")
    if dest_name:
        text = set_key(text, "Background", dest_name, quoted=True)
    if hero_name:
        text = set_key(text, "HeroBackground", hero_name, quoted=True)
    text = apply_palette(text, settings)

    if not sudo_write(CONF, text):
        print("FAIL")
        return 1

    print("OK" if dest_name else "OK_NO_WALLPAPER")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

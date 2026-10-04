#!/usr/bin/env python3
"""Sync the YAHR SDDM greeter with the current palette, clock, and wallpaper.

Writes colors from ~/.config/yahr/current.json, clock/date formats from
settings.json, then copies a sharp login-background.png into
/usr/share/sddm/themes/yahr-theme. Full-screen blur is fixed at FastBlur
radius 40; field opacity is fixed. The login-window crop uses the same sharp
file.

Needs the yahr-sddm sudoers rule.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

THEME_DIR = Path("/usr/share/sddm/themes/yahr-theme")
CONF = THEME_DIR / "theme.conf"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
JPEG_MAGIC = b"\xff\xd8\xff"
# Fixed full-screen FastBlur radius (old Settings slider max was 40).
GREETER_BACKGROUND_BLUR = 40
# Fixed login-plate field opacity; no longer exposed in Settings.
GREETER_WIDGET_OPACITY = "0.75"
# Default name; may become .jpg if PNG conversion is unavailable.
BACKGROUND_STEM = "login-background"
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
    # Tempfiles are often mode 600; force world-readable so the sddm greeter
    # (and greeter --test-mode) can open theme assets under /usr/share.
    try:
        os.chmod(src, 0o644)
    except OSError:
        pass
    result = subprocess.run(
        ["sudo", "-n", "cp", "--no-preserve=mode", str(src), str(dest)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        # Older cp without --no-preserve=mode
        result = subprocess.run(
            ["sudo", "-n", "cp", str(src), str(dest)],
            capture_output=True,
            text=True,
        )
    if result.returncode != 0:
        return False
    # Ensure destination is readable even if cp preserved a restrictive mode.
    subprocess.run(
        ["sudo", "-n", "chmod", "644", str(dest)],
        capture_output=True,
        text=True,
    )
    return True


def sudo_rm(path: Path) -> None:
    if not path.exists():
        return
    subprocess.run(
        ["sudo", "-n", "rm", "-f", str(path)],
        capture_output=True,
        text=True,
    )


def sudo_write(dest: Path, text: str) -> bool:
    result = subprocess.run(
        ["sudo", "-n", "tee", str(dest)],
        input=text,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def publish_live_scripts() -> None:
    """Refresh live Quickshell files when ~/.config/quickshell is a separate copy.

    Scripts alone are not enough: SettingsPanel.qml is what draws the SDDM tab.
    Prefer the dedicated sync helper (symlink to the git checkout) when available.
    """
    here = Path(__file__).resolve().parent
    repo_qs = here.parent
    sync_helper = here / "sync-quickshell-from-repo.py"
    if sync_helper.is_file():
        subprocess.run(
            [sys.executable, str(sync_helper)],
            capture_output=True,
            text=True,
            check=False,
        )

    live_root = HOME / ".config/quickshell"
    live_scripts = live_root / "scripts"
    if not live_root.is_dir():
        return
    try:
        if live_root.resolve() == repo_qs.resolve():
            return
    except OSError:
        return

    for rel in (
        "scripts/sddm-apply.py",
        "scripts/set-wallpaper.py",
        "scripts/sddm-apply-cli",
        "scripts/set-wallpaper-cli",
        "scripts/sync-quickshell-from-repo.py",
        "scripts/sync-quickshell-cli",
        "modules/settings/SettingsPanel.qml",
        "Settings.qml",
    ):
        src = repo_qs / rel
        dest = live_root / rel
        if not src.is_file():
            continue
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)
            if rel.startswith("scripts/"):
                os.chmod(dest, 0o755)
        except OSError:
            pass


def _file_magic(path: Path, n: int = 8) -> bytes:
    try:
        with path.open("rb") as fh:
            return fh.read(n)
    except OSError:
        return b""


def is_png(path: Path) -> bool:
    return _file_magic(path).startswith(PNG_MAGIC)


def is_jpeg(path: Path) -> bool:
    return _file_magic(path).startswith(JPEG_MAGIC)


def encode_resized_png(src: Path, dest: Path) -> bool:
    """Resize src to 2560x1440 and write a real PNG to dest. dest must not exist."""
    magick = shutil.which("magick") or shutil.which("convert")
    if not magick:
        return False
    cmd = [
        magick, str(src),
        "-resize", "2560x1440^",
        "-gravity", "center",
        "-extent", "2560x1440",
        str(dest),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0 and dest.is_file() and dest.stat().st_size > 32 and is_png(dest)


def write_theme_wallpaper(src: Path) -> Path | None:
    """Install a greeter-readable wallpaper and return the destination path.

    Prefer a real PNG named login-background.png. If conversion fails, copy the
    original bytes with a matching extension so Qt can decode the file.
    Never write JPEG/WebP bytes to a .png path — Qt keys the decoder off the
    suffix and the greeter then shows a blank plate and desktop.
    """
    png_dest = THEME_DIR / f"{BACKGROUND_STEM}.png"
    fd, tmp_name = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    tmp_path = Path(tmp_name)
    tmp_path.unlink(missing_ok=True)
    try:
        if encode_resized_png(src, tmp_path):
            os.chmod(tmp_path, 0o644)
            if sudo_cp(tmp_path, png_dest):
                return png_dest

        ext = src.suffix.lower()
        if ext not in IMAGE_EXTS:
            ext = ".png" if is_png(src) else ".jpg" if is_jpeg(src) else ".png"
        if ext == ".jpeg":
            ext = ".jpg"
        dest = THEME_DIR / f"{BACKGROUND_STEM}{ext}"
        if dest.suffix.lower() == ".png" and not is_png(src):
            return None
        fd, raw_name = tempfile.mkstemp(suffix=ext)
        os.close(fd)
        raw = Path(raw_name)
        try:
            shutil.copy2(src, raw)
            os.chmod(raw, 0o644)
            if sudo_cp(raw, dest):
                return dest
            return None
        finally:
            raw.unlink(missing_ok=True)
    finally:
        tmp_path.unlink(missing_ok=True)


def clear_stale_wallpaper_assets(keep: set[str]) -> None:
    """Remove older login-background.* variants and obsolete login-hero.* files."""
    for path in THEME_DIR.glob("login-background.*"):
        if path.name not in keep:
            sudo_rm(path)
    # Hero now reads Background directly; drop leftover hero assets.
    for path in THEME_DIR.glob("login-hero.*"):
        sudo_rm(path)


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
    parser = argparse.ArgumentParser(description="Apply YAHR SDDM wallpaper and palette")
    parser.add_argument(
        "--opacity",
        default=GREETER_WIDGET_OPACITY,
        help="Ignored; greeter field opacity is fixed at %(default)s.",
    )
    parser.add_argument(
        "--blur",
        type=int,
        default=GREETER_BACKGROUND_BLUR,
        help="Ignored; greeter blur is fixed at radius %(default)s.",
    )
    parser.add_argument("--wallpaper", default="desktop")
    args = parser.parse_args()

    if args.opacity is not None and not re.fullmatch(r"[0-9]+(\.[0-9]+)?", str(args.opacity)):
        print("BAD_VALUE")
        return 1
    if not CONF.is_file():
        print("MISSING_THEME")
        return 1

    publish_live_scripts()
    settings = load_json(HOME / ".config/yahr/settings.json")
    wallpaper = resolve_wallpaper(args.wallpaper)
    dest_name = None
    runtime_blur = GREETER_BACKGROUND_BLUR
    runtime_opacity = GREETER_WIDGET_OPACITY
    if wallpaper is not None:
        dest = write_theme_wallpaper(wallpaper)
        if dest is None:
            print("FAIL")
            print(f"wallpaper={wallpaper}")
            return 1
        dest_name = dest.name
        clear_stale_wallpaper_assets({dest_name})

    face = HOME / ".face.icon"
    if face.is_file():
        sudo_cp(face, Path("/usr/share/sddm/faces") / f"{HOME.name}.face.icon")

    theme_main = find_theme_main()
    main_copied = False
    if theme_main is not None:
        main_copied = sudo_cp(theme_main, THEME_DIR / "Main.qml")

    text = CONF.read_text()
    text = set_key(text, "WidgetOpacity", runtime_opacity)
    text = set_key(text, "BackgroundBlur", str(runtime_blur))
    text = set_key(text, "ShowHostname", "false")
    if dest_name:
        text = set_key(text, "Background", dest_name, quoted=True)
        # Keep key for older greeter builds; both sides use Background in Main.qml.
        text = set_key(text, "HeroBackground", dest_name, quoted=True)
    text = apply_palette(text, settings)

    if not sudo_write(CONF, text):
        print("FAIL")
        return 1

    # Verbose status so a stale/copied script is obvious in the terminal.
    def _mode(path: Path) -> str:
        try:
            return oct(path.stat().st_mode & 0o777)
        except OSError:
            return "missing"

    if dest_name:
        print("OK")
        print(f"wallpaper={wallpaper}")
        print(f"background={THEME_DIR / dest_name} mode={_mode(THEME_DIR / dest_name)}")
        try:
            size = (THEME_DIR / dest_name).stat().st_size
        except OSError:
            size = 0
        magic = _file_magic(THEME_DIR / dest_name).hex()
        print(f"bytes={size} magic={magic}")
        print("hero=shared-with-background")
        print(f"runtime_blur={runtime_blur}")
        print(f"widget_opacity={runtime_opacity}")
        print(f"main_qml={'copied ' + str(theme_main) if main_copied else 'unchanged'}")
    else:
        print("OK_NO_WALLPAPER")
        print(f"runtime_blur={runtime_blur}")
        print(f"widget_opacity={runtime_opacity}")
        print(f"main_qml={'copied ' + str(theme_main) if main_copied else 'unchanged'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

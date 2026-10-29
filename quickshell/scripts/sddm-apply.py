#!/usr/bin/env python3
"""Sync the YAHR SDDM greeter with the current palette, clock, font, and wallpaper.

Writes colors from ~/.config/yahr/current.json, UI font / clock formats / framed
bar geometry from settings.json, then copies a sharp login-background.png and
refreshes Main.qml + Components/ into /usr/share/sddm/themes/yahr-theme.
Full-screen blur is fixed at FastBlur radius 40; field opacity is fixed.

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


# Same catalog keys as ThemeManager.uiFontCatalog / Settings UI Font chips.
UI_FONT_CATALOG: dict[str, list[str]] = {
    "Inter": ["Inter", "Inter Variable"],
    "Source Sans": ["Source Sans 3", "Source Sans Variable", "Source Sans 3 VF", "Source Sans Pro"],
    "Roboto": ["Roboto Flex", "Roboto"],
    "Manrope": ["Manrope"],
    "Overpass": ["Overpass", "Overpass Nerd Font"],
    "Space Grotesk": ["Space Grotesk", "SpaceGrotesk"],
    "IBM Plex Sans": ["IBM Plex Sans Var", "IBM Plex Sans"],
}


def _normalize_font_key(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", (name or "").lower())


def ui_font_key(settings: dict) -> str:
    """Return the Settings catalog key (or raw family) for the UI font."""
    raw = str((settings.get("general") or {}).get("uiFont") or "Inter").strip()
    if not raw:
        return "Inter"
    if raw in UI_FONT_CATALOG:
        return raw
    norm = _normalize_font_key(raw)
    for key, families in UI_FONT_CATALOG.items():
        if _normalize_font_key(key) == norm:
            return key
        for fam in families:
            if _normalize_font_key(fam) == norm:
                return key
    # Common typo: Grostek → Grotesk
    if "grostek" in norm and "space" in norm:
        return "Space Grotesk"
    return raw


def fontconfig_families() -> set[str]:
    fc_list = shutil.which("fc-list")
    if not fc_list:
        return set()
    try:
        result = subprocess.run(
            [fc_list, ":", "family"],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return set()
    if result.returncode != 0:
        return set()
    names: set[str] = set()
    for line in result.stdout.splitlines():
        for part in line.split(","):
            name = part.strip()
            if name:
                names.add(name)
    return names


def resolve_ui_font(settings: dict) -> str:
    """Resolve Settings UI font to an installed family name for the greeter."""
    key = ui_font_key(settings)
    families = list(UI_FONT_CATALOG.get(key, [key]))
    if key not in families:
        families.insert(0, key)
    installed = fontconfig_families()
    if not installed:
        return families[0]
    lower = {name.lower(): name for name in installed}
    for fam in families:
        if fam in installed:
            return fam
        hit = lower.get(fam.lower())
        if hit:
            return hit
        # Prefix match (e.g. "Inter" → "Inter Variable" already listed; also "Space Grotesk Medium")
        norm = _normalize_font_key(fam)
        for name in installed:
            if _normalize_font_key(name) == norm or _normalize_font_key(name).startswith(norm):
                return name
    return families[0]


def ui_font(settings: dict) -> str:
    """Back-compat alias: resolved family written to theme.conf Font=."""
    return resolve_ui_font(settings)


def frame_settings(settings: dict) -> dict[str, str]:
    """Mirror quickshell framed mode (solid + docked bar) into theme.conf."""
    bar = settings.get("bar") or {}
    hypr = settings.get("hypr") or {}
    style = str(bar.get("barStyle") or "single")
    floating = bool(bar.get("floating", False))
    if style == "islands":
        floating = True
    use_frame = style == "single" and not floating
    try:
        gaps = int(hypr.get("gapsOut") or 10)
    except (TypeError, ValueError):
        gaps = 10
    try:
        rounding = int(hypr.get("rounding") or 12)
    except (TypeError, ValueError):
        rounding = 12
    try:
        opacity = float(bar.get("barOpacity") if bar.get("barOpacity") is not None else 0.7)
    except (TypeError, ValueError):
        opacity = 0.7
    bg_style = str(bar.get("backgroundStyle") or "translucent")
    follow = bool(bar.get("followHyprland", False))
    if follow or bg_style == "opaque":
        frame_opacity = 1.0
    else:
        frame_opacity = max(0.92, opacity)
    return {
        "UseFrame": "true" if use_frame else "false",
        "FrameThickness": str(max(10, gaps)),
        "FrameInnerRadius": str(max(0, rounding)),
        "FrameOpacity": f"{frame_opacity:.2f}",
    }


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


MAIN_VERSION_MARK = "YAHR_SDDM_MAIN_V=5"


def _theme_main_version(path: Path) -> int:
    try:
        text = path.read_text(errors="ignore")
    except OSError:
        return 0
    match = re.search(r"YAHR_SDDM_MAIN_V=(\d+)", text)
    return int(match.group(1)) if match else 0


def find_theme_dir() -> Path | None:
    """Locate the newest yahr-theme source (prefer git clone over stale share)."""
    candidates: list[Path] = []
    repo_root_file = HOME / ".config/yahr/repo-root"
    if repo_root_file.is_file():
        try:
            root = Path(repo_root_file.read_text().strip()).expanduser()
            if root.is_dir():
                candidates.append(root / "sddm" / "yahr-theme")
        except OSError:
            pass
    here = Path(__file__).resolve()
    # <repo>/quickshell/scripts/sddm-apply.py → <repo>/sddm/yahr-theme
    if here.parent.name == "scripts" and here.parent.parent.name == "quickshell":
        candidates.append(here.parents[2] / "sddm" / "yahr-theme")
    candidates.append(HOME / ".local/share/yahr-shell/sddm/yahr-theme")

    best: Path | None = None
    best_ver = -1
    for path in candidates:
        main = path / "Main.qml"
        if not main.is_file():
            continue
        ver = _theme_main_version(main)
        # Prefer higher version stamps; tie-break by first candidate (repo-root).
        if ver > best_ver or (ver == best_ver and best is None):
            best = path
            best_ver = ver
    return best


def _file_digest(path: Path) -> str:
    try:
        import hashlib

        return hashlib.sha256(path.read_bytes()).hexdigest()[:16]
    except OSError:
        return ""


def copy_theme_qml() -> list[str]:
    """Refresh greeter Main.qml from the best source tree.

    Frame/joins live inside Main.qml (V5+) so a single top-level copy is enough
    for the sudoers rule that only allows paths under yahr-theme/*.
    Also refreshes ~/.local/share so later applies do not pick a stale copy.
    """
    theme_dir = find_theme_dir()
    if theme_dir is None:
        return []
    src = theme_dir / "Main.qml"
    if not src.is_file():
        return []

    copied: list[str] = []
    dest = THEME_DIR / "Main.qml"
    src_digest = _file_digest(src)
    if sudo_cp(src, dest):
        dest_digest = _file_digest(dest)
        if dest_digest and dest_digest == src_digest:
            copied.append(f"Main.qml@{src_digest}")
        else:
            copied.append(f"Main.qml@MISMATCH:{src_digest}->{dest_digest or 'missing'}")
    else:
        copied.append("Main.qml@COPY_FAILED")

    # Keep the installed share tree current for future fallback resolves.
    share = HOME / ".local/share/yahr-shell/sddm/yahr-theme"
    try:
        share.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, share / "Main.qml")
    except OSError:
        pass

    return copied


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
    font_key = ui_font_key(settings)
    font = resolve_ui_font(settings)
    # Font = installed family for Qt; FontKey = Settings catalog key.
    text = set_key(text, "Font", font, quoted=True)
    text = set_key(text, "FontKey", font_key, quoted=True)
    # Legacy key kept for older greeters; Main.qml uses Font + weight.
    text = set_key(text, "TitleFont", font, quoted=True)
    time_fmt, date_fmt = clock_formats(settings)
    text = set_key(text, "TimeFormat", time_fmt, quoted=True)
    text = set_key(text, "DateFormat", date_fmt, quoted=True)
    for key, value in frame_settings(settings).items():
        # Match BackgroundBlur-style unquoted values.
        text = set_key(text, key, value, quoted=False)
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

    theme_dir = find_theme_dir()
    qml_copied = copy_theme_qml()
    frame = frame_settings(settings)
    font = ui_font(settings)

    text = CONF.read_text()
    text = set_key(text, "WidgetOpacity", runtime_opacity)
    text = set_key(text, "BackgroundBlur", str(runtime_blur))
    text = set_key(text, "ShowHostname", "false")
    # Drop legacy thick-top keys so stale conf cannot revive bar-height bezels.
    text = set_key(text, "BarHeight", "0")
    text = set_key(text, "BarPosition", "top", quoted=True)
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

    live_main = THEME_DIR / "Main.qml"
    live_ver = _theme_main_version(live_main)
    src_ver = _theme_main_version(theme_dir / "Main.qml") if theme_dir else 0
    qml_ok = any(item.startswith("Main.qml@") and "FAIL" not in item and "MISMATCH" not in item for item in qml_copied)
    qml_note = ",".join(qml_copied) if qml_copied else "unchanged"

    if dest_name:
        print("OK" if qml_ok and live_ver >= 5 else "OK_QML_STALE")
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
        print(f"ui_font={font}")
        print(f"use_frame={frame['UseFrame']}")
        print(f"frame_thickness={frame['FrameThickness']}")
        print(f"theme_src={theme_dir}")
        print(f"main_version_src={src_ver} live={live_ver}")
        print(f"qml={qml_note}")
    else:
        print("OK_NO_WALLPAPER" if qml_ok and live_ver >= 5 else "OK_QML_STALE")
        print(f"runtime_blur={runtime_blur}")
        print(f"widget_opacity={runtime_opacity}")
        print(f"ui_font={font}")
        print(f"use_frame={frame['UseFrame']}")
        print(f"frame_thickness={frame['FrameThickness']}")
        print(f"theme_src={theme_dir}")
        print(f"main_version_src={src_ver} live={live_ver}")
        print(f"qml={qml_note}")
    if not qml_ok or live_ver < 5:
        print("hint=Main.qml was not refreshed; re-run Apply after sudoers allow cp into the theme dir")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

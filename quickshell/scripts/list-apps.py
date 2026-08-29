#!/usr/bin/env python3
"""List .desktop applications as name|description|icon|command|terminal lines."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

BLACKLIST = {
    "xfce4-about.desktop",
    "avahi-discover.desktop",
    "bssh.desktop",
    "bvnc.desktop",
    "qv4l2.desktop",
    "qvidcap.desktop",
    "lstopo.desktop",
    "uuctl.desktop",
}

SEARCH_PATHS = [
    Path.home() / ".local/share/applications",
    Path.home() / ".local/share/flatpak/exports/share/applications",
    Path("/var/lib/flatpak/exports/share/applications"),
    Path("/usr/local/share/applications"),
    Path("/usr/share/applications"),
]


ICON_CACHE: dict[str, str] = {}
ICON_EXTS = (".svg", ".png", ".xpm")
ICON_SIZES = ("48x48", "32x32", "64x64", "128x128", "96x96", "scalable")
ICON_CATS = ("apps", "applications", "places", "devices", "categories", "mimetypes")
ICON_THEMES = ("Papirus-Dark", "Papirus", "hicolor", "Adwaita")
ICON_ROOTS = (
    Path.home() / ".local/share/icons",
    Path.home() / ".icons",
    Path("/usr/share/icons"),
    Path("/var/lib/flatpak/exports/share/icons"),
    Path.home() / ".local/share/flatpak/exports/share/icons",
)


def find_icon(icon: str) -> str:
    if not icon:
        return ""
    cached = ICON_CACHE.get(icon)
    if cached is not None:
        return cached
    path = Path(icon)
    if path.is_absolute() and path.is_file():
        ICON_CACHE[icon] = str(path)
        return str(path)
    name = path.name
    stem = path.stem if path.suffix.lower() in ICON_EXTS else name
    pixmaps = Path("/usr/share/pixmaps")
    for candidate in (
        pixmaps / name,
        pixmaps / f"{stem}.png",
        pixmaps / f"{stem}.svg",
        pixmaps / f"{stem}.xpm",
    ):
        if candidate.is_file():
            ICON_CACHE[icon] = str(candidate)
            return str(candidate)
    for root in ICON_ROOTS:
        if not root.is_dir():
            continue
        for theme in ICON_THEMES:
            tdir = root / theme
            if not tdir.is_dir():
                continue
            for size in ICON_SIZES:
                for cat in ICON_CATS:
                    folder = tdir / size / cat
                    if not folder.is_dir():
                        continue
                    direct = folder / name
                    if direct.is_file():
                        ICON_CACHE[icon] = str(direct)
                        return str(direct)
                    for ext in ICON_EXTS:
                        candidate = folder / f"{stem}{ext}"
                        if candidate.is_file():
                            ICON_CACHE[icon] = str(candidate)
                            return str(candidate)
    ICON_CACHE[icon] = icon
    return icon


def resolve_command(command: str) -> str | None:
    parts = command.split()
    if not parts:
        return None
    binary = parts[0]
    path = Path(os.path.expanduser(binary))
    if path.is_absolute():
        if path.is_file() and os.access(path, os.X_OK):
            return command
        return None
    found = shutil.which(binary)
    if not found:
        local = Path.home() / ".local" / "bin" / binary
        if local.is_file() and os.access(local, os.X_OK):
            found = str(local)
    if not found:
        return None
    parts[0] = found
    return " ".join(parts)


def command_available(command: str) -> bool:
    return resolve_command(command) is not None


def parse_desktop(path: Path) -> dict | None:
    name = description = icon = command = try_exec = ""
    terminal = False
    hidden = False
    nodisplay = False
    in_desktop = False
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return None
    for line in text.splitlines():
        if line.startswith("[") and line.strip() == "[Desktop Entry]":
            in_desktop = True
            continue
        if line.startswith("[") and in_desktop:
            break
        if not in_desktop or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if key == "Name" and not name:
            name = value
        elif key == "Comment" and not description:
            description = value
        elif key == "Icon" and not icon:
            icon = value
        elif key == "Exec" and not command:
            command = " ".join(tok for tok in value.split() if not tok.startswith("%"))
        elif key == "TryExec" and not try_exec:
            try_exec = value
        elif key == "Terminal":
            terminal = value.lower() == "true"
        elif key == "Hidden":
            hidden = value.lower() == "true"
        elif key == "NoDisplay":
            nodisplay = value.lower() == "true"
        elif key == "Type" and value != "Application":
            return None
    if hidden or nodisplay or not name or not command:
        return None
    if try_exec and resolve_command(try_exec) is None:
        return None
    resolved = resolve_command(command)
    if not resolved:
        return None
    return {
        "name": name.replace("|", " "),
        "description": (description or name).replace("|", " "),
        "icon": find_icon(icon),
        "command": resolved,
        "terminal": terminal,
        "desktopId": path.stem,
    }


def main() -> None:
    seen: set[str] = set()
    rows = []
    for directory in SEARCH_PATHS:
        if not directory.is_dir():
            continue
        for desktop in sorted(directory.glob("*.desktop")):
            if desktop.name in BLACKLIST or desktop.name in seen:
                continue
            seen.add(desktop.name)
            app = parse_desktop(desktop)
            if not app:
                continue
            rows.append(app)
    rows.sort(key=lambda a: a["name"].lower())
    for app in rows:
        print(
            f"{app['name']}|{app['description']}|{app['icon']}|{app['command']}|"
            f"{str(app['terminal']).lower()}|{app['desktopId']}"
        )


if __name__ == "__main__":
    main()

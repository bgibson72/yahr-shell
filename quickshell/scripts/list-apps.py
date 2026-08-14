#!/usr/bin/env python3
"""List .desktop applications as name|description|icon|command|terminal lines."""

from __future__ import annotations

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


def parse_desktop(path: Path) -> dict | None:
    name = description = icon = command = ""
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
    return {
        "name": name.replace("|", " "),
        "description": (description or name).replace("|", " "),
        "icon": icon,
        "command": command,
        "terminal": terminal,
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
            f"{app['name']}|{app['description']}|{app['icon']}|{app['command']}|{str(app['terminal']).lower()}"
        )


if __name__ == "__main__":
    main()

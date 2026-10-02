#!/usr/bin/env python3
"""List wallpaper images grouped by theme folder.

Prints a JSON object::

    {"sections": [{"id": "Catppuccin", "title": "Catppuccin", "paths": ["/..."]}]}

Each immediate subfolder of the wallpaper directory is one section. The
title comes from the theme whose wallpaperDir matches that folder (the
shortest matching name, so Catppuccin and Catppuccin Latte share one
section). Images sitting directly in the directory, not in a subfolder,
are listed last under "Other".

Pass the directory as argv[1]; ~ is expanded. Defaults to ~/Pictures/Wallpapers.
"""

from __future__ import annotations

import json
import os
import sys
import unicodedata
from pathlib import Path

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
OTHER = "Other"


def expand(path: str) -> Path:
    return Path(os.path.expanduser(path)).expanduser().resolve()


def is_image(path: Path, root: Path) -> bool:
    if path.suffix.lower() not in EXTS or not path.is_file():
        return False
    try:
        relative = path.relative_to(root)
    except ValueError:
        return False
    return not any(part.startswith(".") for part in relative.parts)


def fold(text: str) -> str:
    norm = unicodedata.normalize("NFKD", text)
    stripped = "".join(ch for ch in norm if not unicodedata.combining(ch))
    return "".join(ch for ch in stripped.lower() if ch.isalnum())


def theme_dirs() -> list[Path]:
    dirs: list[Path] = []
    env = os.environ.get("YAHR_THEMES")
    if env:
        dirs.append(Path(os.path.expanduser(env)))
    else:
        share = Path.home() / ".local/share/yahr-shell/themes"
        checkout = Path(__file__).resolve().parents[2] / "themes"
        if share.is_dir():
            dirs.append(share)
        elif checkout.is_dir():
            dirs.append(checkout)
    user = Path.home() / ".config/yahr/themes"
    if user.is_dir():
        dirs.append(user)
    return dirs


def load_themes() -> list[dict[str, str]]:
    files: dict[str, Path] = {}
    for directory in theme_dirs():
        if not directory.is_dir():
            continue
        for path in directory.glob("*.json"):
            if path.name == "schema.json":
                continue
            files[path.stem] = path
    themes: list[dict[str, str]] = []
    for stem in sorted(files):
        try:
            data = json.loads(files[stem].read_text())
        except (OSError, json.JSONDecodeError, TypeError):
            continue
        if not isinstance(data, dict):
            continue
        wallpaper_dir = str(data.get("wallpaperDir") or "").strip()
        name = str(data.get("name") or stem).strip() or stem
        if wallpaper_dir:
            themes.append({"name": name, "wallpaperDir": wallpaper_dir})
    return themes


def section_title(folder: str, themes: list[dict[str, str]]) -> str:
    matches = [theme["name"] for theme in themes if theme["wallpaperDir"] == folder]
    if not matches:
        folded = fold(folder)
        matches = [theme["name"] for theme in themes if fold(theme["wallpaperDir"]) == folded]
    if not matches:
        return folder
    target = fold(folder)
    exact = [name for name in matches if fold(name) == target]
    pool = exact or matches
    return min(pool, key=lambda name: (len(name), name.lower()))


def _sorted_paths(paths: list[Path]) -> list[str]:
    return [str(path) for path in sorted(paths, key=lambda item: item.as_posix().lower())]


def sections_for(root: Path, themes: list[dict[str, str]]) -> list[dict]:
    if not root.is_dir():
        return []

    grouped: dict[str, list[Path]] = {}
    loose: list[Path] = []
    for path in root.rglob("*"):
        if not is_image(path, root):
            continue
        relative = path.relative_to(root)
        if len(relative.parts) == 1:
            loose.append(path)
        else:
            grouped.setdefault(relative.parts[0], []).append(path)

    ordered: list[str] = []
    seen: set[str] = set()
    for theme in themes:
        folder = theme["wallpaperDir"]
        key = next((name for name in grouped if name == folder or fold(name) == fold(folder)), None)
        if key is None or key in seen:
            continue
        ordered.append(key)
        seen.add(key)
    ordered.extend(sorted((name for name in grouped if name not in seen), key=str.lower))

    sections: list[dict] = []
    for key in ordered:
        paths = _sorted_paths(grouped[key])
        if not paths:
            continue
        sections.append({"id": key, "title": section_title(key, themes), "paths": paths})

    if loose:
        loose_paths = _sorted_paths(loose)
        other = next(
            (section for section in sections if section["id"].lower() == OTHER.lower() or section["title"] == OTHER),
            None,
        )
        if other is None:
            sections.append({"id": OTHER, "title": OTHER, "paths": loose_paths})
        else:
            other["id"] = OTHER
            other["title"] = OTHER
            other["paths"] = _sorted_paths([Path(path) for path in other["paths"]] + loose)
            sections = [section for section in sections if section is not other] + [other]
    return sections


def main() -> int:
    raw = sys.argv[1] if len(sys.argv) > 1 else "~/Pictures/Wallpapers"
    payload = {"sections": sections_for(expand(raw), load_themes())}
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Print a theme's palette JSON by id, checking user themes before bundled ones.

Mirrors the lookup logic in theme-engine/yahr_theme/apply.py without
importing that package, so the shell can preview any theme's colors
before applying it.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def home() -> Path:
    return Path(os.environ.get("HOME", str(Path.home())))


def repo_root() -> Path:
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


def iter_theme_files() -> list[Path]:
    files: dict[str, Path] = {}
    bundled = bundled_themes()
    if bundled.is_dir():
        for p in bundled.glob("*.json"):
            if p.name == "schema.json":
                continue
            files[p.stem] = p
    user = user_themes()
    if user.is_dir():
        for p in user.glob("*.json"):
            files[p.stem] = p
    return sorted(files.values(), key=lambda p: p.stem)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: theme-colors.py <theme-id>", file=sys.stderr)
        return 1

    needle = sys.argv[1].strip().lower()
    for path in iter_theme_files():
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue
        if data.get("id", path.stem).lower() == needle or path.stem.lower() == needle:
            json.dump(data, sys.stdout)
            return 0

    print("{}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

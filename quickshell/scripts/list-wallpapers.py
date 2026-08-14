#!/usr/bin/env python3
"""List wallpaper paths. Arg is a theme folder name, or 'all'."""

from __future__ import annotations

import os
import sys
from pathlib import Path

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}


def main() -> None:
    home = Path.home()
    root = home / "Pictures/Wallpapers"
    if not root.is_dir():
        share = home / ".local/share/yahr-shell/wallpapers"
        root = share if share.is_dir() else Path(__file__).resolve().parents[2] / "wallpapers"
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    paths: list[Path] = []
    if which == "all":
        paths = [p for p in root.rglob("*") if p.suffix.lower() in EXTS]
    else:
        folder = root / which
        if folder.is_dir():
            paths = [p for p in folder.iterdir() if p.suffix.lower() in EXTS]
    for p in sorted(paths):
        print(p)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""List image files in a wallpaper directory as a flat gallery.

Prints one absolute path per line. Recurses into subfolders but does not
group by theme — every image is shown together. Pass the directory as
argv[1]; ~ is expanded. Defaults to ~/Pictures/Wallpapers.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}


def expand(path: str) -> Path:
    return Path(os.path.expanduser(path)).expanduser().resolve()


def is_image(path: Path) -> bool:
    if path.suffix.lower() not in EXTS or not path.is_file():
        return False
    return not any(part.startswith(".") for part in path.parts)


def main() -> int:
    raw = sys.argv[1] if len(sys.argv) > 1 else "~/Pictures/Wallpapers"
    root = expand(raw)
    if not root.is_dir():
        return 0

    paths = [p for p in root.rglob("*") if is_image(p)]
    for path in sorted(paths, key=lambda p: p.as_posix().lower()):
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

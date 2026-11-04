#!/usr/bin/env python3
"""Rewrite ~/.config/hypr/hyprlock.conf from the current palette and Settings UI font."""
from __future__ import annotations

import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "theme-engine"))

from yahr_theme import apply, paths, templates  # noqa: E402


def main() -> int:
    palette_path = paths.current_json()
    if not palette_path.is_file():
        print(f"missing palette: {palette_path}", file=sys.stderr)
        return 1
    try:
        palette = json.loads(palette_path.read_text())
        if not isinstance(palette, dict):
            raise TypeError("palette is not an object")
    except (OSError, json.JSONDecodeError, TypeError) as exc:
        print(f"failed to read palette: {exc}", file=sys.stderr)
        return 1

    settings_path = paths.yahr_config() / "settings.json"
    try:
        settings = json.loads(settings_path.read_text())
        if not isinstance(settings, dict):
            settings = {}
    except (OSError, json.JSONDecodeError, TypeError):
        settings = {}

    ui_font = apply.resolve_ui_font(settings)
    conf = paths.hyprlock_conf()
    conf.parent.mkdir(parents=True, exist_ok=True)
    conf.write_text(templates.hyprlock_conf(palette, ui_font=ui_font))
    print(f"wrote {conf} ui_font={ui_font}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Rewrite ~/.config/mako/config from the current palette and settings."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "theme-engine"))

from yahr_theme import paths, templates  # noqa: E402


def main() -> int:
    palette = json.loads(paths.current_json().read_text())
    settings_path = paths.yahr_config() / "settings.json"
    try:
        settings = json.loads(settings_path.read_text())
        if not isinstance(settings, dict):
            settings = {}
    except (OSError, json.JSONDecodeError, TypeError):
        settings = {}
    conf = paths.mako_config()
    conf.parent.mkdir(parents=True, exist_ok=True)
    conf.write_text(templates.mako_config(palette, **templates.mako_style(palette, settings)))
    subprocess.run(["makoctl", "reload"], check=False, capture_output=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

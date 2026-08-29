#!/usr/bin/env python3
"""Keep Ghostty's GL opacity at 1 and ask running windows to reload config."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "theme-engine"))

from yahr_theme.apply import sync_ghostty_opacity  # noqa: E402


def _reload_running_ghostty() -> None:
    try:
        clients = json.loads(subprocess.check_output(["hyprctl", "-j", "clients"], text=True))
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, TypeError):
        return
    for client in clients if isinstance(clients, list) else []:
        cls = str(client.get("class") or "").lower()
        addr = client.get("address")
        if "ghostty" not in cls or not addr:
            continue
        subprocess.run(
            [
                "hyprctl",
                "dispatch",
                "hl.dsp.send_shortcut("
                f'{{ mods = "CTRL+SHIFT", key = ",", window = "address:{addr}" }})',
            ],
            check=False,
            capture_output=True,
        )


def main() -> int:
    sync_ghostty_opacity()
    _reload_running_ghostty()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

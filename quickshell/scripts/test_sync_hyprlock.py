#!/usr/bin/env python3
"""Tests for sync-hyprlock.py."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).with_name("sync-hyprlock.py")


class SyncHyprlockTests(unittest.TestCase):
    def test_writes_settings_ui_font(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            yahr = home / ".config" / "yahr"
            hypr = home / ".config" / "hypr"
            yahr.mkdir(parents=True)
            hypr.mkdir(parents=True)
            (yahr / "current.json").write_text(
                json.dumps(
                    {
                        "name": "Test",
                        "bgBase": "#111111",
                        "surface0": "#222222",
                        "accentBlue": "#89b4fa",
                        "accentGreen": "#a6e3a1",
                        "accentRed": "#f38ba8",
                        "accentYellow": "#f9e2af",
                        "accentCyan": "#89dceb",
                        "fgPrimary": "#cdd6f4",
                        "fgSecondary": "#bac2de",
                        "fgTertiary": "#a6adc8",
                    }
                )
                + "\n"
            )
            (yahr / "settings.json").write_text(
                json.dumps({"general": {"uiFont": "Space Grotesk"}}) + "\n"
            )

            env = os.environ.copy()
            env["HOME"] = str(home)
            result = subprocess.run(
                ["python3", str(SCRIPT)],
                env=env,
                text=True,
                capture_output=True,
                check=False,
                cwd=str(ROOT),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            text = (hypr / "hyprlock.conf").read_text()
            self.assertIn("$ui = Space Grotesk", text)
            self.assertIn("$uiBold = Space Grotesk ExtraBold", text)
            self.assertNotIn("Inter ExtraBold", text)


if __name__ == "__main__":
    unittest.main()

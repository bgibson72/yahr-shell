#!/usr/bin/env python3
"""Tests for toggle-gamemode.sh state machine (no Hyprland required)."""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "quickshell" / "scripts" / "toggle-gamemode.sh"


class ToggleGamemodeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.yahr = self.home / ".config" / "yahr"
        self.yahr.mkdir(parents=True)
        (self.yahr / "settings.json").write_text(
            textwrap.dedent(
                """\
                {
                  "hypr": {
                    "animations": true,
                    "blurEnabled": false
                  }
                }
                """
            ),
            encoding="utf-8",
        )
        # Stub hyprctl / powerprofilesctl / notify-send / hypridle out of PATH.
        self.bindir = self.home / "bin"
        self.bindir.mkdir()
        for name in ("hyprctl", "powerprofilesctl", "notify-send", "hypridle"):
            path = self.bindir / name
            path.write_text("#!/bin/bash\nexit 0\n", encoding="utf-8")
            path.chmod(path.stat().st_mode | stat.S_IEXEC)

        self.env = os.environ.copy()
        self.env["HOME"] = str(self.home)
        self.env["PATH"] = f"{self.bindir}:{self.env.get('PATH', '')}"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_script(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_script_is_executable(self) -> None:
        self.assertTrue(SCRIPT.is_file())
        self.assertTrue(os.access(SCRIPT, os.X_OK))

    def test_default_status_off(self) -> None:
        result = self.run_script("status")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "off")

    def test_toggle_on_writes_state(self) -> None:
        result = self.run_script("on")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "on")
        state = (self.yahr / "gamemode").read_text(encoding="utf-8").strip()
        self.assertEqual(state, "on")
        snap = (self.yahr / "gamemode-snap").read_text(encoding="utf-8")
        self.assertIn("animations=true", snap)

    def test_toggle_off_restores(self) -> None:
        self.run_script("on")
        result = self.run_script("off")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "off")
        state = (self.yahr / "gamemode").read_text(encoding="utf-8").strip()
        self.assertEqual(state, "off")
        self.assertFalse((self.yahr / "gamemode-snap").exists())

    def test_toggle_roundtrip(self) -> None:
        self.assertEqual(self.run_script("toggle").stdout.strip(), "on")
        self.assertEqual(self.run_script("status").stdout.strip(), "on")
        self.assertEqual(self.run_script("toggle").stdout.strip(), "off")
        self.assertEqual(self.run_script("status").stdout.strip(), "off")

    def test_on_is_idempotent(self) -> None:
        self.run_script("on")
        result = self.run_script("on")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "on")


if __name__ == "__main__":
    unittest.main()

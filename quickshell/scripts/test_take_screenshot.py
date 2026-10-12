#!/usr/bin/env python3
"""Unit tests for take-screenshot.sh delay + save/clipboard branching."""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "take-screenshot.sh"


def write_stub(path: Path, body: str) -> None:
    path.write_text("#!/bin/bash\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


class TakeScreenshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmpdir.name)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.out = self.tmp / "shots"
        self.out.mkdir()
        self.log = self.tmp / "hyprshot.log"

        write_stub(self.bin / "hyprshot", f'echo "hyprshot $@" >> "{self.log}"\n')
        write_stub(self.bin / "slurp", 'echo "0,0 10x10"\n')
        # grim -g GEOM OUTFILE
        write_stub(self.bin / "grim", 'printf "png" > "$3"\n')
        write_stub(self.bin / "notify-send", "exit 0\n")

        self.env = os.environ.copy()
        self.env["PATH"] = f"{self.bin}:{self.env.get('PATH', '')}"

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

    def run_script(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            env=self.env,
            text=True,
            capture_output=True,
            check=True,
        )

    def test_save_and_copy_uses_hyprshot(self) -> None:
        self.run_script("output", "true", "true", str(self.out), "0")
        logged = self.log.read_text().strip()
        self.assertEqual(logged, f"hyprshot -m output -o {self.out}")

    def test_clipboard_only_uses_hyprshot_flag(self) -> None:
        self.run_script("region", "false", "true", str(self.out), "0")
        logged = self.log.read_text().strip()
        self.assertEqual(logged, "hyprshot -m region --clipboard-only")

    def test_save_only_uses_grim_not_hyprshot(self) -> None:
        self.run_script("output", "true", "false", str(self.out), "0")
        self.assertFalse(self.log.exists(), "hyprshot should not run for save-only")
        shots = list(self.out.glob("*.png"))
        self.assertEqual(len(shots), 1)
        self.assertEqual(shots[0].read_text(), "png")

    def test_delay_is_honored(self) -> None:
        t0 = time.monotonic()
        self.run_script("output", "true", "true", str(self.out), "1")
        elapsed = time.monotonic() - t0
        # Fixed 0.2s panel-close sleep + 1s delay
        self.assertGreaterEqual(elapsed, 1.1)
        self.assertLess(elapsed, 3.0)

    def test_invalid_delay_is_ignored(self) -> None:
        t0 = time.monotonic()
        self.run_script("output", "true", "true", str(self.out), "9")
        elapsed = time.monotonic() - t0
        # Only the fixed 0.2s panel-close sleep
        self.assertLess(elapsed, 1.0)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Tests for yahr-lock (pre-lock hyprlock font sync wrapper)."""

from __future__ import annotations

import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).with_name("yahr-lock")

PALETTE = {
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


class YahrLockTests(unittest.TestCase):
    def test_script_is_executable(self) -> None:
        mode = SCRIPT.stat().st_mode
        self.assertTrue(mode & stat.S_IXUSR)

    def test_syncs_font_before_exec_hyprlock(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            yahr = home / ".config" / "yahr"
            hypr = home / ".config" / "hypr"
            bindir = home / "bin"
            yahr.mkdir(parents=True)
            hypr.mkdir(parents=True)
            bindir.mkdir(parents=True)
            (yahr / "repo-root").write_text(str(ROOT) + "\n")
            (yahr / "current.json").write_text(json.dumps(PALETTE) + "\n")
            (yahr / "settings.json").write_text(
                json.dumps({"general": {"uiFont": "Space Grotesk"}}) + "\n"
            )
            (hypr / "hyprlock.conf").write_text("$ui = Inter\n")

            # Fake hyprlock records that it was exec'd; wrapper replaces itself.
            fake = bindir / "hyprlock"
            fake.write_text(
                "#!/usr/bin/env bash\n"
                f'echo "hyprlock-ran" > "{home}/locked"\n'
                f'grep "^\\$ui" "{hypr}/hyprlock.conf" > "{home}/font"\n'
            )
            fake.chmod(0o755)

            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{bindir}:{env.get('PATH', '')}"
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((home / "locked").is_file())
            font = (home / "font").read_text()
            self.assertIn("$ui = Space Grotesk", font)
            conf = (hypr / "hyprlock.conf").read_text()
            self.assertIn("$ui = Space Grotesk", conf)


if __name__ == "__main__":
    unittest.main()

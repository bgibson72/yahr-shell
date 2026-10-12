#!/usr/bin/env python3
"""Tests for sync-theme-engine-from-repo.py."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SYNC = ROOT / "sync-theme-engine-from-repo.py"


class SyncThemeEngineTests(unittest.TestCase):
    def test_sync_prefers_repo_and_rewrites_wrapper(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            repo = Path(tmp) / "repo"
            engine = repo / "theme-engine"
            pkg = engine / "yahr_theme"
            pkg.mkdir(parents=True)
            (pkg / "__init__.py").write_text("")
            (pkg / "templates.py").write_text("MARKER = 'from-repo'\n")
            (engine / "yahr-theme").write_text("#!/usr/bin/env python3\nprint('ok')\n")
            (engine / "yahr-theme").chmod(0o755)

            env = os.environ.copy()
            env["HOME"] = str(home)
            result = subprocess.run(
                ["python3", str(SYNC), "--repo", str(repo)],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            share_templates = home / ".local/share/yahr-shell/theme-engine/yahr_theme/templates.py"
            self.assertTrue(share_templates.is_file())
            self.assertIn("from-repo", share_templates.read_text())
            wrapper = home / ".local/bin/yahr-theme"
            self.assertTrue(wrapper.is_file())
            text = wrapper.read_text()
            self.assertIn("repo-root", text)
            self.assertIn("theme-engine", text)
            repo_root = home / ".config/yahr/repo-root"
            self.assertEqual(repo_root.read_text().strip(), str(repo.resolve()))


if __name__ == "__main__":
    unittest.main()

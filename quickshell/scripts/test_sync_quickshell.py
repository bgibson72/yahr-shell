#!/usr/bin/env python3
"""Tests for sync-quickshell-from-repo stale detection (no home mutations)."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "quickshell" / "scripts" / "sync-quickshell-from-repo.py"


def load_mod():
    spec = importlib.util.spec_from_file_location("sync_qs", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class SyncQuickshellTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_mod()

    def test_repo_panel_is_not_stale(self):
        self.assertFalse(self.mod.is_stale(ROOT / "quickshell"))

    def test_detects_legacy_blur_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            panel = root / "modules" / "settings" / "SettingsPanel.qml"
            panel.parent.mkdir(parents=True)
            panel.write_text('label: "Blur background"\n', encoding="utf-8")
            self.assertTrue(self.mod.is_stale(root))

    def test_detects_legacy_transparency_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            panel = root / "modules" / "settings" / "SettingsPanel.qml"
            panel.parent.mkdir(parents=True)
            panel.write_text('title: "Login Window Transparency"\n', encoding="utf-8")
            self.assertTrue(self.mod.is_stale(root))

    def test_detects_legacy_dock_shape_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            panel = root / "modules" / "settings" / "SettingsPanel.qml"
            panel.parent.mkdir(parents=True)
            panel.write_text('text: "Dock shape"\n', encoding="utf-8")
            self.assertTrue(self.mod.is_stale(root))

    def test_wallpaper_types_present_in_repo(self):
        self.assertTrue(self.mod.verify_wallpaper_types(ROOT / "quickshell"))


if __name__ == "__main__":
    unittest.main()

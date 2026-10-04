#!/usr/bin/env python3
"""Tests for SDDM wallpaper encoding helpers (no sudo)."""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "quickshell" / "scripts" / "sddm-apply.py"


def load_apply():
    spec = importlib.util.spec_from_file_location("sddm_apply", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class WallpaperMagicTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_apply()
        cls.png = ROOT / "wallpapers" / "Catppuccin" / "abstract.png"
        cls.jpg = ROOT / "wallpapers" / "Catppuccin" / "pxfuel.jpg"

    def test_png_magic(self):
        self.assertTrue(self.png.is_file())
        self.assertTrue(self.mod.is_png(self.png))
        self.assertFalse(self.mod.is_jpeg(self.png))

    def test_jpeg_magic(self):
        self.assertTrue(self.jpg.is_file())
        self.assertTrue(self.mod.is_jpeg(self.jpg))
        self.assertFalse(self.mod.is_png(self.jpg))

    def test_encode_png_from_jpeg_when_magick_present(self):
        magick = self.mod.shutil.which("magick") or self.mod.shutil.which("convert")
        if not magick:
            self.skipTest("ImageMagick not installed")
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "out.png"
            ok = self.mod.encode_resized_png(self.jpg, dest)
            self.assertTrue(ok, "magick should produce a PNG")
            self.assertTrue(self.mod.is_png(dest))
            self.assertGreater(dest.stat().st_size, 32)


if __name__ == "__main__":
    unittest.main()

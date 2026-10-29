#!/usr/bin/env python3
"""Tests for SDDM wallpaper encoding and settings sync helpers (no sudo)."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "quickshell" / "scripts" / "sddm-apply.py"
THEME_CONF = ROOT / "sddm" / "yahr-theme" / "theme.conf"


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

    def test_fixed_greeter_blur_radius(self):
        self.assertEqual(self.mod.GREETER_BACKGROUND_BLUR, 40)

    def test_fixed_widget_opacity(self):
        self.assertEqual(self.mod.GREETER_WIDGET_OPACITY, "0.75")

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


class SettingsSyncTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_apply()

    def test_ui_font_from_settings(self):
        self.assertEqual(self.mod.ui_font_key({"general": {"uiFont": "Manrope"}}), "Manrope")
        self.assertEqual(self.mod.ui_font_key({}), "Inter")
        self.assertEqual(self.mod.ui_font_key({"general": {"uiFont": "Space Grostek"}}), "Space Grotesk")
        self.assertEqual(self.mod.resolve_ui_font({"general": {"uiFont": "Space Grotesk"}}), "Space Grotesk")

    def test_frame_settings_docked_default(self):
        frame = self.mod.frame_settings({
            "bar": {"barStyle": "single", "floating": False, "position": "top", "barSize": "small"},
            "hypr": {"gapsOut": 14, "rounding": 16},
        })
        self.assertEqual(frame["UseFrame"], "true")
        self.assertEqual(frame["FrameThickness"], "14")
        self.assertEqual(frame["FrameInnerRadius"], "16")
        self.assertNotIn("BarHeight", frame)
        self.assertNotIn("BarPosition", frame)

    def test_frame_settings_floating_disables_frame(self):
        frame = self.mod.frame_settings({
            "bar": {"barStyle": "single", "floating": True},
            "hypr": {"gapsOut": 10, "rounding": 12},
        })
        self.assertEqual(frame["UseFrame"], "false")

    def test_frame_settings_islands_disables_frame(self):
        frame = self.mod.frame_settings({
            "bar": {"barStyle": "islands", "floating": False},
            "hypr": {},
        })
        self.assertEqual(frame["UseFrame"], "false")

    def test_frame_settings_opaque_fill(self):
        frame = self.mod.frame_settings({
            "bar": {
                "barStyle": "single",
                "floating": False,
                "backgroundStyle": "opaque",
            },
            "hypr": {"gapsOut": 8, "rounding": 10},
        })
        self.assertEqual(frame["UseFrame"], "true")
        self.assertEqual(frame["FrameThickness"], "10")  # max(10, gaps)
        self.assertEqual(frame["FrameOpacity"], "1.00")

    def test_apply_palette_writes_font_and_frame(self):
        text = THEME_CONF.read_text()
        out = self.mod.apply_palette(text, {
            "general": {"uiFont": "Space Grotesk", "clockFormat24hr": True, "showSeconds": False, "dateFormat": "MDY"},
            "bar": {"barStyle": "single", "floating": False, "position": "top", "barSize": "small", "barOpacity": 0.7},
            "hypr": {"gapsOut": 12, "rounding": 18},
        })
        self.assertIn('Font="Space Grotesk"', out)
        self.assertIn('FontKey="Space Grotesk"', out)
        self.assertIn('TitleFont="Space Grotesk"', out)
        self.assertIn("UseFrame=true", out)
        self.assertIn("FrameThickness=12", out)
        self.assertIn("FrameInnerRadius=18", out)
        self.assertIn('TimeFormat="HH:mm"', out)

    def test_theme_main_v4_inline_frame_and_loader(self):
        theme = ROOT / "sddm" / "yahr-theme"
        main = (theme / "Main.qml").read_text()
        self.assertIn("YAHR_SDDM_MAIN_V=4", main)
        self.assertIn("resolveUiFont", main)
        self.assertIn("useFrame", main)
        self.assertIn("loginReveal", main)
        self.assertIn("panelLoader", main)
        self.assertIn("panelSlot", main)
        self.assertIn("loginPanelComponent", main)
        self.assertIn("toggleLogin", main)
        self.assertIn("frameCanvas", main)
        self.assertNotIn('import "Components"', main)
        self.assertNotIn("barHeight", main)
        self.assertEqual(main.count("{"), main.count("}"))

    def test_find_theme_dir_prefers_versioned_main(self):
        theme = self.mod.find_theme_dir()
        self.assertIsNotNone(theme)
        self.assertGreaterEqual(self.mod._theme_main_version(theme / "Main.qml"), 4)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Checks that widget shadows track Hyprland shadow presets."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EFFECT = ROOT / "quickshell" / "components" / "WidgetShadowEffect.qml"
PANEL = ROOT / "quickshell" / "modules" / "settings" / "SettingsPanel.qml"

PRESETS = {
    "off": {"range": 0, "alpha": 0},
    "light": {"range": 10, "alpha": 18},
    "moderate": {"range": 20, "alpha": 33},
    "heavy": {"range": 40, "alpha": 55},
}


def shadow_px(range_px: int) -> int:
    return max(2, min(64, range_px))


def shadow_alpha(alpha_pct: int) -> float:
    return min(1.0, alpha_pct / 100 * 1.15)


def shadow_scale(range_px: int) -> float:
    return 1.0 + shadow_px(range_px) / 200


def legacy_effective_radius(range_px: int, blur_max: int = 32) -> float:
    """Old WidgetShadowEffect mapping that collapsed presets."""
    blur = min(1.0, 0.55 + range_px / 70)
    return blur * blur_max


class WidgetShadowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.effect = EFFECT.read_text(encoding="utf-8")
        cls.panel = PANEL.read_text(encoding="utf-8")

    def test_presets_match_settings_panel(self):
        for name, expected in PRESETS.items():
            match = re.search(
                rf"{name}:\s*\{{\s*range:\s*(\d+),\s*alpha:\s*(\d+)\s*\}}",
                self.panel,
            )
            self.assertIsNotNone(match, f"missing preset {name}")
            self.assertEqual(int(match.group(1)), expected["range"])
            self.assertEqual(int(match.group(2)), expected["alpha"])

    def test_effect_maps_range_to_blur_max(self):
        self.assertIn("blurMax: shadowPx", self.effect)
        self.assertIn("shadowBlur: 1.0", self.effect)
        self.assertNotIn("0.55 + ThemeManager.hyprShadowRange / 70", self.effect)

    def test_presets_diverge_in_pixel_radius(self):
        light = shadow_px(PRESETS["light"]["range"])
        moderate = shadow_px(PRESETS["moderate"]["range"])
        heavy = shadow_px(PRESETS["heavy"]["range"])
        self.assertEqual(light, 10)
        self.assertEqual(moderate, 20)
        self.assertEqual(heavy, 40)
        # Heavy should be clearly larger than light (old mapping was ~1.4x).
        self.assertGreaterEqual(heavy / light, 3.0)

    def test_legacy_mapping_was_compressed(self):
        light = legacy_effective_radius(PRESETS["light"]["range"])
        heavy = legacy_effective_radius(PRESETS["heavy"]["range"])
        self.assertLess(heavy / light, 1.6)

    def test_alpha_and_scale_track_presets(self):
        alphas = [shadow_alpha(PRESETS[p]["alpha"]) for p in ("light", "moderate", "heavy")]
        scales = [shadow_scale(PRESETS[p]["range"]) for p in ("light", "moderate", "heavy")]
        self.assertLess(alphas[0], alphas[1])
        self.assertLess(alphas[1], alphas[2])
        self.assertLess(scales[0], scales[1])
        self.assertLess(scales[1], scales[2])


if __name__ == "__main__":
    unittest.main()

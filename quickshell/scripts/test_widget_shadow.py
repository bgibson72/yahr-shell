#!/usr/bin/env python3
"""Checks that widget shadows track Hyprland shadow presets via RectangularShadow."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EFFECT = ROOT / "quickshell" / "components" / "WidgetShadowEffect.qml"
PANEL = ROOT / "quickshell" / "modules" / "settings" / "SettingsPanel.qml"
PANEL_CHROME = ROOT / "quickshell" / "components" / "Panel.qml"

PRESETS = {
    "off": {"range": 0, "alpha": 0},
    "light": {"range": 10, "alpha": 18},
    "moderate": {"range": 20, "alpha": 33},
    "heavy": {"range": 40, "alpha": 55},
}


def shadow_blur(range_px: int) -> float:
    return max(0, range_px) * 1.2


def shadow_spread(range_px: int) -> float:
    return max(0, range_px) * 0.2


def shadow_alpha(alpha_pct: int) -> float:
    return min(1.0, alpha_pct / 100 * 1.15)


class WidgetShadowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.effect = EFFECT.read_text(encoding="utf-8")
        cls.panel = PANEL.read_text(encoding="utf-8")
        cls.chrome = PANEL_CHROME.read_text(encoding="utf-8")

    def test_presets_match_settings_panel(self):
        for name, expected in PRESETS.items():
            match = re.search(
                rf"{name}:\s*\{{\s*range:\s*(\d+),\s*alpha:\s*(\d+)\s*\}}",
                self.panel,
            )
            self.assertIsNotNone(match, f"missing preset {name}")
            self.assertEqual(int(match.group(1)), expected["range"])
            self.assertEqual(int(match.group(2)), expected["alpha"])

    def test_uses_rectangular_shadow_not_multieffect_layer(self):
        self.assertRegex(self.effect, r"(?m)^RectangularShadow \{")
        self.assertNotRegex(self.effect, r"(?m)^MultiEffect \{")
        self.assertNotIn("layer.effect: WidgetShadowEffect", self.chrome)
        self.assertNotIn("layer.enabled:", self.chrome)
        self.assertIn("WidgetShadowEffect {", self.chrome)
        self.assertIn("cornerRadius: panel.freeR", self.chrome)

    def test_blur_and_spread_track_hyprland_range(self):
        self.assertIn("blur: shadowPx * 1.2", self.effect)
        self.assertIn("spread: shadowPx * 0.2", self.effect)

    def test_presets_diverge_in_blur_pixels(self):
        light = shadow_blur(PRESETS["light"]["range"])
        moderate = shadow_blur(PRESETS["moderate"]["range"])
        heavy = shadow_blur(PRESETS["heavy"]["range"])
        self.assertEqual(light, 12.0)
        self.assertEqual(moderate, 24.0)
        self.assertEqual(heavy, 48.0)
        self.assertGreaterEqual(heavy / light, 3.0)
        self.assertLess(shadow_spread(PRESETS["light"]["range"]),
                        shadow_spread(PRESETS["heavy"]["range"]))

    def test_alpha_tracks_presets(self):
        alphas = [shadow_alpha(PRESETS[p]["alpha"]) for p in ("light", "moderate", "heavy")]
        self.assertLess(alphas[0], alphas[1])
        self.assertLess(alphas[1], alphas[2])

    def test_legacy_multieffect_blurmax_mapping_removed(self):
        self.assertNotIn("blurMax: shadowPx", self.effect)
        self.assertNotIn("0.55 + ThemeManager.hyprShadowRange / 70", self.effect)


if __name__ == "__main__":
    unittest.main()

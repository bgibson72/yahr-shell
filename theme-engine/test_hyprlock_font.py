#!/usr/bin/env python3
"""hyprlock.conf must track the Settings UI font."""

from __future__ import annotations

import unittest

from yahr_theme import apply, templates


class HyprlockFontTests(unittest.TestCase):
    def test_resolve_ui_font_catalog_keys(self) -> None:
        self.assertEqual(apply.resolve_ui_font({"general": {"uiFont": "Manrope"}}), "Manrope")
        self.assertEqual(apply.resolve_ui_font({"general": {"uiFont": "Source Sans"}}), "Source Sans 3")
        self.assertEqual(apply.resolve_ui_font({"general": {"uiFont": "Space Grotesk"}}), "Space Grotesk")
        self.assertEqual(apply.resolve_ui_font({}), "Inter")

    def test_hyprlock_conf_uses_ui_font(self) -> None:
        palette = {
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
        text = templates.hyprlock_conf(palette, ui_font="Manrope")
        self.assertIn("$ui = Manrope", text)
        self.assertIn("$uiBold = Manrope ExtraBold", text)
        self.assertIn("font_family = $uiBold", text)
        self.assertIn("font_family = $ui", text)
        self.assertNotIn("Inter ExtraBold", text)
        self.assertNotIn("$ui = Inter", text)


if __name__ == "__main__":
    unittest.main()

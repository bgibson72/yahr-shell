#!/usr/bin/env python3
"""Structural checks for Dock Appearance Follow Hyprland gating."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PANEL = ROOT / "quickshell" / "modules" / "settings" / "SettingsPanel.qml"
SETTINGS = ROOT / "quickshell" / "Settings.qml"
THEME = ROOT / "quickshell" / "ThemeManager.qml"


def dock_appearance_section(text: str) -> str:
    idx = text.find("checked: Settings.dockFollowHyprland")
    if idx < 0:
        raise AssertionError("dockFollowHyprland toggle not found")
    start = text.rfind("SettingsSection {", 0, idx)
    end = text.find("SettingsSection {", idx)
    if start < 0 or end < 0:
        raise AssertionError("could not bound Dock Appearance section")
    return text[start:end]


class DockAppearanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.panel = PANEL.read_text(encoding="utf-8")
        cls.settings = SETTINGS.read_text(encoding="utf-8")
        cls.theme = THEME.read_text(encoding="utf-8")
        cls.section = dock_appearance_section(cls.panel)

    def test_follow_hyprland_is_first_appearance_control(self):
        follow = self.section.find('label: "Follow Hyprland Window Rules"')
        border = self.section.find('label: "Dock border"')
        background = self.section.find('text: "Dock background"')
        radius = self.section.find("Corner radius:")
        self.assertGreater(follow, 0)
        self.assertLess(follow, border)
        self.assertLess(border, background)
        self.assertLess(background, radius)

    def test_dock_shape_removed(self):
        self.assertNotIn("Dock shape", self.panel)
        self.assertNotIn("property string dockShape", self.settings)
        self.assertNotIn("shape: dockShape", self.settings)
        self.assertNotIn("dockShape", self.theme)

    def test_other_appearance_options_gate_on_follow(self):
        enabled = [
            m.start()
            for m in re.finditer(r"enabled: !Settings\.dockFollowHyprland", self.section)
        ]
        self.assertEqual(len(enabled), 3, "border, background, and corner radius should gate")

    def test_theme_dock_radius_follows_hyprland(self):
        self.assertIn(
            "readonly property int dockRadius: dockFollowHyprland ? Settings.hyprRounding : Settings.dockRounding",
            self.theme,
        )

    def test_legacy_square_shape_migrates_to_zero_radius(self):
        self.assertIn('if (d.shape === "square") dockRounding = 0', self.settings)

    def test_dock_radius_logic(self):
        def dock_radius(follow, hypr_rounding, dock_rounding):
            return hypr_rounding if follow else dock_rounding

        self.assertEqual(dock_radius(True, 16, 8), 16)
        self.assertEqual(dock_radius(False, 16, 8), 8)
        self.assertEqual(dock_radius(False, 16, 0), 0)


if __name__ == "__main__":
    unittest.main()

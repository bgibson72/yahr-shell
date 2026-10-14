#!/usr/bin/env python3
"""Lock gaming window rules to Steam / gamescope patterns and tearing hooks."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

HYPR = Path(__file__).resolve().parent
RULES = (HYPR / "rules.lua").read_text()
APPEARANCE = (HYPR / "appearance.lua").read_text()
KEYBINDS = (HYPR / "keybinds.lua").read_text()


class GamingRulesTest(unittest.TestCase):
    def test_tearing_master_toggle_enabled(self) -> None:
        self.assertIn("allow_tearing = true", APPEARANCE)

    def test_vrr_fullscreen_only(self) -> None:
        self.assertRegex(APPEARANCE, r"vrr\s*=\s*2")

    def test_steam_app_tag_rule(self) -> None:
        self.assertIn('class = "^steam_app_"', RULES)
        self.assertIn('tag = "+game"', RULES)
        self.assertIn('content = "game"', RULES)

    def test_gamescope_tag_rule(self) -> None:
        self.assertIn("gamescope", RULES)
        self.assertIn("yahr-tag-gamescope", RULES)

    def test_game_perf_effects(self) -> None:
        self.assertIn("yahr-game-perf", RULES)
        self.assertIn("immediate = true", RULES)
        self.assertIn('idle_inhibit = "focus"', RULES)
        self.assertIn("no_anim = true", RULES)

    def test_steam_app_regex_matches_proton_classes(self) -> None:
        match = re.search(r'class = "(\^steam_app_[^"]*)"', RULES)
        self.assertIsNotNone(match)
        pattern = match.group(1).encode("utf-8").decode("unicode_escape")
        rx = re.compile(pattern)
        self.assertRegex("steam_app_730", rx)
        self.assertRegex("steam_app_1245620", rx)
        self.assertNotRegex("steam", rx)
        self.assertNotRegex("steamwebhelper", rx)

    def test_no_forced_fullscreen_on_games(self) -> None:
        # Game perf rule must not force fullscreen (borderless windowed).
        block = re.search(
            r'name = "yahr-game-perf".*?,\n\}\)',
            RULES,
            flags=re.S,
        )
        self.assertIsNotNone(block)
        self.assertNotIn("fullscreen = true", block.group(0))

    def test_gamemode_keybind(self) -> None:
        self.assertIn("toggle-gamemode.sh", KEYBINDS)
        self.assertIn("SHIFT + G", KEYBINDS)

    def test_appearance_honors_gamemode_file(self) -> None:
        self.assertIn("YAHR_GAMEMODE", APPEARANCE)
        self.assertIn("gamemode_on", APPEARANCE)
        self.assertIn("and not gamemode_on", APPEARANCE)

    def test_autostart_skips_hypridle_in_gamemode(self) -> None:
        autostart = (HYPR / "autostart.lua").read_text()
        self.assertIn(".config/yahr/gamemode", autostart)
        self.assertIn('!= \\"on\\"', autostart)
        self.assertIn("hypridle", autostart)


if __name__ == "__main__":
    unittest.main()

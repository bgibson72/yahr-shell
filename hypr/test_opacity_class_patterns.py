#!/usr/bin/env python3
"""Lock Hyprland opacity window-rule class regexes to RE2 (not Lua patterns).

Settings > Hyprland > Transparent app windows applies opacity via
yahrApplyWindowOpacity() in rules.lua. Class matches are RE2, so dots in
app ids must be written as `\\.` in the Lua string. Lua-style `%.` is a
literal percent sign and fails to match org.xfce.Thunar (Thunar's Wayland
app id), which made Thunar ignore the transparency toggle.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

RULES = Path(__file__).with_name("rules.lua").read_text()


def _lua_class_patterns() -> dict[str, str]:
    """Decode opacity_apps class strings the way Lua double-quoted strings do."""
    block = re.search(
        r"local opacity_apps = \{(.*?)\n\}",
        RULES,
        flags=re.S,
    )
    assert block, "opacity_apps table not found in rules.lua"
    found: dict[str, str] = {}
    for key, raw in re.findall(
        r'\{ key = "([^"]+)", class = "([^"]+)" \}',
        block.group(1),
    ):
        # Lua treats \\ as one backslash in the string passed to Hyprland.
        found[key] = raw.encode("utf-8").decode("unicode_escape")
    return found


class OpacityClassPatternsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.patterns = _lua_class_patterns()

    def test_thunar_wayland_app_id_matches(self) -> None:
        # Metainfo / GTK application id on current Thunar builds.
        rx = re.compile(self.patterns["xfce_thunar"])
        self.assertRegex("org.xfce.Thunar", rx)
        self.assertRegex("org.xfce.thunar", rx)
        self.assertNotRegex("org%Xxfce%Ythunar", rx)

    def test_thunar_x11_class_matches(self) -> None:
        rx = re.compile(self.patterns["thunar"])
        self.assertRegex("thunar", rx)
        self.assertRegex("Thunar", rx)

    def test_no_lua_percent_escapes_in_decoded_patterns(self) -> None:
        for key, pattern in self.patterns.items():
            self.assertNotIn(
                "%",
                pattern,
                f"{key} still contains a literal % (Lua pattern leak)",
            )

    def test_sibling_apps_still_match(self) -> None:
        cases = {
            "ghostty_id": "com.mitchellh.ghostty",
            "code_oss": "code-oss",
            "zed": "dev.zed.Zed",
            "cursor": "Cursor",
        }
        for key, app_class in cases.items():
            with self.subTest(key=key, app_class=app_class):
                self.assertRegex(app_class, re.compile(self.patterns[key]))


if __name__ == "__main__":
    unittest.main()

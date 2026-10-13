#!/usr/bin/env python3
"""Lock Thunar rename float rules to the real Wayland app id.

Thunar reports class `org.xfce.Thunar` (capital T). A lowercase-only
`org.xfce.thunar` RE2 pattern never matches, so the rename dialog stays
tiled. Handler class checks must be case-insensitive for the same reason.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

RULES = Path(__file__).with_name("rules.lua").read_text()


def _lua_string(raw: str) -> str:
    return raw.encode("utf-8").decode("unicode_escape")


def _thunar_class_pattern() -> str:
    m = re.search(r'local thunar_class = "([^"]+)"', RULES)
    assert m, "thunar_class not found in rules.lua"
    return _lua_string(m.group(1))


def _handler_accepts(class_: str, title: str) -> bool:
    """Mirror yahrMaybeFloatThunarRename gating (title + optional class)."""
    if not re.match(r"^Rename", title):
        return False
    if class_ == "":
        return True
    lowered = class_.lower()
    return lowered in ("thunar", "org.xfce.thunar")


class ThunarRenameFloatTest(unittest.TestCase):
    def test_static_class_matches_wayland_app_id(self) -> None:
        rx = re.compile(_thunar_class_pattern())
        self.assertRegex("org.xfce.Thunar", rx)
        self.assertRegex("org.xfce.thunar", rx)
        self.assertRegex("Thunar", rx)
        self.assertRegex("thunar", rx)
        self.assertNotRegex("org.gnome.Nautilus", rx)

    def test_handler_accepts_capital_t_app_id(self) -> None:
        self.assertTrue(
            _handler_accepts("org.xfce.Thunar", 'Rename "walls-main"')
        )
        self.assertTrue(_handler_accepts("Thunar", 'Rename "walls-main"'))
        self.assertTrue(_handler_accepts("thunar", "Rename"))
        self.assertTrue(_handler_accepts("", 'Rename "x"'))

    def test_handler_rejects_non_rename_and_other_apps(self) -> None:
        self.assertFalse(
            _handler_accepts("org.xfce.Thunar", "Downloads - Thunar")
        )
        self.assertFalse(
            _handler_accepts("ghostty", 'Rename "walls-main"')
        )

    def test_uses_hl_dispatch_for_immediate_float(self) -> None:
        self.assertIn("hl.dispatch(hl.dsp.window.float", RULES)
        self.assertIn("hl.dispatch(hl.dsp.window.center", RULES)
        self.assertIn("title:^(Rename)", RULES)
        self.assertIn("size = { 520, 200 }", RULES)


if __name__ == "__main__":
    unittest.main()

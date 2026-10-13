#!/usr/bin/env python3
"""Lock Thunar rename float rules to the real Wayland app id and placement.

Thunar reports class `org.xfce.Thunar` (capital T). The rename dialog also
maps as a large tiled window; floating without a window selector can hit the
main Thunar instead, leaving the dialog fullscreen underneath. Placement
must target the dialog, resize after float, center, focus, and raise.
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

    def test_places_dialog_with_explicit_target_resize_and_raise(self) -> None:
        self.assertIn("yahrPlaceThunarRename", RULES)
        # Must not float the active window blindly (that hit main Thunar).
        self.assertNotIn(
            'hl.dsp.window.float({ action = "set" })',
            RULES,
        )
        self.assertIn('float({ action = "set", window = sel })', RULES)
        self.assertIn("hl.dsp.window.resize({", RULES)
        self.assertIn("relative = false", RULES)
        self.assertIn('alter_zorder({ mode = "top", window = sel })', RULES)
        self.assertIn("hl.dsp.focus({ window = sel })", RULES)
        self.assertIn("stay_focused = true", RULES)
        self.assertIn("thunar_rename_w = 480", RULES)
        self.assertIn("thunar_rename_h = 170", RULES)
        self.assertIn('type = "oneshot"', RULES)


if __name__ == "__main__":
    unittest.main()

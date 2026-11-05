#!/usr/bin/env python3
"""hyprlock.conf must track the Settings UI font."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from yahr_theme import apply, cli, paths, templates

PALETTE = {
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


class HyprlockFontTests(unittest.TestCase):
    def test_resolve_ui_font_catalog_keys(self) -> None:
        self.assertEqual(apply.resolve_ui_font({"general": {"uiFont": "Manrope"}}), "Manrope")
        self.assertEqual(apply.resolve_ui_font({"general": {"uiFont": "Source Sans"}}), "Source Sans 3")
        self.assertEqual(apply.resolve_ui_font({"general": {"uiFont": "Space Grotesk"}}), "Space Grotesk")
        self.assertEqual(apply.resolve_ui_font({"general": {"uiFont": "Space Grostek"}}), "Space Grotesk")
        self.assertEqual(apply.resolve_ui_font({}), "Inter")

    def test_hyprlock_conf_uses_ui_font(self) -> None:
        text = templates.hyprlock_conf(PALETTE, ui_font="Manrope")
        self.assertIn("$ui = Manrope", text)
        self.assertIn("$uiBold = Manrope", text)
        self.assertIn("font_family = $uiBold", text)
        self.assertIn("font_family = $ui", text)
        self.assertNotIn("ExtraBold", text)
        self.assertNotIn("$ui = Inter", text)

    def test_sync_hyprlock_conf_and_cli(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            yahr = home / ".config" / "yahr"
            hypr = home / ".config" / "hypr"
            yahr.mkdir(parents=True)
            hypr.mkdir(parents=True)
            (yahr / "current.json").write_text(json.dumps(PALETTE) + "\n")
            (yahr / "settings.json").write_text(
                json.dumps({"general": {"uiFont": "Space Grotesk"}}) + "\n"
            )
            (hypr / "hyprlock.conf").write_text("$ui = Inter\n")

            with mock.patch.object(paths, "home", return_value=home):
                conf, font, mode = apply.sync_hyprlock_conf()
                self.assertEqual(font, "Space Grotesk")
                self.assertEqual(mode, "wrote")
                self.assertIn("$ui = Space Grotesk", conf.read_text())

                conf.write_text("$ui = Inter\n")
                ns = argparse_ns(ui_font="Manrope")
                with mock.patch.dict(os.environ, {"HOME": str(home)}):
                    # cmd uses paths.home via apply — already patched
                    rc = cli.cmd_sync_hyprlock(ns)
                self.assertEqual(rc, 0)
                self.assertIn("$ui = Manrope", conf.read_text())


def argparse_ns(**kwargs):
    class NS:
        pass

    ns = NS()
    for key, value in kwargs.items():
        setattr(ns, key, value)
    return ns


if __name__ == "__main__":
    unittest.main()

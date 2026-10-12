#!/usr/bin/env python3
"""Guards against squared Firefox toolbarbutton hover overlays."""

from __future__ import annotations

import unittest

from yahr_theme.templates import firefox_user_chrome

SAMPLE = {
    "name": "Test",
    "bgBase": "#1e1e2e",
    "surface0": "#313244",
    "surface1": "#45475a",
    "fgPrimary": "#cdd6f4",
    "fgSecondary": "#a6adc8",
    "accentBlue": "#89b4fa",
    "accentGreen": "#a6e3a1",
    "accentRed": "#f38ba8",
    "accentYellow": "#f9e2af",
    "accentOrange": "#fab387",
}


class FirefoxUserChromeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.css = firefox_user_chrome(SAMPLE)

    def test_does_not_paint_square_hover_on_toolbarbutton(self) -> None:
        # The old rule painted surface1 on the button chrome itself, which
        # stacked a rectangle under Proton's pill icon-stack hover.
        self.assertNotRegex(
            self.css,
            r"toolbarbutton:hover,\s*\n\.toolbarbutton-1:hover \{\s*\n\s*background-color:\s*var\(--surface1\)",
        )

    def test_keeps_button_chrome_transparent_on_hover(self) -> None:
        self.assertIn("background-color: transparent !important;", self.css)
        self.assertIn("toolbarbutton:hover,", self.css)

    def test_themes_native_pill_hover_variables(self) -> None:
        for var in (
            "--toolbarbutton-hover-background",
            "--toolbarbutton-active-background",
            "--toolbarbutton-background-color-hover",
            "--toolbarbutton-background-color-active",
        ):
            self.assertIn(var, self.css)

    def test_clears_background_image_on_button_chrome(self) -> None:
        self.assertIn("background-image: none !important;", self.css)


if __name__ == "__main__":
    unittest.main()

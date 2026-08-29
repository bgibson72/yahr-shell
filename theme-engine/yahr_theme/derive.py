"""Derive a full Catppuccin-shaped palette from 1 background + 8 accents."""

from __future__ import annotations

import re

from .colors import darken, hash_hex, lighten, palette_mode, relative_luminance, strip_hash

_SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(name: str) -> str:
    slug = _SLUG_RE.sub("-", name.strip().lower()).strip("-")
    return slug or "custom"


def derive_palette(
    name: str,
    bg: str,
    blue: str,
    purple: str,
    pink: str,
    red: str,
    orange: str,
    yellow: str,
    green: str,
    teal: str,
    theme_id: str | None = None,
    papirus_folder: str | None = None,
) -> dict:
    bg = strip_hash(bg)
    blue = strip_hash(blue)
    purple = strip_hash(purple)
    pink = strip_hash(pink)
    red = strip_hash(red)
    orange = strip_hash(orange)
    yellow = strip_hash(yellow)
    green = strip_hash(green)
    teal = strip_hash(teal)

    tid = theme_id or slugify(name)
    wallpaper_dir = name.replace(" ", "")
    light = relative_luminance(bg) >= 0.55
    if light:
        neutrals = {
            "fgPrimary": hash_hex(darken(bg, 0.78)),
            "fgSecondary": hash_hex(darken(bg, 0.62)),
            "fgTertiary": hash_hex(darken(bg, 0.48)),
            "border2": hash_hex(darken(bg, 0.38)),
            "border1": hash_hex(darken(bg, 0.26)),
            "border0": hash_hex(darken(bg, 0.16)),
            "surface2": hash_hex(darken(bg, 0.18)),
            "surface1": hash_hex(darken(bg, 0.12)),
            "surface0": hash_hex(darken(bg, 0.07)),
            "bgMantle": hash_hex(lighten(bg, 0.08)),
            "bgCrust": hash_hex(darken(bg, 0.08)),
        }
    else:
        neutrals = {
            "fgPrimary": hash_hex(lighten(bg, 0.90)),
            "fgSecondary": hash_hex(lighten(bg, 0.78)),
            "fgTertiary": hash_hex(lighten(bg, 0.65)),
            "border2": hash_hex(lighten(bg, 0.55)),
            "border1": hash_hex(lighten(bg, 0.45)),
            "border0": hash_hex(lighten(bg, 0.35)),
            "surface2": hash_hex(lighten(bg, 0.30)),
            "surface1": hash_hex(lighten(bg, 0.20)),
            "surface0": hash_hex(lighten(bg, 0.10)),
            "bgMantle": hash_hex(darken(bg, 0.15)),
            "bgCrust": hash_hex(darken(bg, 0.30)),
        }

    palette = {
        "id": tid,
        "name": name,
        "wallpaperDir": wallpaper_dir,
        "custom": True,
        "seed": {
            "bg": hash_hex(bg),
            "blue": hash_hex(blue),
            "purple": hash_hex(purple),
            "pink": hash_hex(pink),
            "red": hash_hex(red),
            "orange": hash_hex(orange),
            "yellow": hash_hex(yellow),
            "green": hash_hex(green),
            "teal": hash_hex(teal),
        },
        "accentRose": hash_hex(pink),
        "accentCoral": hash_hex(red),
        "accentPink": hash_hex(pink),
        "accentPurple": hash_hex(purple),
        "accentRed": hash_hex(red),
        "accentMaroon": hash_hex(red),
        "accentOrange": hash_hex(orange),
        "accentYellow": hash_hex(yellow),
        "accentGreen": hash_hex(green),
        "accentTeal": hash_hex(teal),
        "accentCyan": hash_hex(teal),
        "accentSapphire": hash_hex(blue),
        "accentBlue": hash_hex(blue),
        "accentLavender": hash_hex(purple),
        **neutrals,
        "bgBase": hash_hex(bg),
        "glassAccent": hash_hex(blue) + "59",
    }
    folder = (papirus_folder or "auto").strip().lower()
    if folder and folder != "auto":
        palette["papirusFolder"] = folder
    palette["mode"] = palette_mode(palette)
    return palette

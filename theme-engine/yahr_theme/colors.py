"""Color helpers: hex parsing, mixing, and Papirus nearest-neighbor match."""

from __future__ import annotations

PAPIRUS_FOLDERS = {
    "adwaita": "93c0ea",
    "black": "dcdcdc",
    "blue": "5294e2",
    "bluegrey": "607d8b",
    "breeze": "57b8ec",
    "brown": "ae8e6c",
    "carmine": "a30002",
    "cyan": "00bcd4",
    "darkcyan": "45abb7",
    "deeporange": "eb6637",
    "green": "87b158",
    "grey": "8e8e8e",
    "indigo": "5c6bc0",
    "magenta": "ca71df",
    "nordic": "eceff4",
    "orange": "ee923a",
    "palebrown": "d1bfae",
    "paleorange": "eeca8f",
    "pink": "f06292",
    "red": "e25252",
    "teal": "16a085",
    "violet": "7e57c2",
    "white": "cccccc",
    "yaru": "ff7446",
    "yellow": "f9bd30",
}


def strip_hash(value: str) -> str:
    value = value.strip().lstrip("#")
    if len(value) == 8:
        return value[:6]
    if len(value) != 6:
        raise ValueError(f"expected 6-digit hex color, got {value!r}")
    return value.lower()


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    h = strip_hash(value)
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgb_to_hex(r: int, g: int, b: int) -> str:
    return "{:02x}{:02x}{:02x}".format(
        max(0, min(255, int(round(r)))),
        max(0, min(255, int(round(g)))),
        max(0, min(255, int(round(b)))),
    )


def mix(hex_color: str, target: tuple[int, int, int], amount: float) -> str:
    r, g, b = hex_to_rgb(hex_color)
    tr, tg, tb = target
    return rgb_to_hex(
        r + (tr - r) * amount,
        g + (tg - g) * amount,
        b + (tb - b) * amount,
    )


def darken(hex_color: str, amount: float) -> str:
    return mix(hex_color, (0, 0, 0), amount)


def lighten(hex_color: str, amount: float) -> str:
    return mix(hex_color, (255, 255, 255), amount)


def relative_luminance(hex_color: str) -> float:
    r, g, b = hex_to_rgb(hex_color)
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def contrast_on(bg_hex: str, dark: str = "#1b1e2b", light: str = "#ffffff") -> str:
    """Foreground that stays readable on bg_hex."""
    try:
        return dark if relative_luminance(bg_hex) > 0.55 else light
    except ValueError:
        return light


def palette_mode(palette: dict) -> str:
    mode = str(palette.get("mode", "")).strip().lower()
    if mode in ("light", "dark"):
        return mode
    bg = palette.get("bgBase") or palette.get("bg_base") or "#000000"
    try:
        return "light" if relative_luminance(bg) >= 0.55 else "dark"
    except ValueError:
        return "dark"


def hash_hex(value: str) -> str:
    return "#" + strip_hash(value)


def rgb_css(value: str) -> str:
    return f"rgb({strip_hash(value)})"


def rgba_css(value: str, alpha_hex: str = "ff") -> str:
    return f"rgba({strip_hash(value)}{alpha_hex.lower()})"


def nearest_papirus(accent_hex: str) -> str:
    tr, tg, tb = hex_to_rgb(accent_hex)
    best_name = "blue"
    best_dist = 10**18
    for name, hexv in PAPIRUS_FOLDERS.items():
        r, g, b = hex_to_rgb(hexv)
        dist = (r - tr) ** 2 + (g - tg) ** 2 + (b - tb) ** 2
        if dist < best_dist:
            best_dist = dist
            best_name = name
    return best_name


# Bundled palettes → Papirus folder color. Light variants inherit the family name.
PAPIRUS_THEME_FOLDERS = {
    "catppuccin": "adwaita",
    "dracula": "magenta",
    "eldritch": "violet",
    "everforest": "green",
    "gruvbox": "orange",
    "kanagawa": "paleorange",
    "material": "indigo",
    "monochrome": "black",
    "nightfox": "darkcyan",
    "dayfox": "darkcyan",
    "tokyo-night": "indigo",
    "rose-pine": "cyan",
    "nord": "nordic",
    "solarized": "cyan",
}

GNOME_ACCENTS = {
    "blue": "3584e4",
    "teal": "2190a4",
    "green": "3a944a",
    "yellow": "c88800",
    "orange": "ed5b00",
    "red": "e01b24",
    "pink": "d56199",
    "purple": "9141ac",
    "slate": "6f8396",
}

PAPIRUS_TO_GNOME = {
    "adwaita": "blue",
    "blue": "blue",
    "breeze": "blue",
    "indigo": "blue",
    "cyan": "teal",
    "darkcyan": "teal",
    "teal": "teal",
    "green": "green",
    "yellow": "yellow",
    "paleorange": "yellow",
    "orange": "orange",
    "deeporange": "orange",
    "yaru": "orange",
    "brown": "orange",
    "palebrown": "orange",
    "red": "red",
    "carmine": "red",
    "pink": "pink",
    "magenta": "pink",
    "violet": "purple",
    "nordic": "slate",
    "bluegrey": "slate",
    "grey": "slate",
    "black": "slate",
    "white": "slate",
}


def papirus_folder_for(palette: dict) -> str:
    explicit = str(palette.get("papirusFolder") or "").strip().lower()
    if explicit in PAPIRUS_FOLDERS:
        return explicit
    tid = str(palette.get("id") or "").strip().lower()
    if tid in PAPIRUS_THEME_FOLDERS:
        return PAPIRUS_THEME_FOLDERS[tid]
    for key in sorted(PAPIRUS_THEME_FOLDERS, key=len, reverse=True):
        if tid.startswith(key + "-"):
            return PAPIRUS_THEME_FOLDERS[key]
    return nearest_papirus(str(palette.get("accentBlue") or "#5294e2"))


def nearest_gnome_accent(accent_hex: str) -> str:
    tr, tg, tb = hex_to_rgb(accent_hex)
    best_name = "blue"
    best_dist = 10**18
    for name, hexv in GNOME_ACCENTS.items():
        r, g, b = hex_to_rgb(hexv)
        dist = (r - tr) ** 2 + (g - tg) ** 2 + (b - tb) ** 2
        if dist < best_dist:
            best_dist = dist
            best_name = name
    return best_name

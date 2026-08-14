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

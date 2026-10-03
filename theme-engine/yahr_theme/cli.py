"""yahr-theme CLI."""

from __future__ import annotations

import argparse
import json
import sys

from . import apply, derive
from .paths import current_json


def _print_json(obj) -> None:
    json.dump(obj, sys.stdout, indent=2)
    sys.stdout.write("\n")


def cmd_list(args: argparse.Namespace) -> int:
    themes = apply.list_themes()
    if getattr(args, "json", False):
        _print_json(themes)
        return 0
    for theme in themes:
        mark = "*" if theme["active"] else " "
        kind = "custom" if theme["custom"] else "bundled"
        print(f"{mark} {theme['id']:16}  {theme['name']:20}  {kind:8}  {theme['mode']}")
    return 0


def cmd_current(_args: argparse.Namespace) -> int:
    path = current_json()
    if not path.is_file():
        print("no theme applied yet", file=sys.stderr)
        return 1
    _print_json(json.loads(path.read_text()))
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    palette = apply.apply_id(args.theme, reload=not args.no_reload)
    print(f"applied {palette['name']} ({palette['id']})")
    # Firefox status is printed by apply_palette (path written, or a warning).
    return 0


def cmd_save(args: argparse.Namespace) -> int:
    palette = derive.derive_palette(
        name=args.name,
        bg=args.bg,
        blue=args.blue,
        purple=args.purple,
        pink=args.pink,
        red=args.red,
        orange=args.orange,
        yellow=args.yellow,
        green=args.green,
        teal=args.teal,
        theme_id=args.id,
        papirus_folder=getattr(args, "papirus_folder", None),
    )
    path = apply.save_palette(palette, apply_now=not args.no_apply)
    print(f"saved {palette['id']} -> {path}")
    return 0


def cmd_delete(args: argparse.Namespace) -> int:
    apply.delete_theme(args.theme)
    print(f"deleted {args.theme}")
    return 0


def cmd_derive(args: argparse.Namespace) -> int:
    palette = derive.derive_palette(
        name=args.name,
        bg=args.bg,
        blue=args.blue,
        purple=args.purple,
        pink=args.pink,
        red=args.red,
        orange=args.orange,
        yellow=args.yellow,
        green=args.green,
        teal=args.teal,
        theme_id=args.id,
        papirus_folder=getattr(args, "papirus_folder", None),
    )
    _print_json(palette)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="yahr-theme",
        description="Apply Yahr Shell palettes across Hyprland, Quickshell, GTK, Ghostty, Starship, Mako, and more.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_list = sub.add_parser("list", help="list bundled and user themes")
    p_list.add_argument("--json", action="store_true", help="print theme metadata as JSON")
    p_list.set_defaults(func=cmd_list)

    p_current = sub.add_parser("current", help="print the active palette JSON")
    p_current.set_defaults(func=cmd_current)

    p_apply = sub.add_parser("apply", help="apply a theme by id or name")
    p_apply.add_argument("theme")
    p_apply.add_argument("--no-reload", action="store_true", help="write files without reloading running apps")
    p_apply.set_defaults(func=cmd_apply)

    p_save = sub.add_parser("save", help="derive and save a custom theme")
    p_save.add_argument("--name", required=True)
    p_save.add_argument("--id")
    p_save.add_argument("--bg", required=True)
    p_save.add_argument("--blue", required=True)
    p_save.add_argument("--purple", required=True)
    p_save.add_argument("--pink", required=True)
    p_save.add_argument("--red", required=True)
    p_save.add_argument("--orange", required=True)
    p_save.add_argument("--yellow", required=True)
    p_save.add_argument("--green", required=True)
    p_save.add_argument("--teal", required=True)
    p_save.add_argument("--papirus-folder", default="auto", help="Papirus folder color, or auto")
    p_save.add_argument("--no-apply", action="store_true")
    p_save.set_defaults(func=cmd_save)

    p_del = sub.add_parser("delete", help="delete a user-saved custom theme")
    p_del.add_argument("theme")
    p_del.set_defaults(func=cmd_delete)

    p_derive = sub.add_parser("derive", help="print a derived palette without saving")
    p_derive.add_argument("--name", default="Custom")
    p_derive.add_argument("--id")
    p_derive.add_argument("--bg", required=True)
    p_derive.add_argument("--blue", required=True)
    p_derive.add_argument("--purple", required=True)
    p_derive.add_argument("--pink", required=True)
    p_derive.add_argument("--red", required=True)
    p_derive.add_argument("--orange", required=True)
    p_derive.add_argument("--yellow", required=True)
    p_derive.add_argument("--green", required=True)
    p_derive.add_argument("--teal", required=True)
    p_derive.add_argument("--papirus-folder", default="auto")
    p_derive.set_defaults(func=cmd_derive)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (FileNotFoundError, PermissionError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

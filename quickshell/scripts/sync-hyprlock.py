#!/usr/bin/env python3
"""Rewrite ~/.config/hypr/hyprlock.conf from the current palette and Settings UI font.

Resolves theme-engine the same way as yahr-theme-cli so a copied
~/.config/quickshell (parents[2] == ~/.config) still finds the package.
Pass --ui-font to avoid racing Settings.FileView saves.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))


def find_theme_engine() -> Path | None:
    """Locate theme-engine with yahr_theme/ (repo-root, checkout, then share)."""
    repo_root_file = HOME / ".config/yahr/repo-root"
    if repo_root_file.is_file():
        try:
            root = Path(repo_root_file.read_text().strip()).expanduser().resolve()
        except OSError:
            root = None
        if root and (root / "theme-engine" / "yahr_theme").is_dir():
            return root / "theme-engine"

    here = Path(__file__).resolve()
    # <repo>/quickshell/scripts/this.py → <repo>/theme-engine
    # Also try parents[3] in case of unexpected nesting.
    for parent in here.parents[2:5]:
        candidate = parent / "theme-engine"
        if (candidate / "yahr_theme").is_dir():
            return candidate

    share = HOME / ".local/share/yahr-shell/theme-engine"
    if (share / "yahr_theme").is_dir():
        return share
    return None


def load_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError, TypeError):
        return {}


def patch_existing_conf(conf: Path, ui_font: str) -> bool:
    """Update $ui / $uiBold in an existing hyprlock.conf without regenerating.

    Used when theme-engine is missing or too old to accept ui_font=.
    """
    if not conf.is_file():
        return False
    try:
        text = conf.read_text()
    except OSError:
        return False
    if not re.search(r"(?m)^\$ui\s*=", text):
        return False

    font = (ui_font or "Inter").strip() or "Inter"
    text = re.sub(r"(?m)^\$ui\s*=\s*.*$", f"$ui = {font}", text, count=1)
    if re.search(r"(?m)^\$uiBold\s*=", text):
        text = re.sub(r"(?m)^\$uiBold\s*=\s*.*$", f"$uiBold = {font}", text, count=1)
    else:
        text = re.sub(r"(?m)^(\$ui\s*=\s*.*)$", rf"\1\n$uiBold = {font}", text, count=1)
    # Leftover hardcoded Inter ExtraBold from older generators.
    text = text.replace("font_family = Inter ExtraBold", "font_family = $uiBold")
    conf.write_text(text)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ui-font",
        default="",
        help="Resolved UI font family (skips reading settings.json when set)",
    )
    args = parser.parse_args()

    engine = find_theme_engine()
    conf_fallback = HOME / ".config/hypr/hyprlock.conf"
    settings = load_json(HOME / ".config/yahr/settings.json")

    if engine is not None:
        sys.path.insert(0, str(engine))
        try:
            from yahr_theme import apply, paths, templates  # noqa: WPS433
        except ImportError as exc:
            print(f"theme-engine import failed: {exc}", file=sys.stderr)
            ui_font = (args.ui_font or "").strip() or str(
                (settings.get("general") or {}).get("uiFont") or "Inter"
            )
            if patch_existing_conf(conf_fallback, ui_font):
                print(f"patched {conf_fallback} ui_font={ui_font} (import fallback)")
                return 0
            return 1

        palette_path = paths.current_json()
        if not palette_path.is_file():
            print(f"missing palette: {palette_path}", file=sys.stderr)
            return 1
        palette = load_json(palette_path)
        if not palette:
            print(f"failed to read palette: {palette_path}", file=sys.stderr)
            return 1

        ui_font = (args.ui_font or "").strip()
        if not ui_font:
            ui_font = apply.resolve_ui_font(settings)

        conf = paths.hyprlock_conf()
        try:
            conf.parent.mkdir(parents=True, exist_ok=True)
            conf.write_text(templates.hyprlock_conf(palette, ui_font=ui_font))
        except TypeError:
            # Stale share package without ui_font= — patch in place.
            if patch_existing_conf(conf, ui_font):
                print(f"patched {conf} ui_font={ui_font} (stale template)")
                return 0
            raise
        print(f"wrote {conf} ui_font={ui_font}")
        return 0

    ui_font = (args.ui_font or "").strip() or str(
        (settings.get("general") or {}).get("uiFont") or "Inter"
    )
    if patch_existing_conf(conf_fallback, ui_font):
        print(f"patched {conf_fallback} ui_font={ui_font} (no theme-engine)")
        return 0
    print("theme-engine not found and no patchable hyprlock.conf", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Rewrite ~/.config/hypr/hyprlock.conf from the current palette and Settings UI font.

Prefers ``yahr-theme sync-hyprlock`` (installed CLI / theme-engine package) so a
missing or stale repo-root checkout still works. Falls back to importing
theme-engine directly, then to an in-place $ui patch.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
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
    text = text.replace("font_family = Inter ExtraBold", "font_family = $uiBold")
    conf.write_text(text)
    return True


def try_yahr_theme_cli(ui_font: str) -> int | None:
    """Run installed yahr-theme sync-hyprlock when the subcommand exists."""
    bin_path = shutil.which("yahr-theme")
    if not bin_path:
        local = HOME / ".local/bin/yahr-theme"
        bin_path = str(local) if local.is_file() else ""
    if not bin_path:
        return None
    cmd = [bin_path, "sync-hyprlock"]
    if ui_font:
        cmd.extend(["--ui-font", ui_font])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except OSError:
        return None
    # Old CLIs without the subcommand exit 2 from argparse.
    if result.returncode == 0:
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        return 0
    err = (result.stderr or "") + (result.stdout or "")
    if "invalid choice" in err or "unrecognized arguments" in err or "invalid command" in err:
        return None
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ui-font",
        default="",
        help="Resolved UI font family (skips reading settings.json when set)",
    )
    args = parser.parse_args()
    ui_font = (args.ui_font or "").strip()
    settings = load_json(HOME / ".config/yahr/settings.json")
    if not ui_font:
        ui_font = str((settings.get("general") or {}).get("uiFont") or "Inter")

    cli_rc = try_yahr_theme_cli(ui_font)
    if cli_rc is not None:
        return cli_rc

    engine = find_theme_engine()
    conf_fallback = HOME / ".config/hypr/hyprlock.conf"

    if engine is not None:
        sys.path.insert(0, str(engine))
        try:
            from yahr_theme import apply  # noqa: WPS433
        except ImportError as exc:
            print(f"theme-engine import failed: {exc}", file=sys.stderr)
            if patch_existing_conf(conf_fallback, ui_font):
                print(f"patched {conf_fallback} ui_font={ui_font} (import fallback)")
                return 0
            return 1
        try:
            conf, font, mode = apply.sync_hyprlock_conf(ui_font)
            print(f"{mode} {conf} ui_font={font}")
            return 0
        except FileNotFoundError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        except TypeError:
            if patch_existing_conf(conf_fallback, ui_font):
                print(f"patched {conf_fallback} ui_font={ui_font} (stale apply)")
                return 0
            raise

    if patch_existing_conf(conf_fallback, ui_font):
        print(f"patched {conf_fallback} ui_font={ui_font} (no theme-engine)")
        return 0
    print("theme-engine not found and no patchable hyprlock.conf", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

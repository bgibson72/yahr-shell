#!/usr/bin/env python3
"""Force ~/.config/quickshell to track the git checkout in repo-root.

Settings QML (including SDDM blur/opacity controls) is loaded from
Quickshell.shellDir. If that tree is a stale copy of the clone, Settings keeps
showing removed controls after git pull. This script replaces the live tree
with a symlink to <repo>/quickshell whenever possible, otherwise copies the
critical Settings files from the clone.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))
LIVE = HOME / ".config/quickshell"
REPO_ROOT_FILE = HOME / ".config/yahr/repo-root"
STALE_MARKERS = (
    "Blur background",
    "Login Window Transparency",
    "Apply writes colors, wallpaper, blur, and opacity",
)
CRITICAL_REL_PATHS = (
    "modules/settings/SettingsPanel.qml",
    "Settings.qml",
    "scripts/sddm-apply.py",
    "scripts/set-wallpaper.py",
    "scripts/sddm-apply-cli",
    "scripts/set-wallpaper-cli",
    "scripts/sync-quickshell-from-repo.py",
)


def resolve_repo_root(explicit: str | None = None) -> Path | None:
    if explicit:
        path = Path(os.path.expanduser(explicit)).resolve()
        if (path / "quickshell" / "shell.qml").is_file():
            return path
        return None
    if REPO_ROOT_FILE.is_file():
        try:
            path = Path(REPO_ROOT_FILE.read_text().strip()).expanduser().resolve()
        except OSError:
            path = None
        if path and (path / "quickshell" / "shell.qml").is_file():
            return path
    # Walk up from this script: .../quickshell/scripts/this.py → repo root
    here = Path(__file__).resolve()
    candidate = here.parents[2]
    if (candidate / "quickshell" / "shell.qml").is_file():
        return candidate
    return None


def panel_text(root: Path) -> str:
    panel = root / "modules/settings/SettingsPanel.qml"
    try:
        return panel.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def is_stale(root: Path) -> bool:
    text = panel_text(root)
    if not text:
        return True
    return any(marker in text for marker in STALE_MARKERS)


def same_tree(a: Path, b: Path) -> bool:
    try:
        return a.resolve() == b.resolve()
    except OSError:
        return False


def write_repo_root(repo: Path) -> None:
    REPO_ROOT_FILE.parent.mkdir(parents=True, exist_ok=True)
    REPO_ROOT_FILE.write_text(str(repo) + "\n")


def force_symlink(repo_qs: Path) -> str:
    LIVE.parent.mkdir(parents=True, exist_ok=True)
    if LIVE.is_symlink() or LIVE.exists():
        if LIVE.is_symlink() or LIVE.is_file():
            LIVE.unlink()
        else:
            shutil.rmtree(LIVE)
    os.symlink(str(repo_qs), str(LIVE), target_is_directory=True)
    return "RELINKED_SYMLINK"


def copy_critical(repo_qs: Path) -> str:
    LIVE.mkdir(parents=True, exist_ok=True)
    copied = 0
    for rel in CRITICAL_REL_PATHS:
        src = repo_qs / rel
        dest = LIVE / rel
        if not src.is_file():
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        if rel.startswith("scripts/"):
            try:
                os.chmod(dest, 0o755)
            except OSError:
                pass
        copied += 1
    return f"COPIED_CRITICAL count={copied}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync live Quickshell config from the yahr-shell git checkout")
    parser.add_argument("--repo", default="", help="Override path to the yahr-shell clone")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Report status only; do not modify ~/.config/quickshell",
    )
    parser.add_argument(
        "--copy-only",
        action="store_true",
        help="Never symlink; copy critical Settings/SDDM files into the live tree",
    )
    args = parser.parse_args()

    repo = resolve_repo_root(args.repo or None)
    if repo is None:
        print("MISSING_REPO_ROOT")
        print(f"expected_file={REPO_ROOT_FILE}")
        return 2

    repo_qs = repo / "quickshell"
    write_repo_root(repo)

    live_exists = LIVE.exists() or LIVE.is_symlink()
    linked = live_exists and same_tree(LIVE, repo_qs)
    live_stale = is_stale(LIVE) if live_exists else True
    repo_stale = is_stale(repo_qs)

    print(f"repo={repo}")
    print(f"live={LIVE}")
    print(f"live_is_symlink={LIVE.is_symlink()}")
    print(f"live_tracks_repo={linked}")
    print(f"live_stale={live_stale}")
    print(f"repo_stale={repo_stale}")

    if repo_stale:
        print("REPO_STALE")
        print("Pull latest main into the clone, then re-run this script.")
        return 3

    if args.check:
        if linked and not live_stale:
            print("OK")
            return 0
        if live_stale:
            print("STALE_LIVE")
            return 1
        print("NOT_LINKED")
        return 1

    if linked and not live_stale:
        print("OK")
        return 0

    if args.copy_only:
        print(copy_critical(repo_qs))
        print("OK_NEED_RESTART" if is_stale(LIVE) is False else "FAIL")
        return 0 if not is_stale(LIVE) else 1

    try:
        print(force_symlink(repo_qs))
    except OSError as exc:
        print(f"symlink_failed={exc}")
        print(copy_critical(repo_qs))

    if is_stale(LIVE):
        print("FAIL")
        return 1
    print("OK_NEED_RESTART")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

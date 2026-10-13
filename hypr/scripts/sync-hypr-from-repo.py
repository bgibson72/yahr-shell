#!/usr/bin/env python3
"""Keep ~/.config/hypr tracking the git checkout in repo-root.

install.sh prefers a symlink from ~/.config/hypr → <repo>/hypr so `git pull`
is live. When that falls back to a copy (or the tree is recreated as a real
directory), pulled window rules never reach Hyprland — e.g. Thunar rename
float fixes stay tiled until the stale copy is refreshed.

Prefer re-symlinking the live tree to the clone (preserving theme.lua and
nvidia.lua). Fall back to copying tracked config files into the live tree.

Exit codes:
  0  already in sync
  10 files updated (caller should `hyprctl reload`)
  2  missing repo-root / hypr tree
  1  failed
"""

from __future__ import annotations

import argparse
import filecmp
import os
import shutil
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))
LIVE = HOME / ".config/hypr"
REPO_ROOT_FILE = HOME / ".config/yahr/repo-root"

# Written by yahr-theme apply / the installer; never overwrite from the clone
# when copying into a live directory tree.
LOCAL_ONLY = frozenset({"theme.lua", "nvidia.lua"})

SKIP_DIR_NAMES = frozenset({"__pycache__", ".git"})


def resolve_repo_root(explicit: str | None = None) -> Path | None:
    if explicit:
        path = Path(os.path.expanduser(explicit)).resolve()
        if (path / "hypr" / "hyprland.lua").is_file():
            return path
        return None
    if REPO_ROOT_FILE.is_file():
        try:
            path = Path(REPO_ROOT_FILE.read_text().strip()).expanduser().resolve()
        except OSError:
            path = None
        if path and (path / "hypr" / "hyprland.lua").is_file():
            return path
    # .../hypr/scripts/this.py → repo root
    here = Path(__file__).resolve()
    candidate = here.parents[2]
    if (candidate / "hypr" / "hyprland.lua").is_file():
        return candidate
    return None


def write_repo_root(repo: Path) -> None:
    REPO_ROOT_FILE.parent.mkdir(parents=True, exist_ok=True)
    REPO_ROOT_FILE.write_text(str(repo) + "\n")


def same_tree(a: Path, b: Path) -> bool:
    try:
        return a.resolve() == b.resolve()
    except OSError:
        return False


def iter_repo_files(repo_hypr: Path) -> list[Path]:
    files: list[Path] = []
    for path in sorted(repo_hypr.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(repo_hypr)
        if any(part in SKIP_DIR_NAMES for part in rel.parts):
            continue
        if rel.name in LOCAL_ONLY:
            continue
        if rel.suffix == ".pyc":
            continue
        files.append(rel)
    return files


def live_matches_repo(live: Path, repo_hypr: Path) -> bool:
    if not live.exists() and not live.is_symlink():
        return False
    if live.is_symlink() and same_tree(live, repo_hypr):
        return True
    for rel in iter_repo_files(repo_hypr):
        src = repo_hypr / rel
        dest = live / rel
        if not dest.is_file():
            return False
        if not filecmp.cmp(src, dest, shallow=False):
            return False
    return True


def preserve_local_files(live: Path) -> dict[str, bytes]:
    saved: dict[str, bytes] = {}
    if not live.exists() and not live.is_symlink():
        return saved
    # When live is already a symlink into the repo, locals already live there.
    if live.is_symlink() and same_tree(live, live.resolve()):
        pass
    for name in LOCAL_ONLY:
        path = live / name
        if path.is_file() and not path.is_symlink():
            try:
                saved[name] = path.read_bytes()
            except OSError:
                pass
        elif path.is_file():
            try:
                saved[name] = path.read_bytes()
            except OSError:
                pass
    return saved


def restore_local_files(target: Path, saved: dict[str, bytes]) -> None:
    for name, data in saved.items():
        dest = target / name
        try:
            if dest.is_file() and dest.read_bytes() == data:
                continue
            dest.write_bytes(data)
            print(f"restored_local={name}")
        except OSError as exc:
            print(f"restore_failed={name}:{exc}")


def force_symlink(repo_hypr: Path) -> str:
    """Replace the live tree with a symlink; keep theme.lua / nvidia.lua."""
    LIVE.parent.mkdir(parents=True, exist_ok=True)
    repo_hypr = repo_hypr.resolve()
    saved = preserve_local_files(LIVE)
    backup = LIVE.parent / f"hypr.stale.{os.getpid()}"

    if LIVE.is_symlink():
        LIVE.unlink()
    elif LIVE.exists():
        if backup.exists():
            if backup.is_symlink() or backup.is_file():
                backup.unlink()
            else:
                shutil.rmtree(backup)
        LIVE.rename(backup)

    os.symlink(str(repo_hypr), str(LIVE), target_is_directory=True)
    restore_local_files(repo_hypr, saved)

    if backup.exists():
        try:
            if backup.is_symlink() or backup.is_file():
                backup.unlink()
            else:
                shutil.rmtree(backup)
        except OSError as exc:
            print(f"stale_cleanup_failed={exc}")
            print(f"stale_left={backup}")
    return "RELINKED_SYMLINK"


def copy_tracked(repo_hypr: Path) -> str:
    """Copy clone files into a real ~/.config/hypr directory (no symlink)."""
    LIVE.mkdir(parents=True, exist_ok=True)
    copied = 0
    for rel in iter_repo_files(repo_hypr):
        src = repo_hypr / rel
        dest = LIVE / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.is_file() and filecmp.cmp(src, dest, shallow=False):
            continue
        shutil.copy2(src, dest)
        if rel.parts and rel.parts[0] == "scripts":
            try:
                os.chmod(dest, 0o755)
            except OSError:
                pass
        copied += 1
        print(f"copied={rel}")
    return f"COPIED_TRACKED count={copied}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync live Hyprland config from the yahr-shell git checkout"
    )
    parser.add_argument("--repo", default="", help="Override path to the yahr-shell clone")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Report status only; do not modify ~/.config/hypr",
    )
    parser.add_argument(
        "--copy-only",
        action="store_true",
        help="Never symlink; copy tracked files into the live tree",
    )
    args = parser.parse_args()

    repo = resolve_repo_root(args.repo or None)
    if repo is None:
        print("MISSING_REPO_ROOT")
        print(f"expected_file={REPO_ROOT_FILE}")
        return 2

    repo_hypr = (repo / "hypr").resolve()
    write_repo_root(repo)

    live_exists = LIVE.exists() or LIVE.is_symlink()
    linked = live_exists and same_tree(LIVE, repo_hypr)
    matched = live_matches_repo(LIVE, repo_hypr) if live_exists else False

    print(f"repo={repo}")
    print(f"live={LIVE}")
    print(f"live_is_symlink={LIVE.is_symlink()}")
    print(f"live_tracks_repo={linked}")
    print(f"live_matches_repo={matched}")

    if args.check:
        if matched:
            print("OK")
            return 0
        print("STALE_LIVE" if live_exists else "MISSING_LIVE")
        return 1

    if matched and linked:
        print("OK")
        return 0

    if matched and not linked:
        # Content matches but not symlinked — still OK for Hyprland; optionally
        # upgrade to a symlink unless --copy-only.
        if args.copy_only:
            print("OK")
            return 0

    if args.copy_only:
        before = matched
        print(copy_tracked(repo_hypr))
        after = live_matches_repo(LIVE, repo_hypr)
        if not after:
            print("FAIL")
            return 1
        if before:
            print("OK")
            return 0
        print("UPDATED")
        return 10

    try:
        print(force_symlink(repo_hypr))
    except OSError as exc:
        print(f"symlink_failed={exc}")
        before = live_matches_repo(LIVE, repo_hypr)
        print(copy_tracked(repo_hypr))
        after = live_matches_repo(LIVE, repo_hypr)
        if not after:
            print("FAIL")
            return 1
        print("UPDATED" if not before else "OK")
        return 10 if not before else 0

    if not live_matches_repo(LIVE, repo_hypr):
        print("FAIL")
        return 1
    print("UPDATED")
    return 10


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Force ~/.config/quickshell to track the git checkout in repo-root.

Settings QML (including SDDM blur/opacity controls) is loaded from
Quickshell.shellDir. If that tree is a stale copy of the clone, Settings keeps
showing removed controls after git pull. This script replaces the live tree
with a symlink to <repo>/quickshell whenever possible, otherwise copies the
critical Settings files from the clone.

Relinking while Quickshell is running makes qmlscanner reload mid-swap and can
fail with errors like "WallpaperSlideshow is not a type". By default this
script stops qs/quickshell before replacing the live tree.
"""

from __future__ import annotations

import argparse
import os
import shutil
import signal
import subprocess
import sys
import time
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
    "modules/wallpaper/qmldir",
    "modules/wallpaper/WallpaperSlideshow.qml",
    "modules/wallpaper/WallpaperPicker.qml",
    "Settings.qml",
    "scripts/sddm-apply.py",
    "scripts/set-wallpaper.py",
    "scripts/sddm-apply-cli",
    "scripts/set-wallpaper-cli",
    "scripts/sync-quickshell-from-repo.py",
    "scripts/sync-quickshell-cli",
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


def quickshell_pids() -> list[int]:
    pids: list[int] = []
    for name in ("qs", "quickshell"):
        result = subprocess.run(
            ["pgrep", "-x", name],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            continue
        for line in result.stdout.splitlines():
            line = line.strip()
            if line.isdigit():
                pids.append(int(line))
    return sorted(set(pids))


def stop_quickshell() -> list[int]:
    pids = quickshell_pids()
    if not pids:
        print("quickshell_running=false")
        return []
    print(f"quickshell_running=true pids={','.join(str(p) for p in pids)}")
    for pid in pids:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.time() + 5.0
    while time.time() < deadline:
        remaining = [pid for pid in pids if Path(f"/proc/{pid}").exists()]
        if not remaining:
            break
        time.sleep(0.1)
    for pid in pids:
        if Path(f"/proc/{pid}").exists():
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    print("quickshell_stopped=true")
    return pids


def start_quickshell(repo_qs: Path) -> None:
    target = str(LIVE if (LIVE.exists() or LIVE.is_symlink()) else repo_qs)
    # Prefer the real path so qs does not depend on a half-written symlink.
    try:
        target = str(Path(target).resolve())
    except OSError:
        pass
    cmd = ["qs", "-p", target]
    if shutil.which("qs") is None:
        cmd = ["quickshell", "-p", target] if shutil.which("quickshell") else None
    if cmd is None:
        print("start_failed=missing_qs_binary")
        return
    subprocess.Popen(
        cmd,
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    print(f"started={' '.join(cmd)}")


def force_symlink(repo_qs: Path) -> str:
    """Replace the live tree with a symlink, using rename-aside to avoid an empty gap."""
    LIVE.parent.mkdir(parents=True, exist_ok=True)
    repo_qs = repo_qs.resolve()
    backup = LIVE.parent / f"quickshell.stale.{os.getpid()}"

    if LIVE.is_symlink():
        LIVE.unlink()
    elif LIVE.exists():
        if backup.exists():
            if backup.is_symlink() or backup.is_file():
                backup.unlink()
            else:
                shutil.rmtree(backup)
        LIVE.rename(backup)

    os.symlink(str(repo_qs), str(LIVE), target_is_directory=True)

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


def verify_wallpaper_types(root: Path) -> bool:
    slideshow = root / "modules/wallpaper/WallpaperSlideshow.qml"
    picker = root / "modules/wallpaper/WallpaperPicker.qml"
    qmldir = root / "modules/wallpaper/qmldir"
    ok = slideshow.is_file() and picker.is_file() and qmldir.is_file()
    print(f"wallpaper_slideshow={slideshow.is_file()}")
    print(f"wallpaper_picker={picker.is_file()}")
    print(f"wallpaper_qmldir={qmldir.is_file()}")
    return ok


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
    parser.add_argument(
        "--keep-running",
        action="store_true",
        help="Do not stop Quickshell before replacing the live tree (unsafe)",
    )
    parser.add_argument(
        "--restart",
        action="store_true",
        help="Start qs -p ~/.config/quickshell after a successful sync",
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
    verify_wallpaper_types(repo_qs)

    if repo_stale:
        print("REPO_STALE")
        print("Pull latest main into the clone, then re-run this script.")
        return 3

    if args.check:
        if linked and not live_stale and verify_wallpaper_types(LIVE if live_exists else repo_qs):
            print("OK")
            return 0
        if live_stale:
            print("STALE_LIVE")
            return 1
        print("NOT_LINKED")
        return 1

    if linked and not live_stale:
        print("OK")
        if args.restart and not quickshell_pids():
            start_quickshell(repo_qs)
        return 0

    will_replace = not args.copy_only
    if will_replace and not args.keep_running:
        stop_quickshell()
    elif will_replace and quickshell_pids():
        print("WARN=quickshell_still_running_relink_may_race")

    if args.copy_only:
        print(copy_critical(repo_qs))
        ok = not is_stale(LIVE) and verify_wallpaper_types(LIVE)
        print("OK_NEED_RESTART" if ok else "FAIL")
        if ok and args.restart:
            stop_quickshell()
            start_quickshell(repo_qs)
        return 0 if ok else 1

    try:
        print(force_symlink(repo_qs))
    except OSError as exc:
        print(f"symlink_failed={exc}")
        print(copy_critical(repo_qs))

    ok = not is_stale(LIVE) and verify_wallpaper_types(LIVE)
    if not ok:
        print("FAIL")
        return 1
    print("OK_NEED_RESTART")
    if args.restart:
        start_quickshell(repo_qs)
        print("OK_RESTARTED")
    else:
        print("restart_hint=qs -p ~/.config/quickshell")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

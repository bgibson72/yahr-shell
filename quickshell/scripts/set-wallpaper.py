#!/usr/bin/env python3
"""Apply a wallpaper with awww (preferred) or swww.

Starts the matching daemon if it isn't running, then sets IMAGE using
TRANSITION (awww/swww --transition-type values). Also writes
~/.config/yahr/last-wallpaper so the image is restored on login.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


def pick_tool() -> tuple[str, str]:
    if shutil.which("awww"):
        return "awww", "awww-daemon"
    if shutil.which("swww"):
        return "swww", "swww-daemon"
    raise FileNotFoundError("neither awww nor swww is installed")


def daemon_running(name: str) -> bool:
    return subprocess.run(
        ["pgrep", "-x", name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0


def ensure_daemon(name: str) -> None:
    if daemon_running(name):
        return
    subprocess.Popen(
        [name],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(25):
        time.sleep(0.1)
        if daemon_running(name):
            time.sleep(0.2)
            return
    time.sleep(0.5)


def remember(image: str) -> None:
    """Record the chosen image even when no compositor is running yet."""
    last = Path.home() / ".config/yahr/last-wallpaper"
    last.parent.mkdir(parents=True, exist_ok=True)
    last.write_text(image + "\n")


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: set-wallpaper.py <image> [transition]", file=sys.stderr)
        return 1

    image = os.path.expanduser(sys.argv[1])
    if not os.path.isfile(image):
        print(f"error: not a file: {image}", file=sys.stderr)
        return 1

    transition = sys.argv[2] if len(sys.argv) > 2 else "fade"
    remember(image)
    # The installer applies a theme before the first login. Keep the path
    # so Hyprland can restore it, and skip the daemon until a session exists.
    if not os.environ.get("WAYLAND_DISPLAY"):
        return 0

    try:
        cmd, daemon = pick_tool()
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    ensure_daemon(daemon)

    argv = [
        cmd, "img", image,
        "--transition-type", transition,
        "--transition-duration", "2",
        "--transition-fps", "60",
    ]
    if transition == "grow":
        argv += ["--transition-pos", "center"]

    result = subprocess.run(argv, check=False)
    if result.returncode != 0:
        return result.returncode

    maybe_sync_sddm(image)
    return 0


def find_sddm_apply() -> Path | None:
    """Prefer the git-clone apply script when ~/.config/yahr/repo-root is set.

    install.sh copies Quickshell into ~/.config/quickshell, so the in-tree
    script next to this file can lag behind the checkout the user pulls.
    """
    candidates: list[Path] = []
    repo_root_file = Path.home() / ".config/yahr/repo-root"
    if repo_root_file.is_file():
        try:
            root = Path(repo_root_file.read_text().strip()).expanduser()
            candidates.append(root / "quickshell" / "scripts" / "sddm-apply.py")
        except OSError:
            pass
    candidates.append(Path(__file__).resolve().with_name("sddm-apply.py"))
    share = Path.home() / ".local/share/yahr-shell/quickshell/scripts/sddm-apply.py"
    candidates.append(share)
    for path in candidates:
        if path.is_file():
            return path
    return None


def maybe_sync_sddm(image: str) -> None:
    settings_path = Path.home() / ".config/yahr/settings.json"
    try:
        data = json.loads(settings_path.read_text())
    except (OSError, json.JSONDecodeError):
        return
    sddm = data.get("sddm") or {}
    if not sddm.get("followDesktop", True):
        return
    script = find_sddm_apply()
    if script is None:
        return
    blur = 0 if not sddm.get("blurEnabled", True) else int(sddm.get("blurAmount", 20) or 0)
    opacity = sddm.get("loginOpacity", 0.75)
    log_path = Path.home() / ".cache/yahr/sddm-sync.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [
            sys.executable,
            str(script),
            "--opacity",
            f"{float(opacity):.2f}",
            "--blur",
            str(blur),
            "--wallpaper",
            image,
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    try:
        log_path.write_text(
            f"script={script}\n"
            f"wallpaper={image}\n"
            f"exit={result.returncode}\n"
            f"{result.stdout}"
            f"{result.stderr}"
        )
    except OSError:
        pass


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Apply a wallpaper with awww (preferred) or swww.

Starts the matching daemon if it isn't running, then sets IMAGE using
TRANSITION (awww/swww --transition-type values). Also writes
~/.config/yahr/last-wallpaper so the image is restored on login, and syncs
the SDDM greeter wallpaper when Settings → SDDM → Match desktop is on.
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


def publish_live_scripts() -> None:
    """Refresh ~/.config/quickshell/scripts when it is a separate install copy."""
    live = Path.home() / ".config/quickshell/scripts"
    if not live.is_dir():
        return
    here = Path(__file__).resolve().parent
    try:
        if live.resolve() == here.resolve():
            return
    except OSError:
        return
    for name in ("sddm-apply.py", "set-wallpaper.py", "sddm-apply-cli", "set-wallpaper-cli"):
        src = here / name
        if not src.is_file():
            continue
        try:
            shutil.copy2(src, live / name)
            os.chmod(live / name, 0o755)
        except OSError:
            pass


def find_sddm_apply() -> Path | None:
    """Prefer the git-clone apply script when ~/.config/yahr/repo-root is set."""
    candidates: list[Path] = []
    repo_root_file = Path.home() / ".config/yahr/repo-root"
    if repo_root_file.is_file():
        try:
            root = Path(repo_root_file.read_text().strip()).expanduser()
            candidates.append(root / "quickshell" / "scripts" / "sddm-apply.py")
        except OSError:
            pass
    candidates.append(Path(__file__).resolve().with_name("sddm-apply.py"))
    candidates.append(Path.home() / ".local/share/yahr-shell/quickshell/scripts/sddm-apply.py")
    for path in candidates:
        if path.is_file():
            return path
    return None


def log_sync(message: str) -> None:
    log_path = Path.home() / ".cache/yahr/sddm-sync.log"
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(message if message.endswith("\n") else message + "\n")
    except OSError:
        pass


def maybe_sync_sddm(image: str) -> None:
    settings_path = Path.home() / ".config/yahr/settings.json"
    try:
        data = json.loads(settings_path.read_text())
    except (OSError, json.JSONDecodeError):
        data = {}
    sddm = data.get("sddm") or {}
    if not sddm.get("followDesktop", True):
        log_sync(f"skip=followDesktop_false\nwallpaper={image}\n")
        return
    script = find_sddm_apply()
    if script is None:
        log_sync(f"skip=missing_sddm_apply\nwallpaper={image}\n")
        return
    blur = 0 if not sddm.get("blurEnabled", True) else int(sddm.get("blurAmount", 20) or 0)
    opacity = sddm.get("loginOpacity", 0.75)
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
    log_sync(
        f"script={script}\n"
        f"wallpaper={image}\n"
        f"exit={result.returncode}\n"
        f"{result.stdout}"
        f"{result.stderr}"
    )


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
    publish_live_scripts()
    # Sync greeter as soon as the path is known — do not wait on awww/swww.
    maybe_sync_sddm(image)

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
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())

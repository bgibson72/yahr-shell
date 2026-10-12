#!/usr/bin/env python3
"""Keep the installed yahr-theme CLI pointed at the git checkout.

install.sh copies theme-engine into ~/.local/share/yahr-shell and wraps
~/.local/bin/yahr-theme against that share tree. After `git pull`, that copy
goes stale — Firefox userChrome and other templates keep shipping old CSS
until the next full reinstall. Mirror the quickshell sync: prefer the clone
recorded in ~/.config/yahr/repo-root, refresh the share copy, and rewrite the
wrapper so apply picks up pulled fixes.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))
REPO_ROOT_FILE = HOME / ".config/yahr/repo-root"
SHARE_ENGINE = HOME / ".local/share/yahr-shell" / "theme-engine"
INSTALLED_BIN = HOME / ".local/bin" / "yahr-theme"

WRAPPER = """#!/usr/bin/env python3
import sys
from pathlib import Path

home = Path.home()
candidates = []
repo_root_file = home / ".config/yahr/repo-root"
if repo_root_file.is_file():
    try:
        root = Path(repo_root_file.read_text().strip()).expanduser()
        candidates.append(root / "theme-engine")
    except OSError:
        pass
candidates.append(home / ".local/share/yahr-shell" / "theme-engine")

for path in candidates:
    if (path / "yahr_theme").is_dir():
        sys.path.insert(0, str(path))
        break

from yahr_theme.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
"""


def resolve_repo_root(explicit: str | None = None) -> Path | None:
    if explicit:
        path = Path(os.path.expanduser(explicit)).resolve()
        if (path / "theme-engine" / "yahr_theme").is_dir():
            return path
        return None
    if REPO_ROOT_FILE.is_file():
        try:
            path = Path(REPO_ROOT_FILE.read_text().strip()).expanduser().resolve()
        except OSError:
            path = None
        if path and (path / "theme-engine" / "yahr_theme").is_dir():
            return path
    here = Path(__file__).resolve()
    # .../theme-engine/sync-theme-engine-from-repo.py → repo root
    candidate = here.parents[1]
    if (candidate / "theme-engine" / "yahr_theme").is_dir():
        return candidate
    return None


def sync_share_copy(repo: Path) -> None:
    src = repo / "theme-engine" / "yahr_theme"
    dest = SHARE_ENGINE / "yahr_theme"
    SHARE_ENGINE.mkdir(parents=True, exist_ok=True)
    if dest.exists() or dest.is_symlink():
        if dest.is_symlink() or dest.is_file():
            dest.unlink()
        else:
            shutil.rmtree(dest)
    shutil.copytree(src, dest, symlinks=True)
    # Keep a runnable entrypoint next to the package for python -m / direct exec.
    entry = repo / "theme-engine" / "yahr-theme"
    if entry.is_file():
        target = SHARE_ENGINE / "yahr-theme"
        shutil.copy2(entry, target)
        target.chmod(0o755)


def write_wrapper() -> None:
    INSTALLED_BIN.parent.mkdir(parents=True, exist_ok=True)
    INSTALLED_BIN.write_text(WRAPPER)
    INSTALLED_BIN.chmod(0o755)


def write_repo_root(repo: Path) -> None:
    REPO_ROOT_FILE.parent.mkdir(parents=True, exist_ok=True)
    REPO_ROOT_FILE.write_text(str(repo) + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", help="yahr-shell checkout root")
    parser.add_argument(
        "--no-wrapper",
        action="store_true",
        help="only refresh the share copy; leave ~/.local/bin/yahr-theme alone",
    )
    args = parser.parse_args(argv)

    repo = resolve_repo_root(args.repo)
    if repo is None:
        print("theme-engine sync: no yahr-shell checkout found", file=sys.stderr)
        return 1

    write_repo_root(repo)
    sync_share_copy(repo)
    if not args.no_wrapper:
        write_wrapper()
    print(f"theme-engine sync: {repo / 'theme-engine'} → {SHARE_ENGINE}")
    if not args.no_wrapper:
        print(f"theme-engine sync: wrote {INSTALLED_BIN} (prefers repo-root)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

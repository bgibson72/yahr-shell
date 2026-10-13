#!/usr/bin/env python3
"""Tests for hypr/scripts/sync-hypr-from-repo.py."""

from __future__ import annotations

import os
import shutil
import tempfile
import unittest
from pathlib import Path

import importlib.util


def _load_sync_module():
    path = Path(__file__).with_name("scripts") / "sync-hypr-from-repo.py"
    spec = importlib.util.spec_from_file_location("sync_hypr_from_repo", path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


sync = _load_sync_module()


class SyncHyprFromRepoTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="yahr-hypr-sync-"))
        self.home = self.tmp / "home"
        self.repo = self.tmp / "yahr-shell"
        self.live = self.home / ".config" / "hypr"
        self.repo_hypr = self.repo / "hypr"
        self.repo_hypr.mkdir(parents=True)
        self.home.mkdir(parents=True)
        (self.repo_hypr / "hyprland.lua").write_text("-- hyprland\n")
        (self.repo_hypr / "rules.lua").write_text(
            'local thunar_class = "^([Tt]hunar|org\\\\.xfce\\\\.[Tt]hunar)$"\n'
        )
        (self.repo_hypr / "theme.lua").write_text("-- repo theme sample\n")
        (self.home / ".config" / "yahr").mkdir(parents=True)
        (self.home / ".config" / "yahr" / "repo-root").write_text(str(self.repo) + "\n")

        sync.HOME = self.home
        sync.LIVE = self.live
        sync.REPO_ROOT_FILE = self.home / ".config" / "yahr" / "repo-root"

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_detects_stale_copy(self) -> None:
        self.live.mkdir(parents=True)
        shutil.copy2(self.repo_hypr / "hyprland.lua", self.live / "hyprland.lua")
        (self.live / "rules.lua").write_text(
            'local thunar_class = "^(thunar|org\\\\.xfce\\\\.thunar)$"\n'
        )
        (self.live / "theme.lua").write_text("-- live theme\n")
        self.assertFalse(sync.live_matches_repo(self.live, self.repo_hypr))

    def test_copy_only_updates_rules_preserves_theme(self) -> None:
        self.live.mkdir(parents=True)
        shutil.copy2(self.repo_hypr / "hyprland.lua", self.live / "hyprland.lua")
        (self.live / "rules.lua").write_text("stale\n")
        (self.live / "theme.lua").write_text("-- keep me\n")
        (self.live / "nvidia.lua").write_text("-- nvidia\n")

        os.environ["HOME"] = str(self.home)
        result = sync.copy_tracked(self.repo_hypr)
        self.assertIn("COPIED_TRACKED", result)
        self.assertEqual(
            (self.live / "rules.lua").read_text(),
            (self.repo_hypr / "rules.lua").read_text(),
        )
        self.assertEqual((self.live / "theme.lua").read_text(), "-- keep me\n")
        self.assertEqual((self.live / "nvidia.lua").read_text(), "-- nvidia\n")
        self.assertTrue(sync.live_matches_repo(self.live, self.repo_hypr))

    def test_force_symlink_preserves_locals(self) -> None:
        self.live.mkdir(parents=True)
        (self.live / "hyprland.lua").write_text("stale hyprland\n")
        (self.live / "rules.lua").write_text("stale rules\n")
        (self.live / "theme.lua").write_text("-- live theme keep\n")
        (self.live / "nvidia.lua").write_text("-- nvidia keep\n")

        msg = sync.force_symlink(self.repo_hypr)
        self.assertEqual(msg, "RELINKED_SYMLINK")
        self.assertTrue(self.live.is_symlink())
        self.assertTrue(sync.same_tree(self.live, self.repo_hypr))
        self.assertEqual((self.live / "theme.lua").read_text(), "-- live theme keep\n")
        self.assertEqual((self.live / "nvidia.lua").read_text(), "-- nvidia keep\n")
        self.assertIn("[Tt]hunar", (self.live / "rules.lua").read_text())


if __name__ == "__main__":
    unittest.main()

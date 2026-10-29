#!/usr/bin/env python3
"""Checks for Network panel settings launch + Wi-Fi AP connect wiring."""

import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PANEL = ROOT / "quickshell" / "modules" / "network" / "NetworkPanel.qml"
CONNECT = ROOT / "quickshell" / "scripts" / "wifi-connect.sh"
SETTINGS = ROOT / "quickshell" / "scripts" / "launch-network-settings.sh"
INSTALL = ROOT / "install.sh"
RULES = ROOT / "hypr" / "rules.lua"


class NetworkPanelWiringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.panel = PANEL.read_text(encoding="utf-8")
        cls.install = INSTALL.read_text(encoding="utf-8")
        cls.rules = RULES.read_text(encoding="utf-8")

    def test_settings_uses_launcher_script(self):
        self.assertIn("launch-network-settings.sh", self.panel)
        self.assertIn("function openNetworkSettings", self.panel)
        self.assertNotIn('Quickshell.execDetached(["nm-connection-editor"])', self.panel)

    def test_ap_click_uses_connect_helper(self):
        self.assertIn("function connectTo(ssid)", self.panel)
        self.assertIn("wifi-connect.sh", self.panel)
        self.assertIn("onClicked: root.connectTo(ssid)", self.panel)
        self.assertIn("connectingSsid", self.panel)

    def test_installer_ships_connection_editor(self):
        self.assertIn("network-manager-applet", self.install)
        self.assertIn("networkmanager", self.install)

    def test_hyprland_floats_connection_editor(self):
        self.assertIn("nm-connection-editor", self.rules)

    def test_scripts_are_executable(self):
        for path in (CONNECT, SETTINGS):
            mode = path.stat().st_mode
            self.assertTrue(mode & stat.S_IXUSR, f"{path.name} should be executable")


class WifiConnectScriptTests(unittest.TestCase):
    def test_usage_without_ssid(self):
        proc = subprocess.run(
            [str(CONNECT)],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("usage:", proc.stderr)

    def test_prefers_saved_profile_by_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp)
            nmcli = bin_dir / "nmcli"
            log = bin_dir / "nmcli.log"
            nmcli.write_text(
                textwrap.dedent(
                    f"""\
                    #!/usr/bin/env bash
                    echo "$@" >> "{log}"
                    if [[ "$1" == "-t" && "$2" == "-f" && "$3" == "NAME,TYPE" ]]; then
                        printf '%s\\n' 'HomeNet:802-11-wireless' 'Wired:802-3-ethernet'
                        exit 0
                    fi
                    if [[ "$1" == "-w" && "$3" == "connection" && "$4" == "up" ]]; then
                        exit 0
                    fi
                    echo "unexpected: $*" >&2
                    exit 99
                    """
                ),
                encoding="utf-8",
            )
            nmcli.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            proc = subprocess.run(
                [str(CONNECT), "HomeNet"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            logged = log.read_text(encoding="utf-8")
            self.assertIn("connection up id HomeNet", logged)
            self.assertNotIn("device wifi connect", logged)

    def test_falls_back_to_wifi_connect(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp)
            nmcli = bin_dir / "nmcli"
            log = bin_dir / "nmcli.log"
            nmcli.write_text(
                textwrap.dedent(
                    f"""\
                    #!/usr/bin/env bash
                    echo "$@" >> "{log}"
                    if [[ "$1" == "-t" && "$2" == "-f" && "$3" == "NAME,TYPE" ]]; then
                        printf '%s\\n' 'Other:802-11-wireless'
                        exit 0
                    fi
                    if [[ "$1" == "-g" && "$2" == "802-11-wireless.ssid" ]]; then
                        echo "OtherSSID"
                        exit 0
                    fi
                    if [[ "$1" == "-w" && "$3" == "device" && "$4" == "wifi" && "$5" == "connect" ]]; then
                        exit 0
                    fi
                    echo "unexpected: $*" >&2
                    exit 99
                    """
                ),
                encoding="utf-8",
            )
            nmcli.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            proc = subprocess.run(
                [str(CONNECT), "CafeWifi"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            logged = log.read_text(encoding="utf-8")
            self.assertIn("device wifi connect CafeWifi", logged)

    def test_matches_profile_by_wireless_ssid(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp)
            nmcli = bin_dir / "nmcli"
            log = bin_dir / "nmcli.log"
            nmcli.write_text(
                textwrap.dedent(
                    f"""\
                    #!/usr/bin/env bash
                    echo "$@" >> "{log}"
                    if [[ "$1" == "-t" && "$2" == "-f" && "$3" == "NAME,TYPE" ]]; then
                        printf '%s\\n' 'My Home Profile:802-11-wireless'
                        exit 0
                    fi
                    if [[ "$1" == "-g" && "$2" == "802-11-wireless.ssid" ]]; then
                        echo "HomeSSID"
                        exit 0
                    fi
                    if [[ "$1" == "-w" && "$3" == "connection" && "$4" == "up" ]]; then
                        exit 0
                    fi
                    echo "unexpected: $*" >&2
                    exit 99
                    """
                ),
                encoding="utf-8",
            )
            nmcli.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            proc = subprocess.run(
                [str(CONNECT), "HomeSSID"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            logged = log.read_text(encoding="utf-8")
            self.assertIn("connection up id My Home Profile", logged)


class LaunchNetworkSettingsTests(unittest.TestCase):
    def test_runs_nm_connection_editor_when_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp)
            editor = bin_dir / "nm-connection-editor"
            marker = bin_dir / "launched"
            editor.write_text(
                textwrap.dedent(
                    f"""\
                    #!/usr/bin/env bash
                    touch "{marker}"
                    """
                ),
                encoding="utf-8",
            )
            editor.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:/usr/bin:/bin"
            proc = subprocess.run(
                [str(SETTINGS)],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertTrue(marker.exists())

    def test_fails_clearly_when_no_gui(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp)
            # Empty PATH except a fake notify-send so the script can exit 1 quietly.
            notify = bin_dir / "notify-send"
            notify.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            notify.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:/usr/bin:/bin"
            proc = subprocess.run(
                [str(SETTINGS)],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(proc.returncode, 1)


if __name__ == "__main__":
    unittest.main()

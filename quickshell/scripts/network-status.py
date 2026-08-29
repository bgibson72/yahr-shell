#!/usr/bin/env python3
"""Print the active network type as JSON.

Prefers the interface that owns the default route so Ethernet is shown
when the machine is actually using a wired link, even if Wi-Fi is still
associated.
"""

from __future__ import annotations

import json
import subprocess
import sys


def run(argv: list[str]) -> str:
    try:
        result = subprocess.run(argv, capture_output=True, text=True, check=False)
    except OSError:
        return ""
    return result.stdout


def default_iface() -> str:
    for line in run(["ip", "-o", "route", "show", "default"]).splitlines():
        parts = line.split()
        if "dev" in parts:
            idx = parts.index("dev")
            if idx + 1 < len(parts):
                return parts[idx + 1]
    return ""


def device_table() -> dict[str, tuple[str, str]]:
    table: dict[str, tuple[str, str]] = {}
    for line in run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]).splitlines():
        parts = line.split(":")
        if len(parts) < 3:
            continue
        device = parts[0]
        kind = parts[1].lower()
        state = ":".join(parts[2:]).lower()
        table[device] = (kind, state)
    return table


def connection_names() -> dict[str, str]:
    names: dict[str, str] = {}
    for line in run(["nmcli", "-t", "-f", "NAME,DEVICE", "connection", "show", "--active"]).splitlines():
        parts = line.split(":")
        if len(parts) < 2:
            continue
        name, device = parts[0], parts[-1]
        if device:
            names[device] = name
    return names


def classify(kind: str) -> str:
    if "ethernet" in kind or kind.startswith("802-3"):
        return "ethernet"
    if "p2p" in kind:
        return "other"
    if kind in ("wifi", "802-11-wireless") or "wireless" in kind:
        return "wifi"
    if kind.startswith("wifi"):
        return "wifi"
    return "other"


def connected(state: str) -> bool:
    return state.startswith("connected")


def pick_type(iface: str, devices: dict[str, tuple[str, str]]) -> tuple[str, str]:
    if iface and iface in devices:
        kind, state = devices[iface]
        if connected(state):
            classified = classify(kind)
            if classified in ("wifi", "ethernet"):
                return classified, iface
    for want in ("ethernet", "wifi"):
        for device, (kind, state) in devices.items():
            if connected(state) and classify(kind) == want:
                return want, device
    return "none", iface


def main() -> int:
    iface = default_iface()
    devices = device_table()
    kind, device = pick_type(iface, devices)
    names = connection_names()
    print(json.dumps({
        "type": kind,
        "device": device,
        "name": names.get(device, ""),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

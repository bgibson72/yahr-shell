#!/usr/bin/env python3
"""Print laptop battery status as JSON from sysfs.

Skips HID/peripheral batteries (scope=Device) so a mouse pack does not
mask the laptop pack. Used because UPower is optional and not installed
on every machine.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

PS = Path("/sys/class/power_supply")


def read_text(path: Path, default: str = "") -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return default


def mains_online() -> bool:
    if not PS.is_dir():
        return False
    for entry in sorted(PS.iterdir()):
        supply_type = read_text(entry / "type")
        online_file = entry / "online"
        if supply_type == "Mains" and online_file.exists():
            return read_text(online_file) == "1"
        name = entry.name.upper()
        if name.startswith(("AC", "ADP")) and online_file.exists():
            return read_text(online_file) == "1"
    return False


def pick_battery() -> Path | None:
    if not PS.is_dir():
        return None
    batteries: list[Path] = []
    for entry in sorted(PS.iterdir()):
        if read_text(entry / "type") != "Battery":
            continue
        if read_text(entry / "scope").lower() == "device":
            continue
        if not (entry / "capacity").exists() and not (entry / "energy_now").exists():
            continue
        batteries.append(entry)
    for entry in batteries:
        if entry.name.upper().startswith("BAT"):
            return entry
    return batteries[0] if batteries else None


def seconds_eta(battery: Path, status: str) -> int:
    try:
        power = float(read_text(battery / "power_now") or 0)
        energy_now = float(read_text(battery / "energy_now") or 0)
        energy_full = float(read_text(battery / "energy_full") or 0)
    except ValueError:
        return 0
    if power <= 0:
        return 0
    if status == "Discharging" and energy_now > 0:
        return int(energy_now / power * 3600)
    if status == "Charging" and energy_full > energy_now:
        return int((energy_full - energy_now) / power * 3600)
    return 0


def main() -> int:
    battery = pick_battery()
    ac = mains_online()
    if battery is None:
        print(json.dumps({
            "present": False,
            "percent": 0,
            "status": "Unknown",
            "ac": ac,
            "seconds": 0,
        }))
        return 0
    status = read_text(battery / "status") or "Unknown"
    try:
        percent = int(float(read_text(battery / "capacity") or 0))
    except ValueError:
        percent = 0
    print(json.dumps({
        "present": True,
        "percent": max(0, min(100, percent)),
        "status": status,
        "ac": ac,
        "seconds": seconds_eta(battery, status),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

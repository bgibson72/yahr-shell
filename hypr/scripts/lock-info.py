#!/usr/bin/env python3
"""Strings for the hyprlock bento dashboard. Reads ~/.config/yahr/settings.json.

Weather is served from ~/.cache/yahr/lock-weather.json. The bar and info
panel write that cache when they fetch wttr.in, so the lock screen can
paint immediately. If the cache is missing, one process fetches and the
rest wait on a file lock instead of stampeding the network.
"""
from __future__ import annotations

import fcntl
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))
SETTINGS = HOME / ".config/yahr/settings.json"
CACHE = HOME / ".cache/yahr/lock-weather.json"
LOCK = HOME / ".cache/yahr/lock-weather.lock"
STRINGS = HOME / ".cache/yahr/lock-strings"
WEATHER_TTL = 300

DAYS = ["Mon", "Tues", "Wed", "Thurs", "Fri", "Sat", "Sun"]

WEATHER_ICONS = {
    "113": "󰖙", "116": "󰖕", "119": "󰖐", "122": "󰖐", "143": "󰖑",
    "176": "󰖗", "179": "󰙿", "182": "󰙿", "185": "󰙿", "200": "󰖓",
    "227": "󰖘", "230": "󰼶", "248": "󰖑", "260": "󰖑", "263": "󰖗",
    "266": "󰖖", "281": "󰖖", "284": "󰖖", "293": "󰖗", "296": "󰖖",
    "299": "󰖖", "302": "󰖖", "305": "󰖖", "308": "󰖖", "311": "󰖖",
    "314": "󰖖", "317": "󰙿", "320": "󰙿", "323": "󰙿", "326": "󰙿",
    "329": "󰼶", "332": "󰼶", "335": "󰼶", "338": "󰼶", "350": "󰙿",
    "353": "󰖗", "356": "󰖖", "359": "󰖖", "362": "󰙿", "365": "󰙿",
    "368": "󰙿", "371": "󰼶", "374": "󰙿", "377": "󰙿", "386": "󰖓",
    "389": "󰖓", "392": "󰖓", "395": "󰼶",
}


def settings() -> dict:
    try:
        data = json.loads(SETTINGS.read_text())
        return data.get("general") or {}
    except (OSError, json.JSONDecodeError, TypeError):
        return {}


def time_now() -> None:
    g = settings()
    fmt = "%H:%M" if g.get("clockFormat24hr") else "%I:%M"
    if g.get("showSeconds"):
        fmt += ":%S"
    print(time.strftime(fmt), end="")


def ampm() -> None:
    if settings().get("clockFormat24hr"):
        return
    print(time.strftime("%p"), end="")


def date_weekday() -> None:
    print(DAYS[time.localtime().tm_wday], end="")


def date_month() -> None:
    print(time.strftime("%b"), end="")


def date_day() -> None:
    print(f"{time.localtime().tm_mday}", end="")


def date_year() -> None:
    print(time.strftime("%Y"), end="")


def _load_weather_file() -> tuple[dict | None, float]:
    try:
        age = time.time() - CACHE.stat().st_mtime
        data = json.loads(CACHE.read_text())
        if isinstance(data, dict) and (data.get("current_condition") or data.get("weather")):
            return data, age
    except (OSError, json.JSONDecodeError, TypeError):
        pass
    return None, 0.0


def _weather_meta(g: dict | None = None) -> tuple[str, str]:
    g = g if g is not None else settings()
    loc = str(g.get("weatherLocation") or "").strip()
    unit = "u" if g.get("weatherUseFahrenheit") else "m"
    return loc, unit


def _cache_matches(data: dict, loc: str, unit: str) -> bool:
    if "_unit" in data and data.get("_unit") != unit:
        return False
    if "_loc" in data and data.get("_loc") != loc:
        return False
    return True


def _save_weather(data: dict, loc: str, unit: str) -> dict:
    data["_unit"] = unit
    data["_loc"] = loc
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data))
    tmp.replace(CACHE)
    _write_lock_strings(data)
    return data


def _http_fetch(loc: str, unit: str) -> dict | None:
    query = urllib.parse.quote(loc) if loc else ""
    url = f"https://wttr.in/{query}?{unit}&format=j1"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "yahr-lock/1.0"})
        with urllib.request.urlopen(req, timeout=4) as resp:
            data = json.loads(resp.read().decode())
        if not isinstance(data, dict):
            return None
        return _save_weather(data, loc, unit)
    except (OSError, urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError):
        return None


def _with_weather_lock():
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    fh = open(LOCK, "a+", encoding="utf-8")
    fcntl.flock(fh, fcntl.LOCK_EX)
    return fh


def _spawn_refresh() -> None:
    flag = CACHE.parent / "lock-refresh.running"
    try:
        fd = os.open(flag, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
        os.close(fd)
    except FileExistsError:
        try:
            if time.time() - flag.stat().st_mtime < 45:
                return
            flag.unlink()
        except OSError:
            return
        try:
            fd = os.open(flag, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
            os.close(fd)
        except FileExistsError:
            return
    subprocess.Popen(
        [sys.executable, str(Path(__file__).resolve()), "refresh"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def _weather_data(*, allow_fetch: bool = True) -> dict | None:
    loc, unit = _weather_meta()
    cached, age = _load_weather_file()
    if cached and _cache_matches(cached, loc, unit):
        if age >= WEATHER_TTL:
            _spawn_refresh()
        return cached
    if not allow_fetch:
        return None
    fh = _with_weather_lock()
    try:
        cached, age = _load_weather_file()
        if cached and _cache_matches(cached, loc, unit):
            return cached
        fetched = _http_fetch(loc, unit)
        return fetched or cached
    finally:
        fcntl.flock(fh, fcntl.LOCK_UN)
        fh.close()


def fetch_weather() -> None:
    """Used by the bar/info panel: refresh cache and print the JSON payload."""
    loc, unit = _weather_meta()
    fh = _with_weather_lock()
    try:
        data = _http_fetch(loc, unit)
        if not data:
            cached, _age = _load_weather_file()
            data = cached if cached else {}
        if data:
            _write_lock_strings(data)
        sys.stdout.write(json.dumps(data))
    finally:
        fcntl.flock(fh, fcntl.LOCK_UN)
        fh.close()


def render() -> None:
    """Write lock-string files from cache (no network). Used at theme apply."""
    cached, _age = _load_weather_file()
    _write_lock_strings(cached)


def refresh() -> None:
    loc, unit = _weather_meta()
    flag = CACHE.parent / "lock-refresh.running"
    fh = _with_weather_lock()
    try:
        _http_fetch(loc, unit)
    finally:
        fcntl.flock(fh, fcntl.LOCK_UN)
        fh.close()
        flag.unlink(missing_ok=True)


def _icon(code: str) -> str:
    return WEATHER_ICONS.get(str(code), "󰖕")


def _temp_unit(data: dict) -> str:
    if data.get("_unit") == "u":
        return "F"
    if data.get("_unit") == "m":
        return "C"
    return "F" if settings().get("weatherUseFahrenheit") else "C"


def weather_icon() -> None:
    data = _weather_data(allow_fetch=False)
    if not data:
        print("󰖕", end="")
        return
    cur = (data.get("current_condition") or [{}])[0]
    print(_icon(cur.get("weatherCode") or ""), end="")


def weather_temp() -> None:
    data = _weather_data(allow_fetch=False)
    if not data:
        print("—", end="")
        return
    cur = (data.get("current_condition") or [{}])[0]
    unit = _temp_unit(data)
    key = "temp_F" if unit == "F" else "temp_C"
    print(f"{cur.get(key, '—')}°{unit}", end="")


def _wrap_cond(text: str, width: int = 12, max_lines: int = 2) -> str:
    """Fit wttr.in phrases onto the hyprlock weather columns.

    Keeps whole words together. A single long word may exceed ``width``
    rather than hyphenating; leftover text on the last line is ellipsized.
    """
    words = (text or "").split()
    if not words:
        return ""
    lines: list[str] = []
    current = ""
    for i, word in enumerate(words):
        trial = word if not current else f"{current} {word}"
        if len(trial) <= width:
            current = trial
            continue
        if current:
            lines.append(current)
            current = word
        else:
            current = word
        if len(lines) == max_lines - 1:
            rest = " ".join([current, *words[i + 1 :]]).strip()
            if len(rest) > width:
                cut = rest.rfind(" ", 0, width)
                if cut <= 0:
                    cut = max(1, width - 1)
                rest = rest[:cut].rstrip() + "…"
            lines.append(rest)
            current = ""
            break
    if current and len(lines) < max_lines:
        lines.append(current)
    return "\n".join(lines[:max_lines])


def weather_cond() -> None:
    data = _weather_data(allow_fetch=False)
    if not data:
        print("Unavailable", end="")
        return
    cur = (data.get("current_condition") or [{}])[0]
    desc = ((cur.get("weatherDesc") or [{}])[0].get("value") or "Unknown").strip()
    print(_wrap_cond(desc, width=14), end="")


def _forecast_bits(index: int, data: dict | None = None) -> dict[str, str]:
    empty = {"day": "—", "temps": "—", "icon": "󰖕", "cond": ""}
    if data is None:
        data = _weather_data(allow_fetch=False)
    if not data:
        return empty
    days = data.get("weather") or []
    if index >= len(days):
        return empty
    day = days[index]
    now = time.localtime()
    unit = _temp_unit(data)
    high = day.get("maxtempF" if unit == "F" else "maxtempC", "—")
    low = day.get("mintempF" if unit == "F" else "mintempC", "—")
    hourly = day.get("hourly") or []
    mid = hourly[len(hourly) // 2] if hourly else {}
    code = mid.get("weatherCode") or ""
    cond = _wrap_cond(((mid.get("weatherDesc") or [{}])[0].get("value") or "").strip(), width=13)
    return {
        "day": DAYS[(now.tm_wday + index) % 7],
        "temps": f"{high}° / {low}°",
        "icon": _icon(code),
        "cond": cond,
    }


def _write_lock_strings(data: dict | None) -> None:
    """Pre-render hyprlock weather labels so the lock screen can `cat` them."""
    STRINGS.mkdir(parents=True, exist_ok=True)
    out: dict[str, str] = {
        "weather-icon": "󰖕",
        "weather-temp": "—",
        "weather-cond": "Unavailable",
    }
    for i in range(3):
        bits = _forecast_bits(i, data)
        out[f"forecast-{i}-day"] = bits["day"]
        out[f"forecast-{i}-temps"] = bits["temps"]
        out[f"forecast-{i}-icon"] = bits["icon"]
        out[f"forecast-{i}-cond"] = bits["cond"]
    if data:
        cur = (data.get("current_condition") or [{}])[0]
        unit = _temp_unit(data)
        key = "temp_F" if unit == "F" else "temp_C"
        out["weather-icon"] = _icon(cur.get("weatherCode") or "")
        out["weather-temp"] = f"{cur.get(key, '—')}°{unit}"
        out["weather-cond"] = _wrap_cond(
            ((cur.get("weatherDesc") or [{}])[0].get("value") or "Unknown").strip(),
            width=14,
        )
    for name, text in out.items():
        path = STRINGS / name
        tmp = path.with_suffix(".tmp")
        tmp.write_text(text)
        tmp.replace(path)
    host_path = STRINGS / "host-block"
    host_tmp = host_path.with_suffix(".tmp")
    host_tmp.write_text(_host_block_text())
    host_tmp.replace(host_path)


def forecast_part(index: int, key: str) -> None:
    print(_forecast_bits(index).get(key) or "", end="")


def _battery() -> dict:
    bat = None
    ac = False
    ps = Path("/sys/class/power_supply")
    if ps.is_dir():
        for entry in sorted(ps.iterdir()):
            typ = _read(entry / "type")
            if typ == "Mains" and _read(entry / "online") == "1":
                ac = True
            if entry.name.upper().startswith(("AC", "ADP")) and _read(entry / "online") == "1":
                ac = True
            if typ == "Battery" and _read(entry / "scope").lower() != "device":
                if bat is None or entry.name.upper().startswith("BAT"):
                    bat = entry
    percent = 0
    status = "Unknown"
    if bat is not None:
        try:
            percent = int(float(_read(bat / "capacity") or 0))
        except ValueError:
            percent = 0
        status = _read(bat / "status") or "Unknown"
    return {"present": bat is not None, "percent": percent, "status": status, "ac": ac}


def _read(path: Path) -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def battery_icon() -> None:
    b = _battery()
    if not b["present"]:
        print("󰚥", end="")
        return
    if b["status"] == "Charging" or (b["ac"] and b["status"] != "Discharging"):
        if b["status"] == "Charging":
            print("󰂄", end="")
            return
        print("󰚥", end="")
        return
    pct = b["percent"]
    glyphs = "󰂃󰁺󰁻󰁼󰁽󰁾󰁿󰂀󰂁󰂂󰁹"
    idx = min(10, max(0, pct // 10))
    print(glyphs[idx], end="")


def battery_pct() -> None:
    b = _battery()
    if not b["present"]:
        print("AC", end="")
        return
    print(f"{b['percent']}%", end="")


def battery_sub() -> None:
    b = _battery()
    if not b["present"]:
        print("plugged in", end="")
        return
    if b["status"] == "Charging":
        print("charging", end="")
        return
    if b["ac"]:
        print("plugged in", end="")
        return
    print("remaining", end="")


def _os_name() -> str:
    pretty = "Arch Linux"
    try:
        for line in Path("/etc/os-release").read_text().splitlines():
            if line.startswith("PRETTY_NAME="):
                pretty = line.split("=", 1)[1].strip().strip('"')
                break
    except OSError:
        pass
    return pretty


def _wm_name() -> str:
    return os.environ.get("XDG_CURRENT_DESKTOP") or "Hyprland"


def _fmt_bytes(n: int, *, disk: bool = False) -> str:
    g = n / (1024 ** 3)
    if disk:
        return f"{g:.0f}G"
    if g >= 10:
        return f"{g:.0f}Gi"
    return f"{g:.1f}Gi"


def _ram_str() -> str:
    try:
        vals: dict[str, int] = {}
        for line in Path("/proc/meminfo").read_text().splitlines():
            parts = line.replace(":", " ").split()
            if len(parts) >= 2:
                vals[parts[0]] = int(parts[1]) * 1024
        total = vals.get("MemTotal", 0)
        used = total - vals.get("MemAvailable", 0)
        return f"{_fmt_bytes(used)} / {_fmt_bytes(total)}"
    except (OSError, ValueError):
        return "—"


def _disk_str() -> str:
    try:
        st = os.statvfs("/")
        total = st.f_frsize * st.f_blocks
        used = st.f_frsize * (st.f_blocks - st.f_bfree)
        return f"{_fmt_bytes(used, disk=True)} / {_fmt_bytes(total, disk=True)}"
    except OSError:
        return "—"


def host_os() -> None:
    print(_os_name(), end="")


def host_wm() -> None:
    print(_wm_name(), end="")


def host_kernel() -> None:
    print(os.uname().release, end="")


def host_ram() -> None:
    print(_ram_str(), end="")


def host_disk() -> None:
    print(_disk_str(), end="")


def _accent_hex() -> str:
    try:
        pal = json.loads((HOME / ".config/yahr/current.json").read_text())
        raw = str(pal.get("accentBlue") or pal.get("accent") or "83a598")
        return raw.lstrip("#")
    except (OSError, json.JSONDecodeError, TypeError):
        return "83a598"


def _host_block_text() -> str:
    acc = _accent_hex()
    rows = (
        ("", _os_name()),
        ("", _wm_name()),
        ("", os.uname().release),
        ("󰍛", _ram_str()),
        ("󰋊", _disk_str()),
    )
    return "\n".join(
        f"<span foreground='#{acc}'>{icon}</span>  {text}"
        for icon, text in rows
    )


def host_block() -> None:
    print(_host_block_text(), end="")


COMMANDS = {
    "time": time_now,
    "ampm": ampm,
    "date-weekday": date_weekday,
    "date-month": date_month,
    "date-day": date_day,
    "date-year": date_year,
    "weather-icon": weather_icon,
    "weather-temp": weather_temp,
    "weather-cond": weather_cond,
    "forecast-0-day": lambda: forecast_part(0, "day"),
    "forecast-0-temps": lambda: forecast_part(0, "temps"),
    "forecast-0-icon": lambda: forecast_part(0, "icon"),
    "forecast-0-cond": lambda: forecast_part(0, "cond"),
    "forecast-1-day": lambda: forecast_part(1, "day"),
    "forecast-1-temps": lambda: forecast_part(1, "temps"),
    "forecast-1-icon": lambda: forecast_part(1, "icon"),
    "forecast-1-cond": lambda: forecast_part(1, "cond"),
    "forecast-2-day": lambda: forecast_part(2, "day"),
    "forecast-2-temps": lambda: forecast_part(2, "temps"),
    "forecast-2-icon": lambda: forecast_part(2, "icon"),
    "forecast-2-cond": lambda: forecast_part(2, "cond"),
    "battery-icon": battery_icon,
    "battery-pct": battery_pct,
    "battery-sub": battery_sub,
    "host-os": host_os,
    "host-wm": host_wm,
    "host-kernel": host_kernel,
    "host-ram": host_ram,
    "host-disk": host_disk,
    "host-block": host_block,
    "fetch-weather": fetch_weather,
    "refresh": refresh,
    "render": render,
}


def main() -> int:
    name = sys.argv[1] if len(sys.argv) > 1 else ""
    fn = COMMANDS.get(name)
    if not fn:
        print("—", end="")
        return 1
    fn()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

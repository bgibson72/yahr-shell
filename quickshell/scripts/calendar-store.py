#!/usr/bin/env python3
"""Multi-calendar ICS store for the Yahr Calendar app.

Commands print JSON on stdout. Event add/update flags are argv (no shell).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import uuid
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

HOME = Path.home()
ROOT = HOME / ".config/yahr/calendars"
REGISTRY = ROOT / "calendars.json"
FIRED = ROOT / "fired-alerts.json"

PALETTE = [
    "#89b4fa",
    "#f5c2e7",
    "#a6e3a1",
    "#f9e2af",
    "#fab387",
    "#cba6f7",
    "#94e2d5",
    "#f38ba8",
    "#b4befe",
    "#89dceb",
]

ALERT_LABELS = {
    0: "at the time of the event",
    5: "5 minutes before",
    10: "10 minutes before",
    15: "15 minutes before",
    30: "30 minutes before",
    60: "1 hour before",
    1440: "the day before",
}


def _now() -> datetime:
    return datetime.now().astimezone()


def _ensure_dirs() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)


def _load_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default


def _save_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def _expand(path: str) -> Path:
    return Path(os.path.expanduser(path)).resolve()


def _slug(name: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "-", name.strip().lower()).strip("-")
    return s or "calendar"


def _unfold(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return re.sub(r"\n[ \t]", "", text)


def _unescape(value: str) -> str:
    return (
        value.replace("\\n", "\n")
        .replace("\\N", "\n")
        .replace("\\,", ",")
        .replace("\\;", ";")
        .replace("\\\\", "\\")
    )


def _escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace("\n", "\\n")
    )


def _parse_ics_dt(value: str, params: str) -> tuple[datetime, bool]:
    """Return (datetime, all_day). Floating times are treated as local."""
    raw = value.strip()
    if "VALUE=DATE" in params.upper() or (len(raw) == 8 and "T" not in raw):
        y, m, d = int(raw[0:4]), int(raw[4:6]), int(raw[6:8])
        return datetime(y, m, d), True
    m = re.match(r"^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$", raw)
    if not m:
        y, mo, d = int(raw[0:4]), int(raw[4:6]), int(raw[6:8])
        return datetime(y, mo, d), True
    dt = datetime(
        int(m.group(1)),
        int(m.group(2)),
        int(m.group(3)),
        int(m.group(4)),
        int(m.group(5)),
        int(m.group(6)),
    )
    if m.group(7) == "Z":
        dt = dt.replace(tzinfo=timezone.utc).astimezone()
    return dt.replace(tzinfo=None), False


def _fmt_date(d: date) -> str:
    return d.strftime("%Y%m%d")


def _fmt_dt(dt: datetime) -> str:
    return dt.strftime("%Y%m%dT%H%M%S")


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%S")


def _parse_iso(value: str) -> datetime:
    value = value.strip()
    if "T" in value:
        return datetime.fromisoformat(value[:19])
    return datetime.fromisoformat(value[:10])


def _parse_trigger(value: str) -> int | None:
    value = value.strip().upper()
    sign = -1
    if value.startswith("-"):
        sign = -1
        value = value[1:]
    elif value.startswith("+"):
        sign = 1
        value = value[1:]
    if value in ("PT0S", "P0D", "PT0M", "PT0H"):
        return 0
    days = hours = minutes = 0
    m = re.match(r"^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$", value)
    if not m:
        return None
    days = int(m.group(1) or 0)
    hours = int(m.group(2) or 0)
    minutes = int(m.group(3) or 0)
    total = days * 1440 + hours * 60 + minutes
    if sign > 0:
        return 0
    if total in ALERT_LABELS:
        return total
    if total == 0:
        return 0
    return total


def _trigger_ics(minutes: int) -> str:
    if minutes <= 0:
        return "-PT0S"
    if minutes % 1440 == 0:
        return f"-P{minutes // 1440}D"
    if minutes % 60 == 0:
        return f"-PT{minutes // 60}H"
    return f"-PT{minutes}M"


def parse_ics(text: str) -> list[dict[str, Any]]:
    if not text or not text.strip():
        return []
    unfolded = _unfold(text)
    events: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    in_alarm = False
    calendar_name = ""
    calendar_color = ""

    for raw in unfolded.split("\n"):
        line = raw.strip()
        if not line:
            continue
        if line == "BEGIN:VEVENT":
            current = {
                "uid": "",
                "title": "",
                "location": "",
                "description": "",
                "start": None,
                "end": None,
                "allDay": False,
                "rrule": "",
                "alerts": [],
            }
            in_alarm = False
            continue
        if line == "END:VEVENT" and current is not None:
            if current.get("start") is not None:
                if current.get("end") is None:
                    start: datetime = current["start"]
                    current["end"] = start + (timedelta(days=1) if current["allDay"] else timedelta(hours=1))
                if not current["uid"]:
                    current["uid"] = str(uuid.uuid4())
                events.append(current)
            current = None
            continue
        if line == "BEGIN:VALARM":
            in_alarm = True
            continue
        if line == "END:VALARM":
            in_alarm = False
            continue

        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        name, _, params = key.partition(";")
        name = name.upper()

        if current is None:
            if name == "X-WR-CALNAME":
                calendar_name = _unescape(value)
            elif name in ("X-APPLE-CALENDAR-COLOR", "COLOR"):
                calendar_color = value.strip()
            continue

        if in_alarm:
            if name == "TRIGGER":
                mins = _parse_trigger(value)
                if mins is not None and mins not in current["alerts"]:
                    current["alerts"].append(mins)
            continue

        if name == "UID":
            current["uid"] = value.strip()
        elif name == "SUMMARY":
            current["title"] = _unescape(value)
        elif name == "LOCATION":
            current["location"] = _unescape(value)
        elif name == "DESCRIPTION":
            current["description"] = _unescape(value)
        elif name == "RRULE":
            current["rrule"] = value.strip()
        elif name == "DTSTART":
            dt, all_day = _parse_ics_dt(value, params)
            current["start"] = dt
            current["allDay"] = all_day
        elif name == "DTEND":
            dt, all_day = _parse_ics_dt(value, params)
            current["end"] = dt
            if all_day:
                current["allDay"] = True

    for ev in events:
        ev["alerts"] = sorted(set(int(a) for a in ev["alerts"]))
        if calendar_name:
            ev["_calendarName"] = calendar_name
        if calendar_color:
            ev["_calendarColor"] = calendar_color
    return events


def _weekday_code(dt: datetime) -> str:
    return ["MO", "TU", "WE", "TH", "FR", "SA", "SU"][dt.weekday()]


def _rrule_parts(rrule: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in rrule.split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            out[k.upper()] = v
    return out


def expand_event(ev: dict[str, Any], window_start: datetime, window_end: datetime) -> list[dict[str, Any]]:
    start: datetime = ev["start"]
    end: datetime = ev["end"]
    duration = end - start
    rrule = ev.get("rrule") or ""
    if not rrule:
        if end > window_start and start < window_end:
            occ = dict(ev)
            occ["occurrenceStart"] = start
            return [occ]
        return []

    parts = _rrule_parts(rrule)
    freq = parts.get("FREQ", "")
    interval = int(parts.get("INTERVAL", "1") or 1)
    count = int(parts["COUNT"]) if "COUNT" in parts else None
    until = None
    if "UNTIL" in parts:
        until, _ = _parse_ics_dt(parts["UNTIL"], "")
    byday = [d.strip() for d in parts.get("BYDAY", "").split(",") if d.strip()]

    occurrences: list[datetime] = []
    cursor = start
    emitted = 0
    guard = 0
    while guard < 8000:
        guard += 1
        if until and cursor.date() > until.date():
            break
        if count is not None and emitted >= count:
            break
        if cursor >= window_end + timedelta(days=1):
            break

        match = False
        if freq == "DAILY":
            days = (cursor.date() - start.date()).days
            match = days >= 0 and days % interval == 0
        elif freq == "WEEKLY":
            weeks = ((cursor.date() - start.date()).days) // 7
            day_ok = (not byday) or (_weekday_code(cursor) in byday)
            match = weeks >= 0 and weeks % interval == 0 and day_ok
        elif freq == "MONTHLY":
            months = (cursor.year - start.year) * 12 + (cursor.month - start.month)
            match = months >= 0 and months % interval == 0 and cursor.day == start.day
        elif freq == "YEARLY":
            years = cursor.year - start.year
            match = years >= 0 and years % interval == 0 and cursor.month == start.month and cursor.day == start.day
        else:
            match = cursor.date() == start.date()

        if match and cursor >= start:
            occurrences.append(cursor)
            emitted += 1
            if count is not None and emitted >= count:
                break

        if freq == "WEEKLY" and byday:
            cursor += timedelta(days=1)
        elif freq == "DAILY":
            cursor += timedelta(days=interval)
        elif freq == "WEEKLY":
            cursor += timedelta(weeks=interval)
        elif freq == "MONTHLY":
            month = cursor.month + interval
            year = cursor.year + (month - 1) // 12
            month = (month - 1) % 12 + 1
            try:
                cursor = cursor.replace(year=year, month=month)
            except ValueError:
                cursor = cursor.replace(year=year, month=month, day=28)
        elif freq == "YEARLY":
            try:
                cursor = cursor.replace(year=cursor.year + interval)
            except ValueError:
                cursor = cursor.replace(year=cursor.year + interval, day=28)
        else:
            break

    out: list[dict[str, Any]] = []
    for occ in occurrences:
        occ_end = occ + duration
        if occ_end > window_start and occ < window_end:
            row = dict(ev)
            row["start"] = occ
            row["end"] = occ_end
            row["occurrenceStart"] = occ
            out.append(row)
    return out


def _vevent_block(ev: dict[str, Any]) -> str:
    uid = ev.get("uid") or str(uuid.uuid4())
    start: datetime = ev["start"]
    end: datetime = ev["end"]
    lines = ["BEGIN:VEVENT", f"UID:{uid}", f"DTSTAMP:{_fmt_dt(_now().replace(tzinfo=None))}"]
    if ev.get("allDay"):
        s = start.date()
        e = end.date()
        if e <= s:
            e = s + timedelta(days=1)
        lines.append(f"DTSTART;VALUE=DATE:{_fmt_date(s)}")
        lines.append(f"DTEND;VALUE=DATE:{_fmt_date(e)}")
    else:
        lines.append(f"DTSTART:{_fmt_dt(start)}")
        lines.append(f"DTEND:{_fmt_dt(end)}")
    lines.append(f"SUMMARY:{_escape(ev.get('title') or '')}")
    if ev.get("location"):
        lines.append(f"LOCATION:{_escape(ev['location'])}")
    if ev.get("description"):
        lines.append(f"DESCRIPTION:{_escape(ev['description'])}")
    if ev.get("rrule"):
        lines.append(f"RRULE:{ev['rrule']}")
    for mins in sorted(set(int(a) for a in ev.get("alerts") or [])):
        lines.extend(
            [
                "BEGIN:VALARM",
                "ACTION:DISPLAY",
                f"DESCRIPTION:{_escape(ev.get('title') or 'Reminder')}",
                f"TRIGGER:{_trigger_ics(mins)}",
                "END:VALARM",
            ]
        )
    lines.append("END:VEVENT")
    return "\n".join(lines)


def _wrap_calendar(name: str, color: str, vevents: str) -> str:
    return (
        "BEGIN:VCALENDAR\n"
        "VERSION:2.0\n"
        "PRODID:-//Yahr Shell//Calendar//EN\n"
        "CALSCALE:GREGORIAN\n"
        f"X-WR-CALNAME:{_escape(name)}\n"
        f"X-APPLE-CALENDAR-COLOR:{color}\n"
        f"{vevents}\n"
        "END:VCALENDAR\n"
    )


def _split_vevents(text: str) -> tuple[str, list[str], str]:
    """Return (preamble, vevent blocks, rest)."""
    unfolded = _unfold(text or "")
    blocks: list[str] = []
    pre: list[str] = []
    rest: list[str] = []
    buf: list[str] = []
    in_event = False
    seen_event = False
    for line in unfolded.split("\n"):
        if line.strip() == "BEGIN:VEVENT":
            in_event = True
            seen_event = True
            buf = [line]
            continue
        if line.strip() == "END:VEVENT" and in_event:
            buf.append(line)
            blocks.append("\n".join(buf))
            in_event = False
            buf = []
            continue
        if in_event:
            buf.append(line)
        elif not seen_event:
            if line.strip() and line.strip() != "END:VCALENDAR":
                pre.append(line)
        else:
            if line.strip() and line.strip() != "END:VCALENDAR":
                rest.append(line)
    return "\n".join(pre), blocks, "\n".join(rest)


def write_calendar_file(path: Path, name: str, color: str, events: list[dict[str, Any]]) -> None:
    body = "\n".join(_vevent_block(ev) for ev in events)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(_wrap_calendar(name, color, body), encoding="utf-8")


def rewrite_event(path: Path, name: str, color: str, uid: str, new_ev: dict[str, Any] | None) -> None:
    text = path.read_text(encoding="utf-8") if path.is_file() else ""
    events = parse_ics(text)
    kept = [ev for ev in events if ev.get("uid") != uid]
    if new_ev is not None:
        kept.append(new_ev)
    write_calendar_file(path, name, color, kept)


def default_registry() -> dict[str, Any]:
    personal = ROOT / "personal.ics"
    if not personal.is_file():
        write_calendar_file(personal, "Personal", PALETTE[0], [])
    return {
        "calendars": [
            {
                "id": "personal",
                "name": "Personal",
                "color": PALETTE[0],
                "path": str(personal),
                "writable": True,
                "enabled": True,
            }
        ]
    }


def load_registry() -> dict[str, Any]:
    _ensure_dirs()
    data = _load_json(REGISTRY, None)
    if not data or not data.get("calendars"):
        data = default_registry()
        _save_json(REGISTRY, data)
        return data
    changed = False
    for i, cal in enumerate(data["calendars"]):
        if not cal.get("color"):
            cal["color"] = PALETTE[i % len(PALETTE)]
            changed = True
        if "enabled" not in cal:
            cal["enabled"] = True
            changed = True
        if "writable" not in cal:
            p = _expand(cal["path"])
            cal["writable"] = os.access(p.parent, os.W_OK) if p.parent.is_dir() else True
            changed = True
    if changed:
        _save_json(REGISTRY, data)
    return data


def save_registry(data: dict[str, Any]) -> None:
    _save_json(REGISTRY, data)


def find_cal(data: dict[str, Any], cal_id: str) -> dict[str, Any]:
    for cal in data["calendars"]:
        if cal["id"] == cal_id:
            return cal
    raise SystemExit(f"unknown calendar: {cal_id}")


def load_calendar_events(cal: dict[str, Any]) -> list[dict[str, Any]]:
    path = _expand(cal["path"])
    if path.is_file():
        return parse_ics(path.read_text(encoding="utf-8", errors="replace"))
    if str(cal.get("path", "")).startswith(("http://", "https://")):
        try:
            proc = subprocess.run(
                ["curl", "-fsSL", cal["path"]],
                check=False,
                capture_output=True,
                text=True,
                timeout=20,
            )
            if proc.returncode == 0:
                return parse_ics(proc.stdout)
        except (OSError, subprocess.SubprocessError):
            return []
    return []


def serialize_event(ev: dict[str, Any], cal: dict[str, Any]) -> dict[str, Any]:
    start: datetime = ev["start"]
    end: datetime = ev["end"]
    occ = ev.get("occurrenceStart") or start
    return {
        "id": ev.get("uid") or "",
        "calendarId": cal["id"],
        "calendarName": cal["name"],
        "color": cal["color"],
        "title": ev.get("title") or "(No title)",
        "location": ev.get("location") or "",
        "allDay": bool(ev.get("allDay")),
        "start": _iso(start),
        "end": _iso(end),
        "alerts": ev.get("alerts") or [],
        "writable": bool(cal.get("writable")),
        "occurrenceStart": _iso(occ if isinstance(occ, datetime) else start),
    }


def dump_payload(window_start: datetime, window_end: datetime) -> dict[str, Any]:
    data = load_registry()
    events_out: list[dict[str, Any]] = []
    for cal in data["calendars"]:
        if not cal.get("enabled", True):
            continue
        for ev in load_calendar_events(cal):
            for occ in expand_event(ev, window_start, window_end):
                events_out.append(serialize_event(occ, cal))
    events_out.sort(key=lambda e: (e["start"], e["title"]))
    return {"calendars": data["calendars"], "events": events_out}


def cmd_dump(args: argparse.Namespace) -> int:
    start = _parse_iso(args.start) if args.start else datetime(_now().year, 1, 1)
    end = _parse_iso(args.end) if args.end else datetime(_now().year + 1, 1, 1)
    json.dump(dump_payload(start, end), sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


def cmd_import(args: argparse.Namespace) -> int:
    data = load_registry()
    src = args.path
    name = args.name
    color = args.color
    dest: Path
    writable = True
    if src.startswith(("http://", "https://")):
        cal_id = _slug(name or "web") + "-" + uuid.uuid4().hex[:6]
        dest = ROOT / f"{cal_id}.ics"
        proc = subprocess.run(["curl", "-fsSL", src], check=False, capture_output=True, text=True, timeout=30)
        if proc.returncode != 0:
            print(json.dumps({"error": "download failed"}), file=sys.stderr)
            return 1
        dest.write_text(proc.stdout, encoding="utf-8")
        parsed = parse_ics(proc.stdout)
        if not name:
            name = parsed[0].get("_calendarName") if parsed else None
            name = name or "Imported"
        if not color:
            color = (parsed[0].get("_calendarColor") if parsed else None) or PALETTE[len(data["calendars"]) % len(PALETTE)]
    else:
        path = _expand(src)
        if not path.is_file():
            print(json.dumps({"error": f"not found: {path}"}), file=sys.stderr)
            return 1
        text = path.read_text(encoding="utf-8", errors="replace")
        parsed = parse_ics(text)
        if not name:
            name = parsed[0].get("_calendarName") if parsed else path.stem
            name = name or path.stem
        if not color:
            color = (parsed[0].get("_calendarColor") if parsed else None) or PALETTE[len(data["calendars"]) % len(PALETTE)]
        cal_id = _slug(name) + "-" + uuid.uuid4().hex[:6]
        dest = ROOT / f"{cal_id}.ics"
        shutil.copy2(path, dest)
        writable = os.access(dest, os.W_OK)

    data["calendars"].append(
        {
            "id": cal_id,
            "name": name,
            "color": color if color.startswith("#") else f"#{color.lstrip('#')}",
            "path": str(dest),
            "writable": writable,
            "enabled": True,
        }
    )
    save_registry(data)
    json.dump({"ok": True, "id": cal_id, "calendars": data["calendars"]}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def cmd_remove(args: argparse.Namespace) -> int:
    data = load_registry()
    cal = find_cal(data, args.id)
    if cal["id"] == "personal":
        print(json.dumps({"error": "cannot remove the Personal calendar"}), file=sys.stderr)
        return 1
    data["calendars"] = [c for c in data["calendars"] if c["id"] != args.id]
    save_registry(data)
    json.dump({"ok": True, "calendars": data["calendars"]}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def cmd_set_calendar(args: argparse.Namespace) -> int:
    data = load_registry()
    cal = find_cal(data, args.id)
    if args.name:
        cal["name"] = args.name
    if args.color:
        cal["color"] = args.color if args.color.startswith("#") else f"#{args.color}"
    if args.enabled is not None:
        cal["enabled"] = args.enabled == "true"
    save_registry(data)
    json.dump({"ok": True, "calendar": cal}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def _event_from_args(args: argparse.Namespace, uid: str | None = None) -> dict[str, Any]:
    start = _parse_iso(args.start)
    end = _parse_iso(args.end) if args.end else None
    all_day = bool(args.all_day)
    if all_day:
        start = datetime(start.year, start.month, start.day)
        if end is None:
            end = start + timedelta(days=1)
        else:
            end = datetime(end.year, end.month, end.day)
            # UI end date is inclusive; ICS DTEND is exclusive.
            end = end + timedelta(days=1)
            if end <= start:
                end = start + timedelta(days=1)
    else:
        if end is None:
            end = start + timedelta(hours=1)
    alerts: list[int] = []
    if args.alerts:
        for part in args.alerts.split(","):
            part = part.strip()
            if part:
                alerts.append(int(part))
    return {
        "uid": uid or str(uuid.uuid4()),
        "title": args.title or "New event",
        "location": args.location or "",
        "description": "",
        "start": start,
        "end": end,
        "allDay": all_day,
        "rrule": "",
        "alerts": sorted(set(alerts)),
    }


def cmd_add(args: argparse.Namespace) -> int:
    data = load_registry()
    cal = find_cal(data, args.calendar)
    if not cal.get("writable", True):
        print(json.dumps({"error": "calendar is read-only"}), file=sys.stderr)
        return 1
    ev = _event_from_args(args)
    path = _expand(cal["path"])
    events = parse_ics(path.read_text(encoding="utf-8", errors="replace")) if path.is_file() else []
    events.append(ev)
    write_calendar_file(path, cal["name"], cal["color"], events)
    json.dump({"ok": True, "event": serialize_event(ev, cal)}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def cmd_update(args: argparse.Namespace) -> int:
    data = load_registry()
    cal = find_cal(data, args.calendar)
    if not cal.get("writable", True):
        print(json.dumps({"error": "calendar is read-only"}), file=sys.stderr)
        return 1
    ev = _event_from_args(args, uid=args.uid)
    rewrite_event(_expand(cal["path"]), cal["name"], cal["color"], args.uid, ev)
    json.dump({"ok": True, "event": serialize_event(ev, cal)}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def cmd_delete(args: argparse.Namespace) -> int:
    data = load_registry()
    cal = find_cal(data, args.calendar)
    if not cal.get("writable", True):
        print(json.dumps({"error": "calendar is read-only"}), file=sys.stderr)
        return 1
    rewrite_event(_expand(cal["path"]), cal["name"], cal["color"], args.uid, None)
    json.dump({"ok": True}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def _event_fire_at(ev: dict[str, Any], offset: int) -> datetime:
    start: datetime = ev["start"]
    if ev.get("allDay"):
        start = datetime(start.year, start.month, start.day, 9, 0, 0)
    return start - timedelta(minutes=offset)


def cmd_fire_due(_args: argparse.Namespace) -> int:
    data = load_registry()
    fired = _load_json(FIRED, {"keys": []})
    keys = set(fired.get("keys") or [])
    now = _now().replace(tzinfo=None)
    window_start = now - timedelta(days=2)
    window_end = now + timedelta(days=2)
    sent: list[dict[str, Any]] = []

    for cal in data["calendars"]:
        if not cal.get("enabled", True):
            continue
        for ev in load_calendar_events(cal):
            for occ in expand_event(ev, window_start, window_end):
                for offset in occ.get("alerts") or []:
                    when = _event_fire_at(occ, int(offset))
                    if when > now:
                        continue
                    if now - when > timedelta(hours=12):
                        continue
                    occ_key = occ["start"].strftime("%Y%m%dT%H%M%S")
                    key = f"{occ.get('uid')}|{offset}|{occ_key}"
                    if key in keys:
                        continue
                    title = occ.get("title") or "Calendar event"
                    loc = occ.get("location") or ""
                    label = ALERT_LABELS.get(int(offset), f"{offset} minutes before")
                    body = label if not loc else f"{label}\n{loc}"
                    subprocess.run(
                        ["notify-send", "-a", "Yahr Calendar", "-u", "normal", title, body],
                        check=False,
                    )
                    keys.add(key)
                    sent.append({"key": key, "title": title, "offset": offset})

    # Keep the fired set from growing forever.
    if len(keys) > 4000:
        keys = set(list(keys)[-2000:])
    _save_json(FIRED, {"keys": sorted(keys)})
    json.dump({"sent": sent}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="calendar-store")
    sub = p.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("dump")
    d.add_argument("--start", default="")
    d.add_argument("--end", default="")
    d.set_defaults(func=cmd_dump)

    imp = sub.add_parser("import")
    imp.add_argument("path")
    imp.add_argument("--name", default="")
    imp.add_argument("--color", default="")
    imp.set_defaults(func=cmd_import)

    rm = sub.add_parser("remove")
    rm.add_argument("id")
    rm.set_defaults(func=cmd_remove)

    st = sub.add_parser("set-calendar")
    st.add_argument("id")
    st.add_argument("--name", default="")
    st.add_argument("--color", default="")
    st.add_argument("--enabled", default=None, choices=["true", "false"])
    st.set_defaults(func=cmd_set_calendar)

    add = sub.add_parser("add")
    add.add_argument("--calendar", default="personal")
    add.add_argument("--title", default="New event")
    add.add_argument("--start", required=True)
    add.add_argument("--end", default="")
    add.add_argument("--all-day", action="store_true")
    add.add_argument("--location", default="")
    add.add_argument("--alerts", default="")
    add.set_defaults(func=cmd_add)

    upd = sub.add_parser("update")
    upd.add_argument("--calendar", required=True)
    upd.add_argument("--uid", required=True)
    upd.add_argument("--title", default="New event")
    upd.add_argument("--start", required=True)
    upd.add_argument("--end", default="")
    upd.add_argument("--all-day", action="store_true")
    upd.add_argument("--location", default="")
    upd.add_argument("--alerts", default="")
    upd.set_defaults(func=cmd_update)

    delete = sub.add_parser("delete")
    delete.add_argument("--calendar", required=True)
    delete.add_argument("--uid", required=True)
    delete.set_defaults(func=cmd_delete)

    fire = sub.add_parser("fire-due")
    fire.set_defaults(func=cmd_fire_due)
    return p


def main() -> int:
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Read, conflict-check, and write Hyprland Lua keybinds for Yahr Keybinds."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
JSON_PATH = HOME / ".config" / "yahr" / "keybinds.json"
LIVE_LUA = HOME / ".config" / "hypr" / "keybinds.lua"
QS_SCRIPTS = HOME / ".config" / "quickshell" / "scripts"
IPC = str(QS_SCRIPTS / "yahr-ipc")
RESTART = str(QS_SCRIPTS / "restart-shell.sh")
QS_SCRIPTS_LUA = '/.config/quickshell/scripts'


def _repo_keybinds_lua() -> Path | None:
    """Mirror writes into a git checkout when developing; never invent ~/Projects."""
    env = os.environ.get("YAHR_REPO")
    if env:
        candidate = Path(env).expanduser() / "hypr" / "keybinds.lua"
        if candidate.parent.is_dir():
            return candidate
    root = Path(__file__).resolve().parents[2]
    candidate = root / "hypr" / "keybinds.lua"
    if candidate.resolve() == LIVE_LUA.resolve():
        return None
    if (root / "themes").is_dir() and (root / "theme-engine").is_dir():
        return candidate
    return None

MOD_ORDER = ("SUPER", "CTRL", "ALT", "SHIFT")
GROUP_ORDER = (
    "Applications",
    "Shell",
    "Windows",
    "Workspaces",
    "Mouse",
    "Media",
    "Display",
    "System",
    "Other",
)

LABELS = {
    ("exec", "ipc:toggleLauncher"): ("App launcher", "Shell"),
    ("exec", "ipc:togglePowerMenu"): ("Power menu", "Shell"),
    ("exec", "ipc:toggleThemeSwitcher"): ("Theme switcher", "Shell"),
    ("exec", "ipc:toggleWallpaper"): ("Wallpaper", "Shell"),
    ("exec", "ipc:toggleSettings"): ("Settings", "Shell"),
    ("exec", "ipc:toggleClipboard"): ("Clipboard", "Shell"),
    ("exec", "ipc:toggleAudio"): ("Control center", "Shell"),
    ("exec", "ipc:toggleInfoPanel"): ("Info panel", "Shell"),
    ("exec", "ipc:toggleCalendar"): ("Yahr Calendar", "Shell"),
    ("exec", "ipc:toggleCalculator"): ("Yahr Calculator", "Shell"),
    ("exec", "ipc:toggleKeybinds"): ("Yahr Keybinds", "Shell"),
    ("exec", "restart"): ("Restart Yahr Shell", "Shell"),
    ("exec", "ghostty"): ("Terminal", "Applications"),
    ("exec", "firefox"): ("Browser", "Applications"),
    ("exec", "nvim"): ("Editor", "Applications"),
    ("exec", "hyprlock"): ("Lock screen", "System"),
    ("exec", "hypremoji"): ("Emoji picker", "Applications"),
    ("exec", "makoctl restore"): ("Restore notifications", "Shell"),
    ("close", ""): ("Close window", "Windows"),
    ("exit", ""): ("Exit Hyprland", "Windows"),
    ("float", ""): ("Toggle floating", "Windows"),
    ("pseudo", ""): ("Pseudo-tile", "Windows"),
    ("special", "magic"): ("Scratchpad", "Workspaces"),
    ("move_special", "special:magic"): ("Move to scratchpad", "Workspaces"),
    ("drag", ""): ("Move window (mouse)", "Mouse"),
    ("resize", ""): ("Resize window (mouse)", "Mouse"),
    ("focus_ws", "e+1"): ("Next workspace (scroll)", "Mouse"),
    ("focus_ws", "e-1"): ("Previous workspace (scroll)", "Mouse"),
}

KEY_LABELS = {
    "XF86AudioRaiseVolume": ("Volume up", "Media"),
    "XF86AudioLowerVolume": ("Volume down", "Media"),
    "XF86AudioMute": ("Mute", "Media"),
    "XF86AudioMicMute": ("Mute microphone", "Media"),
    "XF86MonBrightnessUp": ("Brightness up", "Display"),
    "XF86MonBrightnessDown": ("Brightness down", "Display"),
    "XF86AudioNext": ("Next track", "Media"),
    "XF86AudioPause": ("Pause", "Media"),
    "XF86AudioPlay": ("Play", "Media"),
    "XF86AudioPrev": ("Previous track", "Media"),
    "Print": ("Screenshot (output)", "Shell"),
}

CMD_LABELS = {
    "hyprshot -m region --clipboard-only": ("Screenshot (region)", "Shell"),
    "hyprshot -m output --clipboard-only": ("Screenshot (output)", "Shell"),
}

KEY_CANON = {
    "left": "left",
    "right": "right",
    "up": "up",
    "down": "down",
    "return": "Return",
    "enter": "Return",
    "esc": "Escape",
    "escape": "Escape",
    "space": "space",
    "tab": "Tab",
    "period": "period",
    "comma": "comma",
    "minus": "minus",
    "equal": "equal",
    "slash": "slash",
    "backslash": "backslash",
    "print": "Print",
    "printscreen": "Print",
    "backspace": "BackSpace",
    "delete": "Delete",
}


def canonical_key(token: str) -> str:
    t = token.strip()
    if not t:
        return ""
    low = t.lower()
    if low in KEY_CANON:
        return KEY_CANON[low]
    if re.fullmatch(r"mouse:\d+", low) or low in ("mouse_up", "mouse_down"):
        return low
    if low.startswith("xf86"):
        return t if t.startswith("XF86") else t.upper().replace("XF86", "XF86")
    if low.startswith("switch:"):
        return t
    if re.fullmatch(r"f\d{1,2}", low):
        return t.upper()
    if len(t) == 1:
        return t.upper()
    return t


def normalize_combo(raw: str) -> str:
    s = (raw or "").strip()
    if not s:
        return ""
    if s.lower().startswith("switch:"):
        return s
    parts = [p.strip() for p in s.split("+") if p.strip()]
    mods: list[str] = []
    key = ""
    for p in parts:
        u = p.upper().replace("CONTROL", "CTRL").replace("MOD4", "SUPER").replace("META", "SUPER")
        if u in MOD_ORDER:
            if u not in mods:
                mods.append(u)
        else:
            key = canonical_key(p)
    ordered = [m for m in MOD_ORDER if m in mods]
    bits = ordered + ([key] if key else [])
    return " + ".join(bits)


def pretty_combo(combo: str) -> str:
    if not combo:
        return ""
    names = {"SUPER": "Super", "CTRL": "Ctrl", "ALT": "Alt", "SHIFT": "Shift"}
    return " + ".join(names.get(p, p) for p in combo.split(" + "))


def split_top(s: str, sep: str = ",") -> list[str]:
    out = []
    buf = []
    depth = 0
    quote = ""
    for ch in s:
        if quote:
            buf.append(ch)
            if ch == quote:
                quote = ""
            continue
        if ch in "\"'":
            quote = ch
            buf.append(ch)
            continue
        if ch in "({":
            depth += 1
            buf.append(ch)
            continue
        if ch in ")}":
            depth -= 1
            buf.append(ch)
            continue
        if ch == sep and depth == 0:
            out.append("".join(buf).strip())
            buf = []
            continue
        buf.append(ch)
    if buf:
        out.append("".join(buf).strip())
    return out


def unquote(s: str) -> str:
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        body = s[1:-1]
        if s[0] == '"':
            body = body.replace('\\"', '"').replace("\\\\", "\\")
        return body
    return s


def eval_lua_string(expr: str, env: dict[str, str], loop_i: int | None = None) -> str:
    expr = expr.strip()
    chunks = re.split(r"\s*\.\.\s*", expr)
    bits: list[str] = []
    for chunk in chunks:
        chunk = chunk.strip()
        if chunk == "MOD":
            bits.append(env.get("MOD", "SUPER"))
        elif chunk == "i" and loop_i is not None:
            bits.append(str(loop_i))
        elif chunk in env:
            bits.append(env[chunk])
        elif chunk.startswith("os.getenv"):
            m = re.search(r"os\.getenv\(\s*\"([^\"]+)\"\s*\)", chunk)
            bits.append(os.environ.get(m.group(1), "") if m else "")
        else:
            bits.append(unquote(chunk))
    return "".join(bits)


def parse_opts(blob: str | None) -> dict:
    opts = {"mouse": False, "locked": False, "repeating": False}
    if not blob:
        return opts
    if re.search(r"mouse\s*=\s*true", blob):
        opts["mouse"] = True
    if re.search(r"locked\s*=\s*true", blob):
        opts["locked"] = True
    if re.search(r"repeating\s*=\s*true", blob):
        opts["repeating"] = True
    return opts


def parse_action(action: str, env: dict[str, str], loop_i: int | None) -> dict:
    a = action.strip()
    if a.startswith("hl.dsp.exec_cmd"):
        inner = a[a.find("(") + 1 : a.rfind(")")]
        cmd = eval_lua_string(inner, env, loop_i).strip()
        if "yahr-ipc" in inner or inner.strip().startswith("ipc"):
            action = ""
            if ".." in inner:
                action = unquote(inner.split("..", 1)[-1].strip()).strip()
            elif cmd:
                action = cmd.split()[-1]
            return {
                "kind": "exec",
                "payload": f"ipc:{action}",
                "command": f"{IPC} {action}".strip(),
            }
        if cmd == RESTART or cmd.endswith("restart-shell.sh") or inner.strip() == "restart":
            return {"kind": "exec", "payload": "restart", "command": RESTART}
        return {"kind": "exec", "payload": cmd, "command": cmd}
    if "window.close" in a:
        return {"kind": "close", "payload": "", "command": ""}
    if a.startswith("hl.dsp.exit"):
        return {"kind": "exit", "payload": "", "command": ""}
    if "window.float" in a:
        return {"kind": "float", "payload": "", "command": ""}
    if "window.pseudo" in a:
        return {"kind": "pseudo", "payload": "", "command": ""}
    if "window.drag" in a:
        return {"kind": "drag", "payload": "", "command": ""}
    if "window.resize" in a:
        return {"kind": "resize", "payload": "", "command": ""}
    if "toggle_special" in a:
        m = re.search(r'toggle_special\(\s*"([^"]+)"', a)
        return {"kind": "special", "payload": m.group(1) if m else "magic", "command": ""}
    if "focus" in a and "direction" in a:
        m = re.search(r'direction\s*=\s*"([^"]+)"', a)
        return {"kind": "focus_dir", "payload": m.group(1) if m else "", "command": ""}
    if "window.move" in a and "workspace" in a:
        m = re.search(r'workspace\s*=\s*"([^"]+)"', a)
        if m:
            return {"kind": "move_special", "payload": m.group(1), "command": ""}
        m = re.search(r"workspace\s*=\s*([0-9]+|i)", a)
        val = str(loop_i) if m and m.group(1) == "i" else (m.group(1) if m else "")
        return {"kind": "move_ws", "payload": val, "command": ""}
    if "focus" in a and "workspace" in a:
        m = re.search(r'workspace\s*=\s*"([^"]+)"', a)
        if m:
            return {"kind": "focus_ws", "payload": m.group(1), "command": ""}
        m = re.search(r"workspace\s*=\s*([0-9]+|i)", a)
        val = str(loop_i) if m and m.group(1) == "i" else (m.group(1) if m else "")
        return {"kind": "focus_ws", "payload": val, "command": ""}
    return {"kind": "exec", "payload": a, "command": a}


def parse_locals(src: str) -> dict[str, str]:
    env = {"MOD": "SUPER", "HOME": str(HOME)}
    for m in re.finditer(
        r'local\s+(\w+)\s*=\s*(.+?)\s*$', src, re.M
    ):
        name, expr = m.group(1), m.group(2).strip()
        if name in ("ipc", "restart"):
            continue
        env[name] = eval_lua_string(expr, env)
    env["ipc"] = IPC
    env["restart"] = RESTART
    return env


def extract_bind_calls(src: str) -> list[tuple[str, int | None]]:
    """Return (call_inside_parens, loop_i) for each hl.bind."""
    calls: list[tuple[str, int | None]] = []
    loop_re = re.compile(r"for\s+i\s*=\s*1\s*,\s*9\s+do\s*(.*?)\s*end", re.S)
    used = [False] * len(src)

    def mark(span: tuple[int, int]) -> None:
        for i in range(span[0], span[1]):
            used[i] = True

    for m in loop_re.finditer(src):
        body = m.group(1)
        mark(m.span())
        for i in range(1, 10):
            for inner in iter_bind_inners(body):
                calls.append((inner, i))

    for inner, span in iter_bind_inners_spans(src):
        if any(used[i] for i in range(span[0], min(span[1], len(used)))):
            continue
        calls.append((inner, None))
    return calls


def iter_bind_inners(src: str) -> list[str]:
    return [inner for inner, _ in iter_bind_inners_spans(src)]


def iter_bind_inners_spans(src: str) -> list[tuple[str, tuple[int, int]]]:
    out: list[tuple[str, tuple[int, int]]] = []
    i = 0
    needle = "hl.bind("
    while True:
        j = src.find(needle, i)
        if j < 0:
            break
        start = j + len(needle)
        depth = 1
        k = start
        quote = ""
        while k < len(src) and depth:
            ch = src[k]
            if quote:
                if ch == "\\" and k + 1 < len(src):
                    k += 2
                    continue
                if ch == quote:
                    quote = ""
                k += 1
                continue
            if ch in "\"'":
                quote = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            k += 1
        out.append((src[start : k - 1], (j, k)))
        i = k
    return out


def fingerprint(kind: str, payload: str) -> str:
    if payload:
        return f"{kind}:{payload}"
    return kind


def describe(kind: str, payload: str, command: str, combo: str) -> tuple[str, str]:
    if command in CMD_LABELS:
        return CMD_LABELS[command]
    if (kind, payload) in LABELS:
        return LABELS[(kind, payload)]
    key = combo.split(" + ")[-1] if combo else ""
    if key in KEY_LABELS:
        return KEY_LABELS[key]
    if kind == "focus_dir":
        return (f"Focus {payload}", "Windows")
    if kind == "focus_ws":
        return (f"Workspace {payload}", "Workspaces")
    if kind == "move_ws":
        return (f"Move to workspace {payload}", "Workspaces")
    if kind == "exec":
        if payload.startswith("ipc:"):
            return (payload.split(":", 1)[1], "Shell")
        base = Path(command.split()[0]).name if command else payload
        if "launch-thunar" in command or base == "launch-thunar.sh":
            return ("File manager", "Applications")
        if "preview-sddm" in command:
            return ("SDDM preview", "Shell")
        if command.startswith("hyprctl keyword monitor"):
            if "disable" in command:
                return ("Lid close", "System")
            return ("Lid open", "System")
        return (base or "Custom command", "Applications")
    return (kind.replace("_", " ").title(), "Other")


def capture_mode(combo: str, kind: str) -> str:
    if combo.lower().startswith("switch:") or "mouse" in combo.lower() or kind in ("drag", "resize"):
        return "special"
    return "key"


def make_bind(kind: str, payload: str, command: str, combo: str, opts: dict, used_ids: set[str]) -> dict:
    base = fingerprint(kind, payload)
    ident = base
    n = 2
    while ident in used_ids:
        ident = f"{base}:{n}"
        n += 1
    used_ids.add(ident)
    label, group = describe(kind, payload, command, combo)
    return {
        "id": ident,
        "label": label,
        "group": group,
        "combo": combo,
        "kind": kind,
        "payload": payload,
        "command": command,
        "options": opts,
        "capture": capture_mode(combo, kind),
    }


def parse_lua(text: str) -> list[dict]:
    env = parse_locals(text)
    used: set[str] = set()
    binds: list[dict] = []
    for inner, loop_i in extract_bind_calls(text):
        args = split_top(inner)
        if len(args) < 2:
            continue
        combo = normalize_combo(eval_lua_string(args[0], env, loop_i))
        parsed = parse_action(args[1], env, loop_i)
        opts = parse_opts(args[2] if len(args) > 2 else None)
        binds.append(
            make_bind(parsed["kind"], parsed["payload"], parsed.get("command", ""), combo, opts, used)
        )
    return binds


def ensure_keybinds_app(binds: list[dict]) -> list[dict]:
    for b in binds:
        if b.get("payload") == "ipc:toggleKeybinds" or b.get("id", "").startswith("exec:ipc:toggleKeybinds"):
            return binds
    used = {b["id"] for b in binds}
    taken = {normalize_combo(b["combo"]) for b in binds if b.get("combo")}
    combo = "SUPER + K" if "SUPER + K" not in taken else ""
    binds.append(
        make_bind("exec", "ipc:toggleKeybinds", f"{IPC} toggleKeybinds", combo, parse_opts(None), used)
    )
    return binds


def conflicts(binds: list[dict]) -> list[dict]:
    seen: dict[str, str] = {}
    out = []
    for b in binds:
        c = normalize_combo(b.get("combo") or "")
        if not c:
            continue
        if c in seen:
            out.append(
                {
                    "combo": c,
                    "a": seen[c],
                    "b": b["id"],
                    "aLabel": next((x["label"] for x in binds if x["id"] == seen[c]), seen[c]),
                    "bLabel": b["label"],
                }
            )
        else:
            seen[c] = b["id"]
    return out


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def lua_string(s: str) -> str:
    if '"' in s and "'" not in s:
        return "'" + s.replace("\\", "\\\\") + "'"
    return '"' + lua_escape(s) + '"'


def combo_to_lua(combo: str) -> str:
    if combo.lower().startswith("switch:"):
        return f'"{lua_escape(combo)}"'
    parts = [p.strip() for p in combo.split(" + ") if p.strip()]
    if not parts:
        return '""'
    if parts[0] == "SUPER":
        rest = " + ".join(parts[1:])
        if rest:
            return f'MOD .. " + {lua_escape(rest)}"'
        return "MOD"
    return f'"{lua_escape(combo)}"'


def action_to_lua(bind: dict) -> str:
    kind = bind.get("kind") or "exec"
    payload = bind.get("payload") or ""
    command = bind.get("command") or ""
    if kind == "close":
        return "hl.dsp.window.close()"
    if kind == "exit":
        return "hl.dsp.exit()"
    if kind == "float":
        return 'hl.dsp.window.float({ action = "toggle" })'
    if kind == "pseudo":
        return "hl.dsp.window.pseudo()"
    if kind == "drag":
        return "hl.dsp.window.drag()"
    if kind == "resize":
        return "hl.dsp.window.resize()"
    if kind == "special":
        return f'hl.dsp.workspace.toggle_special("{lua_escape(payload or "magic")}")'
    if kind == "move_special":
        return f'hl.dsp.window.move({{ workspace = "{lua_escape(payload)}" }})'
    if kind == "focus_dir":
        return f'hl.dsp.focus({{ direction = "{lua_escape(payload)}" }})'
    if kind == "focus_ws":
        if re.fullmatch(r"\d+", str(payload)):
            return f"hl.dsp.focus({{ workspace = {payload} }})"
        return f'hl.dsp.focus({{ workspace = "{lua_escape(str(payload))}" }})'
    if kind == "move_ws":
        if re.fullmatch(r"\d+", str(payload)):
            return f"hl.dsp.window.move({{ workspace = {payload} }})"
        return f'hl.dsp.window.move({{ workspace = "{lua_escape(str(payload))}" }})'
    if payload.startswith("ipc:"):
        action = payload.split(":", 1)[1]
        return f'hl.dsp.exec_cmd(ipc .. " {lua_escape(action)}")'
    if payload == "restart" or command.endswith("restart-shell.sh"):
        return "hl.dsp.exec_cmd(restart)"
    cmd = command or payload
    if str(HOME) in cmd:
        rel = cmd.replace(str(HOME), "", 1)
        return f'hl.dsp.exec_cmd(os.getenv("HOME") .. {lua_string(rel)})'
    return f"hl.dsp.exec_cmd({lua_string(cmd)})"


def opts_to_lua(opts: dict | None) -> str:
    opts = opts or {}
    flags = []
    if opts.get("mouse"):
        flags.append("mouse = true")
    if opts.get("locked"):
        flags.append("locked = true")
    if opts.get("repeating"):
        flags.append("repeating = true")
    if not flags:
        return ""
    return "{ " + ", ".join(flags) + " }"


def generate_lua(binds: list[dict]) -> str:
    grouped: dict[str, list[dict]] = {g: [] for g in GROUP_ORDER}
    extra: dict[str, list[dict]] = {}
    for b in binds:
        if not normalize_combo(b.get("combo") or ""):
            continue
        g = b.get("group") or "Other"
        if g in grouped:
            grouped[g].append(b)
        else:
            extra.setdefault(g, []).append(b)

    lines = [
        "-- Keybindings. Written by Yahr Keybinds. Quickshell IPC target is `yahr`.",
        "",
        'local MOD = "SUPER"',
        f'local qs = os.getenv("HOME") .. "{QS_SCRIPTS_LUA}"',
        'local ipc = qs .. "/yahr-ipc"',
        'local restart = qs .. "/restart-shell.sh"',
        "",
    ]
    for group in list(GROUP_ORDER) + [g for g in extra if g not in GROUP_ORDER]:
        rows = grouped.get(group) or extra.get(group) or []
        if not rows:
            continue
        lines.append(f"-- {group}")
        for b in rows:
            combo = combo_to_lua(normalize_combo(b["combo"]))
            action = action_to_lua(b)
            opts = opts_to_lua(b.get("options"))
            if opts:
                lines.append(f"hl.bind({combo}, {action}, {opts})")
            else:
                lines.append(f"hl.bind({combo}, {action})")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def lua_candidates() -> list[Path]:
    out: list[Path] = []
    for p in (LIVE_LUA, _repo_keybinds_lua()):
        if p is not None and p.is_file() and p not in out:
            out.append(p)
    return out


def load_binds() -> list[dict]:
    if JSON_PATH.is_file():
        try:
            data = json.loads(JSON_PATH.read_text())
            binds = data.get("binds")
            if isinstance(binds, list) and binds:
                return ensure_keybinds_app(binds)
        except (OSError, json.JSONDecodeError):
            pass
    for path in lua_candidates():
        binds = parse_lua(path.read_text())
        if binds:
            return ensure_keybinds_app(binds)
    return ensure_keybinds_app([])


def dump() -> dict:
    binds = load_binds()
    for b in binds:
        b["combo"] = normalize_combo(b.get("combo") or "")
        b["pretty"] = pretty_combo(b["combo"]) or "Not set"
    return {
        "binds": binds,
        "conflicts": conflicts(binds),
        "luaPath": str(LIVE_LUA),
        "jsonPath": str(JSON_PATH),
    }


def apply(binds: list[dict], reload: bool = True) -> dict:
    cleaned = []
    used: set[str] = set()
    for b in binds:
        combo = normalize_combo(b.get("combo") or "")
        row = dict(b)
        row["combo"] = combo
        if not row.get("id"):
            row["id"] = make_bind(
                row.get("kind") or "exec",
                row.get("payload") or "",
                row.get("command") or "",
                combo,
                row.get("options") or parse_opts(None),
                used,
            )["id"]
        else:
            used.add(row["id"])
        cleaned.append(row)
    clashes = conflicts(cleaned)
    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps({"version": 1, "binds": cleaned}, indent=2) + "\n")
    lua = generate_lua(cleaned)
    LIVE_LUA.parent.mkdir(parents=True, exist_ok=True)
    LIVE_LUA.write_text(lua)
    repo_lua = _repo_keybinds_lua()
    if repo_lua is not None and repo_lua.parent.is_dir():
        repo_lua.write_text(lua)
    reloaded = False
    if reload:
        try:
            subprocess.run(["hyprctl", "reload"], check=False, capture_output=True, text=True)
            reloaded = True
        except OSError:
            reloaded = False
    return {
        "ok": True,
        "conflicts": clashes,
        "wrote": str(LIVE_LUA),
        "reloaded": reloaded,
        "count": sum(1 for b in cleaned if b.get("combo")),
    }


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "dump"
    if cmd == "dump":
        json.dump(dump(), sys.stdout)
        sys.stdout.write("\n")
        return 0
    if cmd == "apply":
        raw = ""
        if "--file" in sys.argv:
            path = sys.argv[sys.argv.index("--file") + 1]
            raw = Path(path).read_text()
        elif not sys.stdin.isatty():
            raw = sys.stdin.read()
        elif JSON_PATH.is_file():
            raw = JSON_PATH.read_text()
        data = json.loads(raw) if raw else {"binds": []}
        binds = data.get("binds") if isinstance(data, dict) else data
        json.dump(apply(binds or []), sys.stdout)
        sys.stdout.write("\n")
        return 0
    print("usage: keybinds-store.py dump|apply", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

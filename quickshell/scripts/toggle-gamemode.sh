#!/usr/bin/env bash
# Yahr Shell — Game Mode toggle.
# Reduces compositor overhead and blocks idle lock/suspend while gaming.
# Usage: toggle-gamemode.sh [toggle|on|off|status]
set -euo pipefail

STATE_DIR="${HOME}/.config/yahr"
STATE_FILE="${STATE_DIR}/gamemode"
SNAP_FILE="${STATE_DIR}/gamemode-snap"
SETTINGS_FILE="${STATE_DIR}/settings.json"

mkdir -p "$STATE_DIR"

is_on() {
    [[ -f "$STATE_FILE" ]] && [[ "$(tr -d '[:space:]' < "$STATE_FILE")" == "on" ]]
}

# Read a boolean from settings.json → hypr.<key>. Prints "true" or "false".
json_bool() {
    local key="$1" default="$2"
    python3 -c '
import json, sys
path, key, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(path))
    val = (data.get("hypr") or {}).get(key)
    if isinstance(val, bool):
        print("true" if val else "false")
    else:
        print(default)
except Exception:
    print(default)
' "$SETTINGS_FILE" "$key" "$default"
}

hypr_eval() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl eval "$1" >/dev/null 2>&1 || true
    fi
}

notify() {
    local title="$1" body="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Yahr Shell" -u low "$title" "$body" || true
    fi
}

current_power_profile() {
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl get 2>/dev/null || echo ""
    else
        echo ""
    fi
}

set_power_profile() {
    local profile="$1"
    [[ -n "$profile" ]] || return 0
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set "$profile" >/dev/null 2>&1 || true
    fi
}

hypridle_running() {
    pgrep -x hypridle >/dev/null 2>&1
}

stop_hypridle() {
    if hypridle_running; then
        pkill -x hypridle 2>/dev/null || true
    fi
}

start_hypridle() {
    if command -v hypridle >/dev/null 2>&1 && ! hypridle_running; then
        nohup hypridle >/dev/null 2>&1 &
    fi
}

write_snap() {
    local anim power idle="false"
    anim="$(json_bool animations true)"
    power="$(current_power_profile)"
    if hypridle_running; then
        idle="true"
    fi
    cat >"$SNAP_FILE" <<EOF
animations=${anim}
power_profile=${power}
hypridle=${idle}
EOF
}

read_snap() {
    local key="$1" default="$2" line
    [[ -f "$SNAP_FILE" ]] || { echo "$default"; return; }
    line="$(grep -E "^${key}=" "$SNAP_FILE" 2>/dev/null | head -1 || true)"
    if [[ -n "$line" ]]; then
        echo "${line#*=}"
    else
        echo "$default"
    fi
}

enable_gamemode() {
    if is_on; then
        echo "on"
        return 0
    fi
    write_snap

    hypr_eval 'hl.config({animations={enabled=false}})'
    # Drop decoration blur while gaming even if Settings has it on.
    hypr_eval 'hl.config({decoration={blur={enabled=false}}})'

    stop_hypridle
    set_power_profile performance

    printf 'on\n' >"$STATE_FILE"
    notify "Game Mode" "On — animations off, idle lock paused"
    echo "on"
}

disable_gamemode() {
    if ! is_on; then
        echo "off"
        return 0
    fi

    local anim power idle blur
    anim="$(read_snap animations true)"
    power="$(read_snap power_profile "")"
    idle="$(read_snap hypridle true)"

    if [[ "$anim" == "true" ]]; then
        hypr_eval 'hl.config({animations={enabled=true}})'
    else
        hypr_eval 'hl.config({animations={enabled=false}})'
    fi

    blur="$(json_bool blurEnabled false)"
    if [[ "$blur" == "true" ]]; then
        hypr_eval 'hl.config({decoration={blur={enabled=true}}})'
    else
        hypr_eval 'hl.config({decoration={blur={enabled=false}}})'
    fi

    if [[ "$idle" == "true" ]]; then
        start_hypridle
    fi

    if [[ -n "$power" ]]; then
        set_power_profile "$power"
    else
        set_power_profile balanced
    fi

    printf 'off\n' >"$STATE_FILE"
    rm -f "$SNAP_FILE"
    notify "Game Mode" "Off — desktop settings restored"
    echo "off"
}

status_gamemode() {
    if is_on; then
        echo "on"
    else
        # Create the state file so Quickshell FileView can watch it
        # for Super+Shift+G toggles as well as the Tools button.
        if [[ ! -f "$STATE_FILE" ]]; then
            printf 'off\n' >"$STATE_FILE"
        fi
        echo "off"
    fi
}

cmd="${1:-toggle}"
case "$cmd" in
    on|enable) enable_gamemode ;;
    off|disable) disable_gamemode ;;
    status) status_gamemode ;;
    toggle)
        if is_on; then
            disable_gamemode
        else
            enable_gamemode
        fi
        ;;
    *)
        echo "usage: $0 [toggle|on|off|status]" >&2
        exit 2
        ;;
esac

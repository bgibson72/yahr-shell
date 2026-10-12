#!/bin/bash
# Screenshot helper for the picker and Hyprland Print keybinds.
# Usage:
#   take-screenshot.sh MODE SAVE COPY LOCATION [DELAY]
#   take-screenshot.sh MODE --from-settings
#   take-screenshot.sh MODE          # same as --from-settings
# MODE: output (workspace) | window | region
# --from-settings reads ~/.config/yahr/settings.json (same prefs as the picker:
# save location, copy-to-clipboard, delay). Matches the widget by always saving.

MODE="${1:-}"
SETTINGS_FILE="${HOME}/.config/yahr/settings.json"

usage() {
    echo "Usage: $0 MODE [SAVE COPY LOCATION [DELAY] | --from-settings]" >&2
    exit 1
}

[ -n "$MODE" ] || usage

case "$MODE" in
    output|window|region) ;;
    *)
        echo "Unknown mode: $MODE" >&2
        exit 1
        ;;
esac

load_from_settings() {
    # Defaults match Settings.qml / ScreenshotPicker (always save).
    SAVE_TO_DISK="true"
    COPY_TO_CLIPBOARD="true"
    SAVE_LOCATION="${HOME}/Pictures/Screenshots"
    DELAY="0"

    if [ ! -f "$SETTINGS_FILE" ]; then
        return
    fi

    eval "$(python3 - "$SETTINGS_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except (OSError, json.JSONDecodeError):
    data = {}
s = data.get("screenshot") or {}

def sh_bool(value, default=True) -> str:
    if value is None:
        value = default
    return "true" if bool(value) else "false"

# Picker always saves; keybinds follow that even if saveToDisk is false.
save = True
copy = s.get("copyToClipboard", True)
loc = s.get("saveLocation", "~/Pictures/Screenshots") or "~/Pictures/Screenshots"
try:
    delay = int(s.get("delay", 0) or 0)
except (TypeError, ValueError):
    delay = 0
delay = max(0, min(5, delay))

print(f"SAVE_TO_DISK={sh_bool(save)}")
print(f"COPY_TO_CLIPBOARD={sh_bool(copy, True)}")
# JSON-quote so spaces / ~ expand correctly after eval + tilde expand.
print(f"SAVE_LOCATION={json.dumps(str(loc))}")
print(f"DELAY={delay}")
PY
)"
    SAVE_LOCATION="${SAVE_LOCATION/#\~/$HOME}"
}

if [ "${2:-}" = "--from-settings" ] || [ -z "${2:-}" ]; then
    load_from_settings
else
    SAVE_TO_DISK="$2"
    COPY_TO_CLIPBOARD="${3:-true}"
    SAVE_LOCATION="${4:-$HOME/Pictures/Screenshots}"
    SAVE_LOCATION="${SAVE_LOCATION/#\~/$HOME}"
    DELAY="${5:-0}"
fi

# Brief settle so a closing picker (or compositor focus change) is out of the way.
sleep 0.2

if [[ "$DELAY" =~ ^[0-5]$ ]] && [ "$DELAY" -gt 0 ]; then
    sleep "$DELAY"
fi

active_output_geometry() {
    local active_workspace monitors ws_id
    active_workspace=$(hyprctl -j activeworkspace) || return 1
    monitors=$(hyprctl -j monitors) || return 1
    ws_id=$(echo "$active_workspace" | jq -r '.id')
    echo "$monitors" | jq -r --argjson id "$ws_id" \
        'first(.[] | select(.activeWorkspace.id == $id)) | "\(.x),\(.y) \((.width / .scale | round))x\((.height / .scale | round))"'
}

run_hyprshot() {
    # Workspace (output) captures the active monitor without an interactive pick —
    # otherwise a delay feels like "nothing happened" while slurp waits for a click.
    if [ "$MODE" = "output" ]; then
        exec hyprshot -m output -m active "$@"
    else
        exec hyprshot -m "$MODE" "$@"
    fi
}

# Hyprshot always copies to the clipboard when saving to disk. When the user
# wants a file only, capture with grim after the same selection UX.
capture_save_only() {
    local geometry=""
    case "$MODE" in
        output)
            geometry=$(active_output_geometry) || exit 1
            ;;
        region)
            geometry=$(slurp -d) || exit 1
            ;;
        window)
            local monitors clients boxes
            monitors=$(hyprctl -j monitors)
            clients=$(hyprctl -j clients | jq -r '[.[] | select(.workspace.id | contains('$(echo "$monitors" | jq -r 'map(.activeWorkspace.id) | join(",")')'))]')
            boxes=$(echo "$clients" | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | cut -f1,2 -d' ')
            geometry=$(slurp -r <<< "$boxes") || exit 1
            ;;
    esac

    [ -n "$geometry" ] || exit 1
    mkdir -p "$SAVE_LOCATION"
    local outfile="$SAVE_LOCATION/$(date +'%Y-%m-%d-%H%M%S_hyprshot.png')"
    grim -g "$geometry" "$outfile" || exit 1
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Screenshot saved" "Image saved in ${outfile}" -i "$outfile" -a Hyprshot
    fi
}

if [ "$SAVE_TO_DISK" = "true" ] && [ "$COPY_TO_CLIPBOARD" = "true" ]; then
    mkdir -p "$SAVE_LOCATION"
    run_hyprshot -o "$SAVE_LOCATION"
fi

if [ "$SAVE_TO_DISK" = "false" ] && [ "$COPY_TO_CLIPBOARD" = "true" ]; then
    run_hyprshot --clipboard-only
fi

if [ "$SAVE_TO_DISK" = "true" ]; then
    capture_save_only
    exit 0
fi

echo "Nothing to do: enable save to disk and/or copy to clipboard" >&2
exit 1

#!/bin/bash
# Screenshot helper invoked by the shell's screenshot picker.
# Arguments: mode saveToDisk copyToClipboard saveLocation [delaySeconds]
#   mode: output (workspace) | window | region
#   delaySeconds: 0–5 (wait before interactive capture)

MODE="$1"
SAVE_TO_DISK="$2"
COPY_TO_CLIPBOARD="$3"
SAVE_LOCATION="${4/#\~/$HOME}"
DELAY="${5:-0}"

# Give the picker panel time to close so it doesn't end up in the shot,
# and so region/window selection isn't fighting the picker for input.
sleep 0.2

if [[ "$DELAY" =~ ^[0-5]$ ]] && [ "$DELAY" -gt 0 ]; then
    sleep "$DELAY"
fi

# Hyprshot always copies to the clipboard when saving to disk. When the user
# wants a file only, capture with grim after the same selection UX.
capture_save_only() {
    local geometry=""
    case "$MODE" in
        output)
            geometry=$(slurp -or) || exit 1
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
        *)
            echo "Unknown mode: $MODE" >&2
            exit 1
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
    exec hyprshot -m "$MODE" -o "$SAVE_LOCATION"
fi

if [ "$SAVE_TO_DISK" = "false" ] && [ "$COPY_TO_CLIPBOARD" = "true" ]; then
    exec hyprshot -m "$MODE" --clipboard-only
fi

if [ "$SAVE_TO_DISK" = "true" ]; then
    capture_save_only
    exit 0
fi

echo "Nothing to do: enable save to disk and/or copy to clipboard" >&2
exit 1

#!/bin/bash
# Screenshot helper invoked by the shell's screenshot picker.
# Arguments: mode saveToDisk copyToClipboard saveLocation
#   mode: output (workspace) | window | region

MODE="$1"
SAVE_TO_DISK="$2"
COPY_TO_CLIPBOARD="$3"
SAVE_LOCATION="${4/#\~/$HOME}"

# Give the picker panel time to close so it doesn't end up in the shot,
# and so region/window selection isn't fighting the picker for input.
sleep 0.2

CMD="hyprshot -m $MODE"

if [ "$SAVE_TO_DISK" = "true" ]; then
    mkdir -p "$SAVE_LOCATION"
    CMD="$CMD -o $SAVE_LOCATION"
fi

if [ "$SAVE_TO_DISK" = "false" ] && [ "$COPY_TO_CLIPBOARD" = "true" ]; then
    CMD="$CMD --clipboard-only"
fi

exec $CMD

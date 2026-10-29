#!/usr/bin/env bash
# Open a GUI NetworkManager settings app.
# Prefer nm-connection-editor (network-manager-applet); fall back to common DEs.
set -euo pipefail

env_file="${HOME}/.config/gtk-3.0/gtk-theme-env.sh"
if [[ -f "$env_file" ]]; then
    # shellcheck source=/dev/null
    source "$env_file"
fi

if command -v nm-connection-editor >/dev/null 2>&1; then
    exec nm-connection-editor "$@"
fi
if command -v nm-connection-editor.real >/dev/null 2>&1; then
    exec nm-connection-editor.real "$@"
fi
if command -v gnome-control-center >/dev/null 2>&1; then
    exec gnome-control-center wifi
fi
if command -v plasma-nm >/dev/null 2>&1; then
    exec plasma-nm
fi

notify-send -a "Yahr Shell" "Network settings" \
    "Install network-manager-applet for nm-connection-editor." 2>/dev/null || true
exit 1

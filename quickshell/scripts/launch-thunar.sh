#!/usr/bin/env bash
# Launch Thunar with the GTK theme written by yahr-theme apply.
# Hyprland-spawned apps often miss gsettings/xsettings, so export GTK_THEME.
set -euo pipefail

env_file="${HOME}/.config/gtk-3.0/gtk-theme-env.sh"
if [[ -f "$env_file" ]]; then
    # shellcheck source=/dev/null
    source "$env_file"
fi

exec thunar "$@"

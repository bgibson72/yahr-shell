#!/bin/bash
# Write WidgetOpacity in the installed YAHR SDDM theme.conf.
set -euo pipefail

val="${1:-}"
if [[ ! "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "BAD_VALUE"
    exit 1
fi

conf="/usr/share/sddm/themes/yahr-theme/theme.conf"
if [[ ! -f "$conf" ]]; then
    echo "MISSING_THEME"
    exit 1
fi

tmp="$(mktemp)"
sed "s/^WidgetOpacity=.*/WidgetOpacity=${val}/" "$conf" > "$tmp"
if sudo -n tee "$conf" < "$tmp" >/dev/null; then
    rm -f "$tmp"
    echo OK
    exit 0
fi
rm -f "$tmp"
echo FAIL
exit 1

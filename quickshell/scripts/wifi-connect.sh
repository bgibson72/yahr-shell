#!/usr/bin/env bash
# Connect to a Wi-Fi access point by SSID.
# Prefer activating a saved connection profile (fast AP switch); otherwise
# ask NetworkManager to associate to the scanned SSID.
set -euo pipefail

ssid="${1:-}"
if [[ -z "$ssid" ]]; then
    echo "usage: wifi-connect.sh SSID" >&2
    exit 2
fi

if ! command -v nmcli >/dev/null 2>&1; then
    echo "nmcli not found (install NetworkManager)" >&2
    exit 127
fi

# Unescape nmcli terse NAME fields (\: → :).
unescape() {
    printf '%s' "${1//\\:/:}"
}

saved=""
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # NAME:TYPE — TYPE is last field and never contains colons.
    type="${line##*:}"
    [[ "$type" == "802-11-wireless" ]] || continue
    name="$(unescape "${line%:"$type"}")"
    if [[ "$name" == "$ssid" ]]; then
        saved="$name"
        break
    fi
    profile_ssid="$(nmcli -g 802-11-wireless.ssid connection show id "$name" 2>/dev/null || true)"
    if [[ "$profile_ssid" == "$ssid" ]]; then
        saved="$name"
        break
    fi
done < <(nmcli -t -f NAME,TYPE connection show)

notify_fail() {
    local detail="${1:-Connection failed}"
    notify-send -a "Yahr Shell" "Wi-Fi" "$detail" 2>/dev/null || true
}

if [[ -n "$saved" ]]; then
    if nmcli -w 20 connection up id "$saved"; then
        exit 0
    fi
    notify_fail "Could not activate “$saved”"
    exit 1
fi

if nmcli -w 20 device wifi connect "$ssid"; then
    exit 0
fi

notify_fail "Could not connect to “$ssid”. Open Network settings if a password is needed."
exit 1

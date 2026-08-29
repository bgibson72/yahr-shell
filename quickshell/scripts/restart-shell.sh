#!/bin/bash
# qs is long-running. Super+Z starts a new copy of this script, which kills
# the previous qs; if we waited on qs in the foreground, that looked like a
# failed start and fired a mako notice every restart.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
self=$$

for pid in $(pgrep -f "/quickshell/scripts/restart-shell.sh" || true); do
    if [ "$pid" != "$self" ]; then
        kill -9 "$pid" 2>/dev/null || true
    fi
done

for pid in $(pgrep -x qs || true) $(pgrep -x quickshell || true); do
    kill "$pid" 2>/dev/null || true
done
sleep 0.4

nohup qs -p "$ROOT" >/dev/null 2>&1 &
qs_pid=$!
sleep 0.8
if ! kill -0 "$qs_pid" 2>/dev/null; then
    notify-send -u critical "Yahr Shell" "Failed to start. Check qs logs, or rebuild with: yay -S quickshell-git"
    exit 1
fi

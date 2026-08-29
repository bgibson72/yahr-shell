#!/bin/bash
# Install passwordless sudo for YAHR SDDM theme + avatar updates.
set -euo pipefail

SUDOERS_FILE="/etc/sudoers.d/sddm-sync-yahr"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/sddm-sync-sudoers"

if ! groups | grep -q '\bwheel\b'; then
    echo "ERROR: You must be in the wheel group to use sudo."
    echo "Add yourself with: sudo usermod -aG wheel $USER"
    exit 1
fi

if [[ ! -f "$SRC" ]]; then
    echo "ERROR: Missing $SRC"
    exit 1
fi

echo "Installing $SUDOERS_FILE…"
sudo cp "$SRC" "$SUDOERS_FILE"
sudo chmod 0440 "$SUDOERS_FILE"

if sudo visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
    echo "Sudoers configured. SDDM opacity and avatar copies can run without a password."
else
    echo "ERROR: visudo rejected the file; removing it."
    sudo rm -f "$SUDOERS_FILE"
    exit 1
fi

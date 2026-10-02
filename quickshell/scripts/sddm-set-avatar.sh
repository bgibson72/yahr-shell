#!/bin/bash
# Copy an image to ~/.face.icon and the SDDM faces directory so the login
# screen shows it instead of the first-letter placeholder.
set -euo pipefail

src="${1:-}"
if [[ -z "$src" || ! -f "$src" ]]; then
    echo "MISSING_FILE"
    exit 1
fi

user="${USER:-$(id -un)}"
cp "$src" "$HOME/.face.icon"
cp "$src" "$HOME/.face" 2>/dev/null || true

face_dir="/usr/share/sddm/faces"
# sudoers '*' does not match '/', so the source has to be a bare file name.
if (cd "$(dirname "$src")" && sudo -n cp "$(basename "$src")" "$face_dir/${user}.face.icon") 2>/dev/null; then
    echo OK
    exit 0
fi

echo HOME_ONLY
exit 0

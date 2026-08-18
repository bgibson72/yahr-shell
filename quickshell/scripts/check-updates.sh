#!/bin/bash
# Prints the combined count of pending pacman + AUR updates.

_checkCommandExists() {
    command -v "$1" >/dev/null 2>&1
}

check_lock_files() {
    local pacman_lock="/var/lib/pacman/db.lck"
    local checkup_lock="${TMPDIR:-/tmp}/checkup-db-${UID}/db.lck"

    local timeout=30
    local elapsed=0

    while [ -f "$pacman_lock" ] || [ -f "$checkup_lock" ]; do
        if [ $elapsed -ge $timeout ]; then
            echo "0"
            exit 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
}

if _checkCommandExists "pacman"; then
    check_lock_files

    aur_helper=""
    if _checkCommandExists "paru"; then
        aur_helper="paru"
    elif _checkCommandExists "yay"; then
        aur_helper="yay"
    fi

    if _checkCommandExists "checkupdates"; then
        updates_pacman=$(checkupdates 2>/dev/null | wc -l)
    else
        updates_pacman=$(pacman -Qu 2>/dev/null | wc -l)
    fi

    updates_aur=0
    if [ -n "$aur_helper" ]; then
        updates_aur=$($aur_helper -Qua 2>/dev/null | wc -l)
    fi

    updates=$((updates_pacman + updates_aur))
    echo "$updates"

elif _checkCommandExists "dnf"; then
    updates=$(dnf check-update -q 2>/dev/null | grep -c ^[a-z0-9])
    echo "$updates"
else
    echo "0"
fi

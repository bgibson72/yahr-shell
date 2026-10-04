-- Autostart

hl.on("hyprland.start", function()
    local home = os.getenv("HOME")

    -- Keep ~/.config/quickshell pointed at the git checkout when repo-root is set.
    -- A stale copied SettingsPanel.qml is why removed SDDM controls can still appear.
    -- Sync with --keep-running here: Hypr has not started qs yet on this event.
    hl.exec_cmd("bash -c 'ROOT=$(tr -d \"[:space:]\" < \"$HOME/.config/yahr/repo-root\" 2>/dev/null || true); SYNC=\"\"; [ -n \"$ROOT\" ] && [ -f \"$ROOT/quickshell/scripts/sync-quickshell-from-repo.py\" ] && SYNC=\"$ROOT/quickshell/scripts/sync-quickshell-from-repo.py\"; [ -z \"$SYNC\" ] && [ -f \"$HOME/.config/quickshell/scripts/sync-quickshell-from-repo.py\" ] && SYNC=\"$HOME/.config/quickshell/scripts/sync-quickshell-from-repo.py\"; [ -n \"$SYNC\" ] && python3 \"$SYNC\" --keep-running >/tmp/yahr-quickshell-sync.log 2>&1 || true'")

    -- Prefer the clone from repo-root, then the live config tree, then a common path.
    local candidates = {}
    local repo_root_file = io.open(home .. "/.config/yahr/repo-root", "r")
    if repo_root_file then
        local root = repo_root_file:read("*l")
        repo_root_file:close()
        if root and #root > 0 then
            candidates[#candidates + 1] = root .. "/quickshell"
        end
    end
    candidates[#candidates + 1] = home .. "/.config/quickshell"
    candidates[#candidates + 1] = home .. "/Projects/yahr-shell/quickshell"
    candidates[#candidates + 1] = home .. "/yahr-shell/quickshell"

    local started = false
    for _, yahr_qs in ipairs(candidates) do
        local qs_probe = io.open(yahr_qs .. "/shell.qml", "r")
        if qs_probe then
            qs_probe:close()
            hl.exec_cmd("qs -p " .. yahr_qs)
            started = true
            break
        end
    end
    if not started then
        hl.exec_cmd("quickshell")
    end
    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("bash -c 'if command -v awww-daemon >/dev/null; then awww-daemon; elif command -v swww-daemon >/dev/null; then swww-daemon; fi'")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("bash -c 'wp=$(cat ~/.config/yahr/last-wallpaper 2>/dev/null); [ -z \"$wp\" ] && wp=$(cat ~/.config/quickshell/last-wallpaper 2>/dev/null); [ -n \"$wp\" ] && [ -f \"$wp\" ] && (command -v awww >/dev/null && awww img \"$wp\" || swww img \"$wp\")'")
end)

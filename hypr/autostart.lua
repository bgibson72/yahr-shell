-- Autostart

hl.on("hyprland.start", function()
    local home = os.getenv("HOME")
    -- Prefer the installed config tree; fall back to a local clone for development.
    local candidates = {
        home .. "/.config/quickshell",
        home .. "/Projects/yahr-shell/quickshell",
    }
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

-- Autostart

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("swww-daemon")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("bash -c 'wp=$(cat ~/.config/yahr/last-wallpaper 2>/dev/null); [ -n \"$wp\" ] && [ -f \"$wp\" ] && swww img \"$wp\"'")
end)

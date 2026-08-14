-- Window and layer rules

local blur_enabled = true
local sf = io.open(os.getenv("HOME") .. "/.config/yahr/settings.json", "r")
if sf then
    local sc = sf:read("*a")
    sf:close()
    if sc:match('"blur"%s*:%s*false') then
        blur_enabled = false
    end
end

hl.layer_rule({ match = { namespace = "^quickshell" }, blur = blur_enabled })
hl.layer_rule({ match = { namespace = "^mako" }, blur = blur_enabled })
hl.layer_rule({ match = { namespace = "^yahr%-bar" }, blur = false })

hl.window_rule({ match = { title = "^(.*Hyprshot.*)$" }, float = true })
hl.window_rule({ match = { class = "^(org%.pulseaudio%.pavucontrol)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(nm%-connection%-editor)$" }, float = true, center = true, size = { 800, 600 } })

hl.window_rule({ match = { class = "^kitty$" }, opacity = "0.92 override 0.88 override" })
hl.window_rule({ match = { class = "^thunar$" }, opacity = "0.92 override 0.88 override" })

hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

hl.window_rule({
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

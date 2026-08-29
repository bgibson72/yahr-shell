-- Window and layer rules.
-- Blur and app-window opacity follow Settings > Hyprland via YAHR_SETTINGS
-- (parsed from ~/.config/yahr/settings.json in hyprland.lua).

local blur_enabled = YAHR_SETTINGS.blur == true

hl.layer_rule({ match = { namespace = "^quickshell" }, blur = blur_enabled })
hl.layer_rule({ match = { namespace = "^mako" }, blur = blur_enabled })
hl.layer_rule({ match = { namespace = "^yahr%-bar" }, blur = false })

-- File managers, terminals, and editors that actually composite with
-- window alpha. Ghostty is included here too: Hyprland's window opacity
-- is what you see immediately. Ghostty's own background-opacity is kept
-- at 1 so the two do not stack.
local opacity_apps = {
    { key = "thunar", class = "^thunar$" },
    { key = "xfce_thunar", class = "^org%.xfce%.thunar$" },
    { key = "ghostty", class = "^ghostty$" },
    { key = "ghostty_id", class = "^com\\.mitchellh\\.ghostty$" },
    { key = "code", class = "^code$" },
    { key = "code_oss", class = "^code%-oss$" },
    { key = "codium", class = "^[Cc]odium$" },
    { key = "vscodium", class = "^VSCodium$" },
    { key = "cursor", class = "^[Cc]ursor$" },
    { key = "zed", class = "^dev%.zed%.Zed$" },
    { key = "zed_short", class = "^zed$" },
}

_G.YAHR_OPACITY_RULES = _G.YAHR_OPACITY_RULES or {}

function _G.yahrApplyWindowOpacity(on, active)
    active = tonumber(active) or 0.92
    if active < 0.5 then active = 0.5 end
    if active > 1 then active = 1 end
    local inactive = math.max(0.40, active - 0.04)
    local gtk_op = "1 override 1 override"
    if on then
        gtk_op = string.format("%.2f override %.2f override", active, inactive)
    end
    for _, app in ipairs(opacity_apps) do
        local existing = YAHR_OPACITY_RULES[app.key]
        if existing and existing.set_enabled then
            existing:set_enabled(false)
        end
        YAHR_OPACITY_RULES[app.key] = hl.window_rule({
            name = "yahr-opacity-" .. app.key,
            match = { class = app.class },
            opacity = gtk_op,
        })
    end
end

yahrApplyWindowOpacity(
    YAHR_SETTINGS.window_transparent == true,
    YAHR_SETTINGS.window_opacity or 0.92
)

hl.window_rule({ match = { title = "^(.*Hyprshot.*)$" }, float = true })
hl.window_rule({ match = { title = "^(.*Waypaper.*)$" }, float = true })

hl.window_rule({ match = { class = "^(org%.pulseaudio%.pavucontrol)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(%.blueman-manager-wrapped)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(xfce4-power-manager-settings)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(nm%-connection%-editor)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { title = "^(HyprEmoji)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { title = "^(Pluck - Color Palette Extractor)$" }, float = true, center = true })

-- File Roller popups. Hyprland class matches are RE2, so dots in the
-- app id must be `\\.`. Lua `%.` is a literal percent sign and will
-- not match org.gnome.FileRoller.
hl.window_rule({
    match = { class = "^(org\\.gnome\\.FileRoller|file-roller)$", title = "^Extract" },
    float = true,
    center = true,
})
hl.window_rule({
    match = { class = "^(org\\.gnome\\.FileRoller|file-roller)$", modal = true },
    float = true,
    center = true,
})

local function yahrFloatExtract()
    -- Dispatch from window.open is overwritten when Hyprland finishes
    -- mapping the dialog as tiled. Run hyprctl after the map settles.
    hl.exec_cmd("sleep 0.2 && hyprctl dispatch 'hl.dsp.window.float({ action = \"set\", window = \"title:Extract\" })' && hyprctl dispatch 'hl.dsp.window.center({ window = \"title:Extract\" })'")
end

local function yahrMaybeFloatFileRollerPopup(w)
    if not w then return end
    local title = w.title or ""
    if title ~= "Extract" and not title:match("^Extract ") then
        return
    end
    yahrFloatExtract()
end

if _G.YAHR_FILE_ROLLER_TITLE_SUB and _G.YAHR_FILE_ROLLER_TITLE_SUB.remove then
    _G.YAHR_FILE_ROLLER_TITLE_SUB:remove()
end
if _G.YAHR_FILE_ROLLER_OPEN_SUB and _G.YAHR_FILE_ROLLER_OPEN_SUB.remove then
    _G.YAHR_FILE_ROLLER_OPEN_SUB:remove()
end
_G.YAHR_FILE_ROLLER_TITLE_SUB = hl.on("window.title", yahrMaybeFloatFileRollerPopup)
_G.YAHR_FILE_ROLLER_OPEN_SUB = hl.on("window.open", yahrMaybeFloatFileRollerPopup)

hl.window_rule({ match = { class = "^(feh)$" }, fullscreen = true })
hl.window_rule({
    match = { class = "sddm-greeter" },
    float = true,
    fullscreen = true,
    fullscreen_state = "2 2",
    rounding = 0,
    border_size = 0,
    decorate = false,
    no_shadow = true,
    no_anim = true,
})

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

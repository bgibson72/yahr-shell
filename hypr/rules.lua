-- Window and layer rules.
-- Blur and app-window opacity follow Settings > Hyprland via YAHR_SETTINGS
-- (parsed from ~/.config/yahr/settings.json in hyprland.lua).

local blur_enabled = YAHR_SETTINGS.blur == true

hl.layer_rule({ match = { namespace = "^quickshell" }, blur = blur_enabled })
hl.layer_rule({ match = { namespace = "^mako" }, blur = blur_enabled })
hl.layer_rule({ match = { namespace = "^yahr-bar" }, blur = false })

-- File managers, terminals, and editors that actually composite with
-- window alpha. Ghostty is included here too: Hyprland's window opacity
-- is what you see immediately. Ghostty's own background-opacity is kept
-- at 1 so the two do not stack.
--
-- Hyprland class matches are RE2 (not Lua patterns). Escape dots as `\\.`
-- and leave hyphens plain — `%.` / `%-` are literal percent signs and will
-- never match app ids like org.xfce.Thunar.
local opacity_apps = {
    { key = "thunar", class = "^[Tt]hunar$" },
    { key = "xfce_thunar", class = "^org\\.xfce\\.[Tt]hunar$" },
    { key = "ghostty", class = "^ghostty$" },
    { key = "ghostty_id", class = "^com\\.mitchellh\\.ghostty$" },
    { key = "code", class = "^code$" },
    { key = "code_oss", class = "^code-oss$" },
    { key = "codium", class = "^[Cc]odium$" },
    { key = "vscodium", class = "^VSCodium$" },
    { key = "cursor", class = "^[Cc]ursor$" },
    { key = "zed", class = "^dev\\.zed\\.Zed$" },
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

hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(\\.blueman-manager-wrapped)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(xfce4-power-manager-settings)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { title = "^(HyprEmoji)$" }, float = true, center = true, size = { 800, 600 } })
hl.window_rule({ match = { title = "^(Pluck - Color Palette Extractor)$" }, float = true, center = true })

-- File Roller popups (same RE2 class escaping as opacity_apps above).
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

-- Thunar rename dialog (F2). Title is `Rename "filename"`. Wayland app
-- id is `org.xfce.Thunar` (capital T) — same RE2 class pattern as
-- opacity_apps.
--
-- GTK maps the dialog as a large tiled window first. Floating without an
-- explicit target can hit the main Thunar window instead, leaving the
-- rename dialog fullscreen underneath. Always target by window object or
-- title, then resize (tile geometry sticks after float), center, focus,
-- and raise.
local thunar_class = "^([Tt]hunar|org\\.xfce\\.[Tt]hunar)$"
local thunar_rename_w = 480
local thunar_rename_h = 170
hl.window_rule({
    match = { class = thunar_class, title = "^Rename" },
    float = true,
    center = true,
    size = { thunar_rename_w, thunar_rename_h },
    max_size = { 560, 220 },
    stay_focused = true,
})
hl.window_rule({
    match = { class = thunar_class, modal = true },
    float = true,
    center = true,
    stay_focused = true,
})

local function yahrIsThunarClass(class)
    if not class or class == "" then
        return false
    end
    class = string.lower(class)
    return class == "thunar" or class == "org.xfce.thunar"
end

local function yahrThunarRenameSelector(w)
    -- Prefer the event window object; fall back to title regex.
    if w ~= nil then
        return w
    end
    return "title:^(Rename)"
end

local function yahrPlaceThunarRename(w)
    local sel = yahrThunarRenameSelector(w)
    hl.dispatch(hl.dsp.window.float({ action = "set", window = sel }))
    -- Compact dialog size — floating a just-tiled GTK dialog keeps the
    -- monitor/tile geometry unless we resize after float.
    hl.dispatch(hl.dsp.window.resize({
        x = thunar_rename_w,
        y = thunar_rename_h,
        relative = false,
        window = sel,
    }))
    hl.dispatch(hl.dsp.window.center({ window = sel }))
    hl.dispatch(hl.dsp.focus({ window = sel }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = sel }))
end

local function yahrMaybeFloatThunarRename(w)
    if not w then return end
    local title = w.title or w.initialTitle or ""
    if not title:match("^Rename") then
        return
    end
    -- Title `Rename …` is Thunar-specific; if class is present, require it
    -- (case-insensitive — org.xfce.Thunar vs org.xfce.thunar).
    local class = w.class or w.initialClass or w.initial_class or ""
    if class ~= "" and not yahrIsThunarClass(class) then
        return
    end
    yahrPlaceThunarRename(w)
    -- Map settle can overwrite float/size; re-place by title once settled.
    hl.timer(function()
        yahrPlaceThunarRename("title:^(Rename)")
    end, { timeout = 200, type = "oneshot" })
end

if _G.YAHR_THUNAR_RENAME_TITLE_SUB and _G.YAHR_THUNAR_RENAME_TITLE_SUB.remove then
    _G.YAHR_THUNAR_RENAME_TITLE_SUB:remove()
end
if _G.YAHR_THUNAR_RENAME_OPEN_SUB and _G.YAHR_THUNAR_RENAME_OPEN_SUB.remove then
    _G.YAHR_THUNAR_RENAME_OPEN_SUB:remove()
end
_G.YAHR_THUNAR_RENAME_TITLE_SUB = hl.on("window.title", yahrMaybeFloatThunarRename)
_G.YAHR_THUNAR_RENAME_OPEN_SUB = hl.on("window.open", yahrMaybeFloatThunarRename)

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

-- ============================================================
-- Gaming — Steam / gamescope / common launchers
-- Tag games, then apply performance effects to the tag. Do not
-- force fullscreen: borderless-windowed is a common preference.
-- Tearing needs general.allow_tearing (appearance.lua) + immediate.
-- ============================================================

-- Steam Proton / native titles (class steam_app_<AppID>).
hl.window_rule({
    name = "yahr-tag-steam-game",
    match = { class = "^steam_app_" },
    tag = "+game",
    content = "game",
})

-- gamescope compositor (Steam Deck / nested gaming).
hl.window_rule({
    name = "yahr-tag-gamescope",
    match = { class = "^(gamescope|[Gg]amescope)$" },
    tag = "+game",
    content = "game",
})

-- Effects for anything tagged `game` / `game*`.
hl.window_rule({
    name = "yahr-game-perf",
    match = { tag = "game" },
    immediate = true,
    idle_inhibit = "focus",
    no_anim = true,
    no_blur = true,
})

-- Steam client chrome (not games) — float utility windows.
hl.window_rule({
    name = "yahr-steam-friends",
    match = { class = "^([Ss]team)$", title = "^(Friends List)$" },
    float = true,
})
hl.window_rule({
    name = "yahr-steam-settings",
    match = { class = "^([Ss]team)$", title = "^(Steam Settings)$" },
    float = true,
    center = true,
})
hl.window_rule({
    name = "yahr-steam-news",
    match = { class = "^([Ss]team)$", title = "^(Steam - News)$" },
    float = true,
    center = true,
})

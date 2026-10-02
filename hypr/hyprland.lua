-- ============================================================
-- Yahr Shell — Hyprland (Lua, requires Hyprland ≥ 0.55)
-- Theme colors live in theme.lua, written by `yahr-theme apply`.
-- ============================================================

local home = os.getenv("HOME")
local themePath = home .. "/.config/hypr/theme.lua"

local ok, theme = pcall(dofile, themePath)
if not ok or type(theme) ~= "table" then
    theme = {
        accent_blue = "rgb(89b4fa)",
        glass_accent = "rgba(89b4fa59)",
        fg_primary = "rgb(cdd6f4)",
        bg_base = "rgb(1e1e2e)",
        border_0 = "rgb(6c7086)",
    }
end

_G.HYPR_THEME = theme

-- Parse ~/.config/yahr/settings.json once. Nested objects are extracted
-- with %b{} so dock.rounding is not confused with hypr.rounding.
local function json_block(src, key)
    return src:match('"' .. key .. '"%s*:%s*(%b{})') or ""
end

local function json_num(block, key, default)
    local v = block:match('"' .. key .. '"%s*:%s*([%-%d%.]+)')
    return v and tonumber(v) or default
end

local function json_bool(block, key, default)
    local v = block:match('"' .. key .. '"%s*:%s*(%l+)')
    if v == "true" then return true end
    if v == "false" then return false end
    return default
end

local function json_str(block, key, default)
    return block:match('"' .. key .. '"%s*:%s*"([^"]*)"') or default
end

local settings = {
    rounding = 12,
    blur = false,
    border_size = 3,
    show_border = false,
    border_transparent = true,
    border_transparency = 65,
    border_fill = "gradient",
    border_angle = 45,
    border_animation = "none",
    gaps_in = 10,
    gaps_out = 10,
    animations = true,
    shadow_preset = "off",
    shadow_range = 20,
    shadow_alpha = 33,
    shadow_use_accent = false,
    blur_enabled = false,
    blur_size = 10,
    window_transparent = false,
    window_opacity = 0.92,
    bar_style = "single",
    bar_floating = false,
    bar_position = "top",
    dock_enabled = true,
    dock_floating = true,
    dock_span = false,
    dock_position = "bottom",
}

local sf = io.open(home .. "/.config/yahr/settings.json", "r")
if sf then
    local sc = sf:read("*a")
    sf:close()
    local general = json_block(sc, "general")
    local hypr = json_block(sc, "hypr")

    if json_bool(general, "blur", false) == false then
        settings.blur = false
    end

    settings.rounding = json_num(hypr, "rounding", settings.rounding)
    settings.border_size = json_num(hypr, "borderSize", settings.border_size)
    settings.show_border = json_bool(hypr, "showBorder", settings.show_border)
    settings.border_transparent = json_bool(hypr, "borderTransparent", settings.border_transparent)
    settings.border_transparency = json_num(hypr, "borderTransparency", settings.border_transparency)
    settings.border_fill = json_str(hypr, "borderFill", settings.border_fill)
    settings.border_angle = json_num(hypr, "borderAngle", settings.border_angle)
    settings.border_animation = json_str(hypr, "borderAnimation", settings.border_animation)
    settings.gaps_in = json_num(hypr, "gapsIn", settings.gaps_in)
    settings.gaps_out = json_num(hypr, "gapsOut", settings.gaps_out)
    settings.animations = json_bool(hypr, "animations", settings.animations)
    settings.shadow_preset = json_str(hypr, "shadowPreset", settings.shadow_preset)
    settings.shadow_range = json_num(hypr, "shadowRange", settings.shadow_range)
    settings.shadow_alpha = json_num(hypr, "shadowAlpha", settings.shadow_alpha)
    settings.shadow_use_accent = json_bool(hypr, "shadowUseAccent", settings.shadow_use_accent)
    settings.blur_enabled = json_bool(hypr, "blurEnabled", json_bool(general, "blur", false))
    settings.blur_size = json_num(hypr, "blurSize", settings.blur_size)
    settings.blur = settings.blur_enabled
    settings.window_transparent = json_bool(hypr, "windowTransparent", settings.window_transparent)
    settings.window_opacity = json_num(hypr, "windowOpacity", settings.window_opacity)

    local bar = json_block(sc, "bar")
    settings.bar_style = json_str(bar, "barStyle", settings.bar_style)
    settings.bar_floating = json_bool(bar, "floating", settings.bar_floating)
    settings.bar_position = json_str(bar, "position", settings.bar_position)

    local dock = json_block(sc, "dock")
    settings.dock_enabled = json_bool(dock, "enabled", settings.dock_enabled)
    settings.dock_floating = json_bool(dock, "floating", settings.dock_floating)
    settings.dock_span = json_bool(dock, "spanFullWidth", settings.dock_span)
    settings.dock_position = json_str(dock, "position", settings.dock_position)
end
_G.YAHR_SETTINGS = settings

-- Lua caches require(). hyprctl reload re-runs this file but would
-- otherwise skip every split module until Hyprland itself restarts.
for _, mod in ipairs({
    "variables", "monitors", "autostart", "appearance",
    "input", "keybinds", "rules",
}) do
    package.loaded[mod] = nil
end

require("variables")
require("monitors")
require("autostart")
require("appearance")
require("input")
require("keybinds")
require("rules")

-- The installer writes this only on NVIDIA machines.
local nvidia_lua = home .. "/.config/hypr/nvidia.lua"
local nvidia_f = io.open(nvidia_lua, "r")
if nvidia_f then
    nvidia_f:close()
    dofile(nvidia_lua)
end

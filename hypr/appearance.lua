-- Look and feel. Colors come from HYPR_THEME (hypr/theme.lua).
-- Numeric/toggle prefs come from YAHR_SETTINGS (settings.json).

local theme = HYPR_THEME
local s = YAHR_SETTINGS

local function hex6(color)
    return (color or ""):match("%((%x%x%x%x%x%x)") or "89b4fa"
end

local function ahex(opacity_pct)
    local n = math.floor(math.max(0, math.min(255, (opacity_pct / 100) * 255)) + 0.5)
    return string.format("%02x", n)
end

local opacity = 100
if s.border_transparent then
    opacity = math.max(0, math.min(100, 100 - (s.border_transparency or 0)))
end

local accent = hex6(theme.accent_blue)
local border0 = hex6(theme.border_0)
local angle = tonumber(s.border_angle) or 45

local active_border
local inactive_border
if s.border_fill == "solid" then
    active_border = "rgba(" .. accent .. ahex(opacity) .. ")"
    inactive_border = "rgba(" .. border0 .. ahex(opacity * 0.5) .. ")"
else
    local scale = opacity / 100
    active_border = {
        colors = {
            "rgba(000000" .. ahex(25 * scale) .. ")",
            "rgba(" .. accent .. ahex(35 * scale) .. ")",
            "rgba(ffffff" .. ahex(15 * scale) .. ")",
        },
        angle = angle,
    }
    inactive_border = {
        colors = {
            "rgba(000000" .. ahex(10 * scale) .. ")",
            "rgba(ffffff" .. ahex(7 * scale) .. ")",
        },
        angle = angle,
    }
end

local shadow_on = s.shadow_preset ~= "off"
local shadow_rgb = s.shadow_use_accent and accent or "000000"
local shadow_a = ahex(s.shadow_alpha or 33)

local frame = s.bar_style == "single" and s.bar_floating == false
local bezel = math.max(10, tonumber(s.gaps_out) or 10)
local inner = 8
local gaps_out = s.gaps_out or 10
local rounding = s.rounding or 12
if frame then
    rounding = s.rounding or 12
    if s.bar_position == "bottom" then
        gaps_out = { top = bezel + inner, right = bezel + inner, bottom = inner, left = bezel + inner }
    else
        gaps_out = { top = inner, right = bezel + inner, bottom = bezel + inner, left = bezel + inner }
    end
    if s.dock_enabled and s.dock_floating == false and s.dock_span then
        if s.dock_position == "bottom" then
            gaps_out.bottom = inner
        elseif s.dock_position == "left" then
            gaps_out.left = inner
        elseif s.dock_position == "right" then
            gaps_out.right = inner
        elseif s.dock_position == "top" then
            gaps_out.top = inner
        end
    end
end

hl.config({
    general = {
        gaps_in = s.gaps_in or 10,
        gaps_out = gaps_out,
        border_size = (s.show_border == false) and 0 or (s.border_size or 3),
        col = {
            active_border = active_border,
            inactive_border = inactive_border,
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = rounding,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = shadow_on,
            range = s.shadow_range or 20,
            render_power = 2,
            color = "rgba(" .. shadow_rgb .. shadow_a .. ")",
        },
        blur = {
            enabled = s.blur_enabled == true,
            size = s.blur_size or 10,
            passes = 4,
            new_optimizations = true,
            noise = 0.01,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = s.animations ~= false,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },

    cursor = {
        enable_hyprcursor = true,
        sync_gsettings_theme = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

local anim = s.animations ~= false
hl.animation({ leaf = "global", enabled = anim, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = anim, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = anim, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = anim, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = anim, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = anim, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = anim, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = anim, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = anim, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = anim, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = anim, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = anim, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = anim, speed = 7, bezier = "quick" })

local border_anim = s.border_fill == "gradient" and (s.border_animation or "none") or "none"
if border_anim == "none" then
    hl.animation({ leaf = "borderangle", enabled = false })
else
    hl.animation({
        leaf = "borderangle",
        enabled = true,
        speed = border_anim == "loop" and 30 or 8,
        bezier = "linear",
        style = border_anim,
    })
end

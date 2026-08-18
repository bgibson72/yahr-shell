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
    }
end

_G.HYPR_THEME = theme

-- Yahr settings.json — read once here, shared via _G so every module
-- avoids its own file I/O + regex parse.
local settings = { rounding = 12, blur = true }
local sf = io.open(home .. "/.config/yahr/settings.json", "r")
if sf then
    local sc = sf:read("*a")
    sf:close()
    local r = sc:match('"rounding"%s*:%s*(%d+)')
    if r then settings.rounding = tonumber(r) end
    if sc:match('"blur"%s*:%s*false') then
        settings.blur = false
    end
end
_G.YAHR_SETTINGS = settings

require("variables")
require("monitors")
require("autostart")
require("appearance")
require("input")
require("keybinds")
require("rules")

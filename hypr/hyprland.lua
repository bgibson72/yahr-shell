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

require("variables")
require("monitors")
require("autostart")
require("appearance")
require("input")
require("keybinds")
require("rules")

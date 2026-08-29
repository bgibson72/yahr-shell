-- Environment variables

local cursor = "Bibata-Modern-Ice"
local cf = io.open(os.getenv("HOME") .. "/.config/yahr/current.json", "r")
if cf then
    local text = cf:read("*a")
    cf:close()
    if text and text:match('"mode"%s*:%s*"light"') then
        cursor = "Bibata-Modern-Classic"
    end
end
hl.env("XCURSOR_THEME", cursor)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", cursor)
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
local path = os.getenv("PATH") or "/usr/bin"
local local_bin = os.getenv("HOME") .. "/.local/bin"
if not path:find(local_bin, 1, true) then
    hl.env("PATH", local_bin .. ":" .. path)
end

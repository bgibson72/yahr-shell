-- Keybindings. Quickshell IPC target is `yahr`.

local MOD = "SUPER"
local ipc = os.getenv("HOME") .. "/.config/quickshell/scripts/yahr-ipc"

hl.bind(MOD .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(MOD .. " + F", hl.dsp.exec_cmd("thunar"))
hl.bind(MOD .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(MOD .. " + A", hl.dsp.exec_cmd(ipc .. " toggleLauncher"))
hl.bind(MOD .. " + Escape", hl.dsp.exec_cmd(ipc .. " togglePowerMenu"))
hl.bind(MOD .. " + T", hl.dsp.exec_cmd(ipc .. " toggleThemeSwitcher"))
hl.bind(MOD .. " + N", hl.dsp.exec_cmd("makoctl restore"))
hl.bind(MOD .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(MOD .. " + Q", hl.dsp.window.close())
hl.bind(MOD .. " + M", hl.dsp.exit())
hl.bind(MOD .. " + P", hl.dsp.window.pseudo())

hl.bind(MOD .. " + SHIFT + W", hl.dsp.exec_cmd(ipc .. " toggleWallpaper"))
hl.bind(MOD .. " + SHIFT + S", hl.dsp.exec_cmd(ipc .. " toggleSettings"))
hl.bind(MOD .. " + SHIFT + V", hl.dsp.exec_cmd(ipc .. " toggleClipboard"))
hl.bind(MOD .. " + SHIFT + C", hl.dsp.exec_cmd(ipc .. " toggleControlCenter"))

hl.bind(MOD .. " + Print", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))

hl.bind(MOD .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(MOD .. " + Z", hl.dsp.exec_cmd("killall quickshell; quickshell"))

hl.bind(MOD .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(MOD .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(MOD .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(MOD .. " + down", hl.dsp.focus({ direction = "down" }))

for i = 1, 9 do
    hl.bind(MOD .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(MOD .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(MOD .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(MOD .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind(MOD .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(MOD .. " + SHIFT + X", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(MOD .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(MOD .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(MOD .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(MOD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

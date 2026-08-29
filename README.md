# Yahr Shell

Hyprland + Quickshell desktop for Arch Linux, built around one theme engine.

Switch between bundled palettes (Catppuccin, Dracula, Nord, …) or save your own colors. The same palette drives Hyprland borders, Quickshell widgets, GTK (Thunar), Papirus folder colors, Ghostty, Starship, Mako, Hyprlock, and Qt.

## Features

- **13 dark + 13 light bundled palettes** plus a custom theme creator (background + 8 accents)
- **One command apply** — `yahr-theme apply catppuccin` rewrites every target without restarting Quickshell
- **Quickshell desktop** — bar, dock, app launcher, control center, power menu, wallpaper picker, clipboard
- **Daily-driver installer** — GPU drivers, compositor, shell, file manager, notifications, lock screen

## Install

From a minimal Arch install:

```bash
git clone https://github.com/bgibson72/yahr-shell.git
cd yahr-shell
./install.sh
```

Flags:

- `--yolo` — unattended core install
- `--minimal` — skip optional packages (Firefox, Blueman, …)

Log in on TTY1 (the installer can add this) or run `Hyprland`. There is no display manager in v1.

## Theming

```bash
yahr-theme list
yahr-theme apply dracula
yahr-theme save --name Dusk --bg 1e1e2e --blue 89b4fa --purple cba6f7 \
  --pink f5c2e7 --red f38ba8 --orange fab387 --yellow f9e2af --green a6e3a1 --teal 94e2d5
yahr-theme delete dusk
```

In the shell: **Super+T** opens the theme switcher. Settings → Theme has the color editor (Save & Apply). Right-click a custom theme card to delete it.

Palettes are JSON in `themes/` (bundled) and `~/.config/yahr/themes/` (yours). `~/.config/yahr/current.json` is what Quickshell watches, so colors update live.

## Keybinds

| Bind | Action |
| --- | --- |
| Super+Return | Terminal (Ghostty) |
| Super+A | App launcher |
| Super+T | Theme switcher |
| Super+F | Thunar |
| Super+Escape | Power menu |
| Super+L | Lock (Hyprlock) |
| Super+Shift+S | Settings |
| Super+Shift+W | Settings → Wallpaper |
| Super+Shift+V | Clipboard |
| Super+Shift+C | Control center |
| Super+Print | Region screenshot |

## Layout

```
themes/            bundled palettes (JSON)
theme-engine/      yahr-theme CLI (Python, stdlib only)
hypr/              Lua config (Hyprland ≥ 0.55) + generated theme.lua
quickshell/        modular QML shell
ghostty/ mako/ thunar/
wallpapers/        per-theme folders, copied to ~/Pictures/Wallpapers
```

## Stack

Hyprland (Lua) · Quickshell · Ghostty · Mako · Thunar · Papirus · swww · adw-gtk3 · qt6ct

Nautilus is not used: libadwaita only follows accent color reliably. Thunar plus generated GTK CSS actually recolors the file manager.

## License

Use and remix freely. Successor to [yahr-quickshell](https://github.com/bgibson72/yahr-quickshell).

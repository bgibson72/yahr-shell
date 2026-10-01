# Yahr Shell

Hyprland + Quickshell desktop for Arch Linux, built around one theme engine.

Switch between bundled palettes (Catppuccin, Dracula, Nord, …) or save your own colors. The same palette drives Hyprland borders, Quickshell widgets, GTK (Thunar), Papirus folder colors, Ghostty, Mako, Hyprlock, SDDM, and Qt.

This is the successor to [yahr-quickshell](https://github.com/bgibson72/yahr-quickshell), which is archived.

## Features

- **13 dark + 13 light bundled palettes** plus a custom theme creator (background + 8 accents)
- **One command apply** — `yahr-theme apply catppuccin` rewrites every target without restarting Quickshell
- **Quickshell desktop** — bar, dock, app launcher, settings, power menu, clipboard, screenshots, network / bluetooth / audio / battery panels
- **Yahr apps** — Calendar (ICS + reminders), Calculator, and Keybinds (live map with conflict checks, writes Hyprland Lua)
- **Unattended installer** — `./install.sh` on a minimal Arch install sets up the desktop, fonts, themes, wallpapers, and greeter

## Install

From a minimal Arch install (with or without Hyprland already present):

```bash
git clone https://github.com/bgibson72/yahr-shell.git
cd yahr-shell
./install.sh
```

The installer does not ask questions. It installs the desktop, fonts, bundled themes, wallpapers, and the SDDM greeter, then you reboot and sign in. It detects this clone’s path and your `$HOME` — it does not assume `~/Projects/yahr-shell` or a fixed username. Configs are copied into `~/.config/{hypr,quickshell,…}`; themes and the theme engine land under `~/.local/share/yahr-shell/`. Wallpapers are copied to `~/Pictures/Wallpapers`.

Flags:

- `--minimal` — skip Firefox (the shell, fonts, themes, and greeter are still installed)
- `--skip-packages` — refresh configs, themes, and wallpapers only
- `--print-plan` — print the package list and exit

## Theming

```bash
yahr-theme list
yahr-theme apply dracula
yahr-theme save --name Dusk --bg 1e1e2e --blue 89b4fa --purple cba6f7 \
  --pink f5c2e7 --red f38ba8 --orange fab387 --yellow f9e2af --green a6e3a1 --teal 94e2d5
yahr-theme delete dusk
```

**Super+T** opens the theme switcher. Settings → Theme has the color editor (Save & Apply). Right-click a custom theme card to delete it.

Palettes are JSON in `themes/` (bundled) and `~/.config/yahr/themes/` (yours). `~/.config/yahr/current.json` is what Quickshell watches, so colors update live.

## Keybinds

Defaults from `hypr/keybinds.lua`. **Super+K** opens Yahr Keybinds to view or change them.

| Bind | Action |
| --- | --- |
| Super+Return | Terminal (Ghostty) |
| Super+A | App launcher |
| Super+T | Theme switcher |
| Super+F | Thunar |
| Super+Escape | Power menu |
| Super+L | Lock (Hyprlock) |
| Super+K | Yahr Keybinds |
| Super+Z | Restart Yahr Shell |
| Super+Shift+S | Settings |
| Super+Shift+W | Settings → Wallpaper |
| Super+Shift+V | Clipboard |
| Super+Shift+C | Control center |
| Super+Print | Region screenshot |
| Print | Output screenshot |

Calendar and Calculator are in the app launcher as **Yahr Calendar** and **Yahr Calculator**.

## Layout

```
themes/            bundled palettes (JSON)
theme-engine/      yahr-theme CLI (Python, stdlib only)
hypr/              Lua config (Hyprland ≥ 0.55) + generated theme.lua
quickshell/        modular QML shell
ghostty/ mako/ thunar/
sddm/              optional SDDM theme
apps/              .desktop launchers for Yahr apps
wallpapers/        per-theme folders, copied to ~/Pictures/Wallpapers
```

## Stack

Hyprland (Lua) · Quickshell · Ghostty · Mako · Thunar · Papirus · swww · adw-gtk3 · qt6ct

Nautilus is not used: libadwaita only follows accent color reliably. Thunar plus generated GTK CSS actually recolors the file manager.

## License

Use and remix freely. Successor to [yahr-quickshell](https://github.com/bgibson72/yahr-quickshell).

# YAHR SDDM theme

Login screen that follows the YAHR shell: full-bleed wallpaper, large clock, and a
floating bottom **dock strip** (avatar, username/password, session, power) tinted
from the active palette. Background blur is fixed at FastBlur radius 40.

## Sync

Theme apply (`yahr-theme apply` or Settings → SDDM → Apply) writes the current
palette from `~/.config/yahr/current.json` into `theme.conf` and copies the
desktop wallpaper into `/usr/share/sddm/themes/yahr-theme` as
`login-background.png` (or `.jpg`). Colors and wallpaper are never hard-coded to
a specific theme — every `yahr-theme apply` and every desktop wallpaper change
(with **Match desktop** on) refreshes the greeter.

```bash
# Manual sync / debug
bash quickshell/scripts/sddm-apply-cli --wallpaper desktop
cat ~/.cache/yahr/sddm-sync.log   # written after each desktop wallpaper change
```

`./install.sh` writes this sudoers rule. To install it on its own:

```bash
# From your clone, or after install:
./sddm/setup-sudoers.sh
# or
~/.local/share/yahr-shell/sddm/setup-sudoers.sh
```

Manual apply from Settings → SDDM → **Apply to SDDM**.

If Settings → SDDM still shows **Blur background** or **Login Window Transparency**,
the live Quickshell tree is stale (a copied `~/.config/quickshell` that did not
follow `git pull`). Repair with:

```bash
# From your yahr-shell clone on latest main:
pwd > ~/.config/yahr/repo-root
bash quickshell/scripts/sync-quickshell-cli --restart
# or: yahr-sync-quickshell --restart
```

The sync stops Quickshell before replacing `~/.config/quickshell` (relinking while
it is running can hot-reload mid-swap and error with `WallpaperSlideshow is not a type`).
Then confirm Settings → SDDM has no blur/transparency controls. Autostart sync log: `/tmp/yahr-quickshell-sync.log`.

## Preview

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/yahr-theme
```

# YAHR SDDM theme

Login screen that follows the YAHR shell: full-bleed wallpaper, large clock, and a
login plate tinted from the active palette. When the desktop bar is **docked**
(solid + picture frame), the greeter draws an even picture-frame bezel on all
four sides and joins a **Login** tab into the bottom edge; click the tab to
slide the login plate up. When the bar is floating, the same tab/plate pattern
is used without the bezel. Background blur is fixed at FastBlur radius 40.

Typography uses the **UI Font** chosen in Settings (resolved via fontconfig to
the same installed family the shell uses). Changing the UI font syncs the
greeter automatically.

## Sync

Theme apply (`yahr-theme apply` or Settings → SDDM → Apply) writes the current
palette from `~/.config/yahr/current.json`, the Settings UI font (plus
fontconfig-resolved family), clock/date formats, and framed-bar geometry
(`UseFrame`, thickness, rounding) into `theme.conf`. It also copies `Main.qml`
(frame + login panel are inlined there) into `/usr/share/sddm/themes/yahr-theme`
and copies the desktop wallpaper as `login-background.png` (or `.jpg`). Check
apply output for `main_version_src=… live=5` — if you see `OK_QML_STALE`, the
sudoers `cp` rule did not refresh the greeter QML. Colors and wallpaper are
never hard-coded to a specific theme — every `yahr-theme apply`, UI font
change, and desktop wallpaper change (with **Match desktop** on) refreshes the
greeter.

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

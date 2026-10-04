# YAHR SDDM theme

Login screen that follows the YAHR shell: wide split plate (wallpaper crop + form), Inter type, card-colored fields, and a runtime-blurred desktop wallpaper (fixed FastBlur radius 40).

## Sync

Theme apply (`yahr-theme apply` or Settings → SDDM → Apply) writes palette colors into `theme.conf` and copies a sharp `login-background.png` into `/usr/share/sddm/themes/yahr-theme`. The login-window crop uses that same file; full-screen blur is always applied at runtime (FastBlur radius 40). Login-plate opacity is fixed (not exposed in Settings).

Desktop wallpaper changes (with **Match desktop** on) call `set-wallpaper.py` → `sddm-apply.py`, which overwrites `login-background.png` every time. Sync prefers the git checkout in `~/.config/yahr/repo-root` when present.

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

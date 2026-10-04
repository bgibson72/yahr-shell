# YAHR SDDM theme

Login screen that follows the YAHR shell: wide split plate (wallpaper welcome panel + form), Inter type, card-colored fields, and a pre-blurred desktop wallpaper.

## Sync

Theme apply (`yahr-theme apply` or Settings → SDDM → Apply) writes palette colors into `theme.conf` and copies sharp PNG wallpapers (`login-background.png` + `login-hero.png`) into `/usr/share/sddm/themes/yahr-theme`. Full-screen blur is applied at runtime by the greeter; the left hero panel always stays sharp.

Desktop wallpaper changes (with **Match desktop** on) call `set-wallpaper.py` → `sddm-apply.py`, which overwrites both PNGs every time. Sync prefers the git checkout in `~/.config/yahr/repo-root` when present so pulled fixes apply without reinstalling Quickshell.

```bash
# Manual sync / debug
bash quickshell/scripts/sddm-apply-cli --opacity 0.75 --blur 20 --wallpaper desktop
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

## Preview

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/yahr-theme
```

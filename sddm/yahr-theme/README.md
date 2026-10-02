# YAHR SDDM theme

Login screen that follows the YAHR shell: wide split plate (wallpaper welcome panel + form), Inter type, card-colored fields, and a pre-blurred desktop wallpaper.

## Sync

Theme apply (`yahr-theme apply` or Settings → SDDM → Apply) writes palette colors into `theme.conf` and copies a sharp wallpaper (`login-background` + `login-hero`) into `/usr/share/sddm/themes/yahr-theme`. Full-screen blur is applied at runtime by the greeter; the left hero panel always stays sharp.

Because `install.sh` copies Quickshell into `~/.config/quickshell`, pull the branch then either re-install configs or run apply from the clone:

```bash
python3 /path/to/yahr-shell/quickshell/scripts/sddm-apply.py \
  --opacity 0.75 --blur 20 --wallpaper desktop
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

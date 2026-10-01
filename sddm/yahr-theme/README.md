# YAHR SDDM theme

Login screen that follows the YAHR shell: Inter type, rounded plate, card-colored fields, and a pre-blurred desktop wallpaper.

## Sync

Theme apply (`yahr-theme apply` or Settings → Theme) writes palette colors and clock formats into `theme.conf`. Changing the desktop wallpaper (with **Match desktop** on) copies a blurred still of that image into `/usr/share/sddm/themes/yahr-theme`.

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

Thunar is the v1 file manager. `yahr-theme apply` maps each palette onto the
GTK3 theme packages in `~/.themes` (the same Catppuccin-Dark / Dracula / …
packs v1 used) and writes `~/.config/gtk-3.0/gtk.css` so Thunar's icon view
picks up `theme_base_color`. Super+F and the bar files button launch
`quickshell/scripts/launch-thunar.sh` so `GTK_THEME` is set even when
Hyprland's environment is thin.

Custom actions live in `uca.xml`.

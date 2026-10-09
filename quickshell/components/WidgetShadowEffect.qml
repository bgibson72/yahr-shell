import QtQuick
import QtQuick.Effects
import ".."

// Soft glow/shadow for floating popups, matching Hyprland window shadow
// presets (range + alpha + optional accent color).
//
// Quickshell panels are rounded rectangles, so RectangularShadow (SDF) is
// the right tool — a layered MultiEffect pads a hard-edged halo that reads
// as a blocky border instead of a glow, especially at Heavy range.
// See Quickshell FAQ: prefer RectangularShadow for rectangular shadows.
RectangularShadow {
    // Caller supplies the panel corner radius (uniform; frame-join panels
    // disable this effect entirely while emerging).
    required property real cornerRadius

    readonly property int shadowPx: Math.max(0, ThemeManager.hyprShadowRange)

    radius: cornerRadius
    // Hyprland decoration.shadow.range is a pixel extent. RectangularShadow
    // blur is also in pixels; ~1.2× matches CSS/box-shadow denser falloff
    // notes in the Qt docs and keeps Light/Moderate/Heavy clearly distinct.
    blur: shadowPx * 1.2
    // Mild spread so heavier presets also feel denser near the edge, not
    // only softer farther out.
    spread: shadowPx * 0.2
    offset: Qt.vector2d(0, 0)
    color: Qt.rgba(
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.r : 0,
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.g : 0,
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.b : 0,
        Math.min(1, ThemeManager.hyprShadowAlpha / 100 * 1.15))
}

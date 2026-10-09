import QtQuick
import QtQuick.Effects
import ".."

// Reusable glow/shadow effect for floating popups, mirroring Hyprland's
// window shadow settings so panels visually match compositor-rendered
// window shadows at the same range/alpha. Applied automatically by
// components/Panel.qml via layer.enabled/layer.effect.
//
// Hyprland's shadow.range is a pixel extent (Light=10, Moderate=20,
// Heavy=40). MultiEffect's shadowBlur is only a 0–1 fraction of blurMax
// (default 32), so the old formula `min(1, 0.55 + range/70)` collapsed
// every preset into ~22–32px of nearly identical glow. Map range onto
// blurMax instead, keep shadowBlur at full strength, and let alpha
// track the preset transparency.
MultiEffect {
    // Hyprland range is 0–100px; MultiEffect blurMax is useful up to 64.
    readonly property int shadowPx: Math.max(2, Math.min(64, ThemeManager.hyprShadowRange))

    shadowEnabled: true
    shadowColor: Qt.rgba(
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.r : 0,
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.g : 0,
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.b : 0,
        // Slight density boost so Qt's soft gaussian reads closer to
        // Hyprland's denser falloff; still scales with the preset alpha.
        Math.min(1, ThemeManager.hyprShadowAlpha / 100 * 1.15))
    // Full blur against blurMax so the pixel radius tracks Hyprland range.
    shadowBlur: 1.0
    blurMax: shadowPx
    // Mild outward scale so heavier presets also read as larger distance,
    // not only a softer blur halo. autoPaddingEnabled (default) grows the
    // layer to fit blurMax; this small scale stays within that pad.
    shadowScale: 1.0 + shadowPx / 200
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
}

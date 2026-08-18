import QtQuick
import QtQuick.Effects
import ".."

// Reusable glow/shadow effect for floating popups, mirroring Hyprland's
// window shadow settings so panels visually match compositor-rendered
// window shadows at the same range/alpha. Applied automatically by
// components/Panel.qml via layer.enabled/layer.effect.
//
// Hyprland's shadow reads as a fairly dense, saturated band close to the
// window edge rather than a soft, spread-out blur. Qt's MultiEffect shadow
// is a gaussian blur by nature, so we boost the color's perceived density a
// bit rather than mapping alpha 1:1.
MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.r : 0,
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.g : 0,
        ThemeManager.hyprShadowUseAccent ? ThemeManager.accentBlue.b : 0,
        Math.min(1, ThemeManager.hyprShadowAlpha / 100 * 1.15))
    shadowBlur: Math.min(1, 0.55 + ThemeManager.hyprShadowRange / 70)
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
}

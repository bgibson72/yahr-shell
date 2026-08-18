import QtQuick
import ".."

// Base look for every floating popup (settings, launcher, control center,
// etc.), plus a shared "slide and plop" entrance: the panel flies in from
// slideOffsetX/slideOffsetY and grows from entranceScale up to full size
// with a springy overshoot, so opening any widget feels organic rather than
// an instant cut. Override the slide/scale properties per-instance to match
// where a given popup is anchored on screen (e.g. a corner-anchored panel
// should slide in from that same corner).
Rectangle {
    id: panel
    property bool isVisible: false

    property real slideOffsetX: 0
    property real slideOffsetY: -36
    property real entranceScale: 0.88

    property real entrance: isVisible ? 1 : 0
    Behavior on entrance {
        NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    scale: entranceScale + (1 - entranceScale) * entrance
    opacity: entrance
    transform: Translate {
        x: (1 - panel.entrance) * panel.slideOffsetX
        y: (1 - panel.entrance) * panel.slideOffsetY
    }

    color: ThemeManager.panelColor
    radius: ThemeManager.hyprRounding
    border.width: ThemeManager.showWidgetBorders ? ThemeManager.widgetBorderWidth : 0
    border.color: ThemeManager.accentBorder
    antialiasing: true

    layer.enabled: ThemeManager.hyprShadowEnabled
    layer.effect: WidgetShadowEffect {}
}

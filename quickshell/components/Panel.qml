import QtQuick
import ".."

// Base look for every floating popup. Motion depends on bar chrome:
//   Islands, or a floating solid bar → elastic slide + grow
//   Solid + docked bar → clip-reveal out of the screen frame / bar edge
// Overlay hosts should keep the window up while `onScreen` is true so the
// leave animation can finish.
Item {
    id: panel
    default property alias content: chrome.data

    property bool isVisible: false
    property real slideOffsetX: 0
    property real slideOffsetY: -36
    property real entranceScale: 0.88
    // "auto" follows the bar edge; otherwise "top" / "bottom" / "left" / "right".
    property string emergeEdge: "auto"
    // "auto" infers left / right / center from x; or set "left" / "right" / "center".
    property string frameJoin: "auto"
    // Settings and similar large dialogs pop in the middle instead of
    // clip-revealing out of the screen frame.
    property bool floatCenter: false

    readonly property bool emerge: ThemeManager.useFrameEmerge && !floatCenter
    readonly property string resolvedEmergeEdge: {
        if (emergeEdge !== "auto")
            return emergeEdge
        return ThemeManager.emergeFromBottom ? "bottom" : "top"
    }
    readonly property string resolvedJoin: {
        if (frameJoin !== "auto")
            return frameJoin
        if (!panel.emerge || !panel.parent)
            return "center"
        const slop = 8
        if (panel.x <= ThemeManager.panelLeftMargin + slop)
            return "left"
        if (panel.x + panel.width >= panel.parent.width - ThemeManager.panelRightMargin - slop)
            return "right"
        return "center"
    }

    property real entrance: isVisible ? 1 : 0
    readonly property bool onScreen: isVisible || entrance > 0.02
    Behavior on entrance {
        NumberAnimation {
            duration: panel.isVisible
                ? (panel.emerge ? 420 : 820)
                : (panel.emerge ? 400 : 240)
            easing.type: panel.isVisible
                ? (panel.emerge ? Easing.OutCubic : Easing.OutElastic)
                : (panel.emerge ? Easing.InOutCubic : Easing.InCubic)
            easing.amplitude: 0.85
            easing.period: 0.48
        }
    }

    readonly property int chromeRadius: ThemeManager.hyprRounding
    readonly property string edge: panel.resolvedEmergeEdge
    readonly property int joinR: ThemeManager.frameInnerRadius
    readonly property bool joinLeft: panel.emerge && resolvedJoin === "left"
    readonly property bool joinRight: panel.emerge && resolvedJoin === "right"
    readonly property bool joinCenter: panel.emerge && resolvedJoin === "center"
    readonly property bool joinTop: panel.emerge && edge === "top"
    readonly property bool joinBottom: panel.emerge && edge === "bottom"
    readonly property bool joinLeftEdge: panel.emerge && edge === "left"
    readonly property bool joinRightEdge: panel.emerge && edge === "right"
    readonly property int freeR: panel.emerge ? joinR : chromeRadius

    readonly property int pad: panel.emerge ? panel.joinR : 0
    readonly property int paddedW: panel.width + pad * 2
    readonly property int paddedH: panel.height + pad * 2

    clip: false

    Item {
        id: reveal
        clip: panel.emerge
        x: {
            if (!panel.emerge)
                return 0
            if (panel.edge === "right")
                return panel.paddedW * (1 - panel.entrance) - panel.pad
            return -panel.pad
        }
        y: {
            if (!panel.emerge)
                return 0
            if (panel.edge === "bottom")
                return panel.paddedH * (1 - panel.entrance) - panel.pad
            return -panel.pad
        }
        width: {
            if (!panel.emerge)
                return panel.width
            if (panel.edge === "left" || panel.edge === "right")
                return Math.max(0, panel.paddedW * panel.entrance)
            return panel.paddedW
        }
        height: {
            if (!panel.emerge)
                return panel.height
            if (panel.edge === "top" || panel.edge === "bottom")
                return Math.max(0, panel.paddedH * panel.entrance)
            return panel.paddedH
        }

        Rectangle {
            id: chrome
            width: panel.width
            height: panel.height
            x: panel.emerge ? -reveal.x : 0
            y: panel.emerge ? -reveal.y : 0

            color: panel.emerge ? ThemeManager.frameFillColor : ThemeManager.panelColor
            radius: panel.freeR
            // Center tabs square both top corners into the bar. Side drawers
            // keep the frame-adjacent top corner convex so it nests in the
            // screen's inner curve; only the inner top is squared for a bar ear.
            // Right/left center drawers square both corners on the bezel edge.
            topLeftRadius: (panel.joinTop && !panel.joinLeft)
                || panel.joinLeftEdge
                || (panel.joinBottom && panel.joinLeft) ? 0 : panel.freeR
            topRightRadius: (panel.joinTop && !panel.joinRight)
                || panel.joinRightEdge
                || (panel.joinBottom && panel.joinRight) ? 0 : panel.freeR
            bottomLeftRadius: (panel.joinBottom && !panel.joinLeft)
                || (panel.joinTop && panel.joinLeft)
                || panel.joinLeftEdge ? 0 : panel.freeR
            bottomRightRadius: (panel.joinBottom && !panel.joinRight)
                || (panel.joinTop && panel.joinRight)
                || panel.joinRightEdge ? 0 : panel.freeR
            border.width: ThemeManager.showWidgetBorders ? ThemeManager.widgetBorderWidth : 0
            border.color: ThemeManager.chromeBorderColor
            antialiasing: true

            scale: panel.emerge ? 1 : (panel.entranceScale + (1 - panel.entranceScale) * Math.max(0, panel.entrance))
            opacity: panel.emerge ? 1 : Math.max(0, Math.min(1, panel.entrance))
            transform: Translate {
                x: panel.emerge ? 0 : (1 - panel.entrance) * panel.slideOffsetX
                y: panel.emerge ? 0 : (1 - panel.entrance) * panel.slideOffsetY
            }

            layer.enabled: !panel.emerge && ThemeManager.hyprShadowEnabled
            layer.effect: WidgetShadowEffect {}

            MouseArea {
                z: -1
                anchors.fill: parent
                onClicked: {}
            }
        }

        FrameJoins {
            id: joins
            x: -panel.pad - reveal.x
            y: -panel.pad - reveal.y
            z: 1
            joinR: panel.joinR
            contentW: panel.width
            contentH: panel.height
            joinTop: panel.joinTop
            joinBottom: panel.joinBottom
            joinLeft: panel.joinLeft
            joinRight: panel.joinRight
            joinLeftEdge: panel.joinLeftEdge
            joinRightEdge: panel.joinRightEdge
        }
    }
}

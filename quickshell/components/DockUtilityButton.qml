import QtQuick
import ".."

// A fixed (non-pinnable, non-removable) utility icon appended to the dock,
// used for things like Settings or Trash — distinct from the user's
// pinned-app icons, which come from Settings.dockPinnedApps.
Item {
    id: root

    property int iconSize: 48
    property string glyph: ""
    property color glyphColor: ThemeManager.fgSecondary
    property string tooltip: ""
    property string dockPosition: "bottom" // "top" | "bottom" | "left" | "right"
    signal clicked()

    width: iconSize
    height: iconSize

    readonly property bool hovered: mouse.containsMouse

    scale: mouse.pressed ? ThemeManager.iconPressScale : (hovered ? ThemeManager.iconHoverScale : 1.0)
    Behavior on scale {
        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: "Symbols Nerd Font"
        font.pixelSize: root.iconSize * 0.55
        color: root.glyphColor
    }

    Rectangle {
        visible: root.hovered && root.tooltip !== ""
        color: Qt.rgba(ThemeManager.bgBase.r, ThemeManager.bgBase.g, ThemeManager.bgBase.b, 0.95)
        radius: 6
        width: tooltipText.implicitWidth + 16
        height: tooltipText.implicitHeight + 8
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.dockPosition === "bottom" ? -height - 8
           : root.dockPosition === "top" ? parent.height + 8
           : 0
        x: root.dockPosition === "left" ? parent.width + 8
           : root.dockPosition === "right" ? -width - 8
           : (width - parent.width) / -2

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: root.tooltip
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeSmall
            color: ThemeManager.fgPrimary
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

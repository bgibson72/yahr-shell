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

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

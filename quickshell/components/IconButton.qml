import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property string glyph: ""
    property color glyphColor: ThemeManager.fgPrimary
    property int pixelSize: ThemeManager.fontSizeIcon
    signal clicked()

    width: 46
    height: 40
    radius: 10
    color: "transparent"

    scale: mouse.pressed ? ThemeManager.iconPressScale : (mouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
    Behavior on scale {
        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: "Symbols Nerd Font"
        font.pixelSize: root.pixelSize
        color: root.glyphColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

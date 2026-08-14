import QtQuick

Rectangle {
    id: root
    property string icon: ""
    property string glyph: ""
    property color glyphColor: ThemeManager.fgPrimary
    property int pixelSize: ThemeManager.fontSizeIcon
    signal clicked()

    width: 36
    height: 32
    radius: 6
    color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
    border.width: mouse.containsMouse ? 1 : 0
    border.color: Qt.rgba(1, 1, 1, 0.18)

    Behavior on color { ColorAnimation { duration: 150 } }

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

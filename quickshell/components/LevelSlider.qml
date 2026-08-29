import QtQuick
import ".."

Item {
    id: root
    property real value: 0
    property color fillColor: ThemeManager.accentBlue
    signal moved(real value)

    implicitHeight: 18
    height: implicitHeight

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: ThemeManager.surface1

        Rectangle {
            width: Math.max(0, Math.min(parent.width, parent.width * root.value / 100))
            height: parent.height
            radius: 4
            color: root.fillColor
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function atX(mx) {
            const pct = Math.max(0, Math.min(100, Math.round(mx / Math.max(1, root.width) * 100)))
            root.value = pct
            root.moved(pct)
        }

        onPressed: mouse => atX(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                atX(mouse.x)
        }
    }
}

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: powerButton
    width: 44
    height: 44
    radius: 22
    color: mouseArea.containsMouse
        ? Qt.rgba(accent.r, accent.g, accent.b, 0.22)
        : buttonBg

    property string icon: ""
    property alias text: toolTip.text
    property color buttonBg: "#2b2837"
    property color buttonFg: "#cdcbe0"
    property color accent: "#6db3ce"
    signal clicked()

    Text {
        anchors.centerIn: parent
        text: getIconText()
        font.family: "Symbols Nerd Font"
        font.pixelSize: 18
        color: icon === "shutdown" ? "#eb746b" : buttonFg
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: powerButton.clicked()
    }

    ToolTip {
        id: toolTip
        visible: mouseArea.containsMouse
        delay: 500
    }

    function getIconText() {
        switch (icon) {
        case "suspend":
            return "󰒲"
        case "reboot":
            return "󰜉"
        case "shutdown":
            return "󰐥"
        default:
            return "?"
        }
    }
}

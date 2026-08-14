import QtQuick
import Quickshell
import "../../components"

Panel {
    id: root
    width: 520
    height: 110
    property bool isVisible: false
    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    function go(action) {
        root.requestClose()
        Qt.callLater(() => {
            if (action === "lock") Quickshell.execDetached(["hyprlock"])
            else if (action === "logout") Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
            else if (action === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
            else if (action === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
            else if (action === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
        })
    }

    Row {
        anchors.centerIn: parent
        spacing: 16

        Repeater {
            model: [
                { icon: "󰌾", action: "lock", danger: false },
                { icon: "󰍃", action: "logout", danger: false },
                { icon: "󰒲", action: "suspend", danger: false },
                { icon: "󰜉", action: "reboot", danger: true },
                { icon: "󰐥", action: "shutdown", danger: true }
            ]

            Rectangle {
                required property var modelData
                width: 72
                height: 72
                radius: 12
                color: mouse.containsMouse
                    ? Qt.rgba((modelData.danger ? ThemeManager.accentRed.r : ThemeManager.accentBlue.r),
                              (modelData.danger ? ThemeManager.accentRed.g : ThemeManager.accentBlue.g),
                              (modelData.danger ? ThemeManager.accentRed.b : ThemeManager.accentBlue.b), 0.25)
                    : "transparent"
                border.width: mouse.containsMouse ? 1 : 0
                border.color: Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.5)

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 30
                    color: ThemeManager.fgPrimary
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.go(modelData.action)
                }
            }
        }
    }
}

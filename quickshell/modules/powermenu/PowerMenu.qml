import QtQuick
import Quickshell
import "../../components"
import "../.."

Panel {
    id: root
    width: 110
    height: 520
    emergeEdge: "right"
    frameJoin: "center"
    slideOffsetX: 48
    slideOffsetY: 0
    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    function go(action) {
        root.requestClose()
        Qt.callLater(() => {
            if (action === "lock") Quickshell.execDetached(["hyprlock"])
            else if (action === "logout") Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"])
            else if (action === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
            else if (action === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
            else if (action === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
        })
    }

    Column {
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

            Item {
                id: btn
                required property var modelData
                width: 80
                height: 80

                scale: mouse.pressed ? ThemeManager.iconPressScale : (mouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }

                Text {
                    anchors.centerIn: parent
                    text: btn.modelData.icon
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 34
                    color: btn.modelData.danger ? ThemeManager.accentRed : ThemeManager.fgPrimary
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.go(btn.modelData.action)
                }
            }
        }
    }
}

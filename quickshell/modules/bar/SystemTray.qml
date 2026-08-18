import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../.."

RowLayout {
    id: root
    spacing: 2
    visible: Settings.showSystemTray && SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem
            required property var modelData

            Layout.preferredWidth: 34
            Layout.preferredHeight: 34

            scale: trayMouse.pressed ? ThemeManager.iconPressScale : (trayMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: ThemeManager.barLarge ? 22 : 18
                source: trayItem.modelData.icon
                asynchronous: true
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        trayItem.modelData.activate()
                    else if (mouse.button === Qt.MiddleButton)
                        trayItem.modelData.secondaryActivate()
                    else if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu)
                        trayItem.modelData.display(trayItem, mouse.x, mouse.y)
                }

                onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}

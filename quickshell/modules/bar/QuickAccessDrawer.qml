import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../.."

// Collapsible strip of app launchers that live in the bar without permanently
// eating space. Chevron toggles a reveal of a couple of quick-launch icons
// for apps that don't already have a dedicated bar icon elsewhere.
Item {
    id: drawer
    visible: Settings.showQuickLaunch

    signal toggleScreenshot()

    property bool expanded: false
    readonly property int chevronSize: 32

    implicitWidth: content.implicitWidth
    implicitHeight: 40

    RowLayout {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Rectangle {
            id: chevron
            Layout.preferredWidth: drawer.chevronSize
            Layout.preferredHeight: drawer.chevronSize
            radius: 8
            color: "transparent"
            scale: chevronMouse.pressed ? ThemeManager.iconPressScale : (chevronMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            Text {
                anchors.centerIn: parent
                text: drawer.expanded ? "\uf054" : "\uf077"
                font.family: "Symbols Nerd Font"
                font.pixelSize: ThemeManager.fontSizeSmall
                color: ThemeManager.fgSecondary
            }

            MouseArea {
                id: chevronMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: drawer.expanded = !drawer.expanded
            }
        }

        Item {
            id: reveal
            Layout.preferredWidth: drawer.expanded ? revealRow.implicitWidth : 0
            Layout.preferredHeight: 40
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            RowLayout {
                id: revealRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                IconButton {
                    glyph: "\uf489"
                    onClicked: Quickshell.execDetached(["kitty"])
                }
                IconButton {
                    glyph: "\uf269"
                    onClicked: Quickshell.execDetached(["firefox"])
                }
                IconButton {
                    glyph: "\uf030"
                    onClicked: drawer.toggleScreenshot()
                }
            }
        }
    }
}

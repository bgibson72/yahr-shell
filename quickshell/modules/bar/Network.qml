import QtQuick
import Quickshell
import "../.."

Item {
    id: net
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 40
    signal togglePanel()

    scale: netMouse.pressed ? ThemeManager.iconPressScale : (netMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
    Behavior on scale {
        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Text {
            id: netGlyph
            text: {
                if (NetworkState.connectionType === "wifi")
                    return "󰤨"
                if (NetworkState.connectionType === "ethernet")
                    return "󰈀"
                return "󰌙"
            }
            font.family: "Symbols Nerd Font"
            font.pixelSize: ThemeManager.fontSizeIcon
            color: {
                if (NetworkState.connectionType === "wifi")
                    return ThemeManager.accentGreen
                if (NetworkState.connectionType === "ethernet")
                    return ThemeManager.accentBlue
                return ThemeManager.accentRed
            }
        }
        Text {
            visible: Settings.showNetworkSpeed && NetworkState.connectionType !== "none"
            text: `↓${NetworkState.downloadSpeedText} ↑${NetworkState.uploadSpeedText}`
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeSmall
            color: ThemeManager.fgSecondary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: netMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: net.togglePanel()
    }
}

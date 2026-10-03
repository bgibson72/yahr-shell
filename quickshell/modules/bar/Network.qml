import QtQuick
import Quickshell
import "../.."

Item {
    id: net
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 40
    signal togglePanel()

    // Reserve room for the widest rate we format ("999.9M") so the tray
    // doesn't shift when values jump between 1–3 digit widths.
    FontMetrics {
        id: speedMetrics
        font.family: ThemeManager.uiFont
        font.pixelSize: ThemeManager.fontSizeNormal
    }
    readonly property int speedFieldWidth: Math.ceil(speedMetrics.advanceWidth("999.9M"))
    readonly property bool showSpeeds: Settings.showNetworkSpeed && NetworkState.connectionType !== "none"

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
        Row {
            id: speedRow
            visible: net.showSpeeds
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Row {
                spacing: 2
                Text {
                    text: "↓"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeNormal
                    color: netGlyph.color
                }
                Text {
                    width: net.speedFieldWidth
                    text: NetworkState.downloadSpeedText
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeNormal
                    color: netGlyph.color
                    horizontalAlignment: Text.AlignRight
                }
            }
            Row {
                spacing: 2
                Text {
                    text: "↑"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeNormal
                    color: netGlyph.color
                }
                Text {
                    width: net.speedFieldWidth
                    text: NetworkState.uploadSpeedText
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeNormal
                    color: netGlyph.color
                    horizontalAlignment: Text.AlignRight
                }
            }
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

import QtQuick
import Quickshell
import "../.."

Item {
    id: net
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 40
    signal togglePanel()

    // Fixed slot width so the tray does not reflow as digit counts change.
    // Content is left-packed (rate then arrow) to avoid empty lead space
    // after the network icon; leftover room stays as trailing pad.
    FontMetrics {
        id: speedMetrics
        font.family: ThemeManager.uiFont
        font.pixelSize: ThemeManager.fontSizeNormal
    }
    readonly property int speedSlotWidth: Math.ceil(speedMetrics.advanceWidth("1024M↓"))
    readonly property bool showSpeeds: Settings.showNetworkSpeed && NetworkState.connectionType !== "none"

    scale: netMouse.pressed ? ThemeManager.iconPressScale : (netMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
    Behavior on scale {
        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
    }

    component SpeedSlot: Item {
        property string rate
        property string arrow
        property color labelColor

        width: net.speedSlotWidth
        height: Math.max(rateLabel.implicitHeight, arrowLabel.implicitHeight)

        Text {
            id: rateLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: rate
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: labelColor
        }
        Text {
            id: arrowLabel
            anchors.left: rateLabel.right
            anchors.verticalCenter: parent.verticalCenter
            text: arrow
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: labelColor
        }
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
            visible: net.showSpeeds
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter

            SpeedSlot {
                rate: NetworkState.downloadSpeedText
                arrow: "↓"
                labelColor: netGlyph.color
            }
            SpeedSlot {
                rate: NetworkState.uploadSpeedText
                arrow: "↑"
                labelColor: netGlyph.color
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

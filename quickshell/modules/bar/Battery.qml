import QtQuick
import Quickshell
import "../.."

Item {
    id: bat
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 40
    signal togglePanel()

    readonly property bool hasBattery: PowerState.hasBattery
    readonly property bool pluggedIn: PowerState.pluggedIn
    readonly property bool charging: PowerState.charging
    readonly property int percent: PowerState.percent

    scale: batMouse.pressed ? ThemeManager.iconPressScale : (batMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
    Behavior on scale {
        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Text {
            id: batGlyph
            text: {
                if (bat.pluggedIn) {
                    if (bat.hasBattery && bat.charging)
                        return "󰂄"
                    return "󰚥"
                }
                const pct = bat.percent
                if (pct >= 95) return "󰁹"
                if (pct >= 80) return "󰂁"
                if (pct >= 60) return "󰁿"
                if (pct >= 40) return "󰁽"
                if (pct >= 20) return "󰁻"
                return "󰂃"
            }
            font.family: "Symbols Nerd Font"
            font.pixelSize: ThemeManager.fontSizeIcon
            color: {
                if (bat.pluggedIn)
                    return ThemeManager.accentGreen
                if (bat.percent <= 15) return ThemeManager.accentRed
                if (bat.percent <= 30) return ThemeManager.accentYellow
                return ThemeManager.accentGreen
            }
        }
        Text {
            visible: Settings.showBatteryPercent && bat.hasBattery
            text: bat.percent + "%"
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: batGlyph.color
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: batMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bat.togglePanel()
    }
}

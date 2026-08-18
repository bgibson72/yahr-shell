import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Item {
    id: bat
    implicitWidth: visible ? row.implicitWidth + 12 : 0
    implicitHeight: 40
    visible: false
    property int percent: 100
    property bool charging: false

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Text {
            text: {
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
                if (bat.charging) return ThemeManager.accentGreen
                if (bat.percent <= 15) return ThemeManager.accentRed
                if (bat.percent <= 30) return ThemeManager.accentYellow
                return ThemeManager.accentGreen
            }
        }
        Text {
            visible: bat.charging
            text: bat.percent + "%"
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeSmall
            color: ThemeManager.accentGreen
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process {
        id: probe
        running: false
        command: ["sh", "-c", "BAT=$(echo /sys/class/power_supply/BAT*/uevent | awk '{print $1}'); [ -f \"$BAT\" ] || exit 1; CAP=$(grep POWER_SUPPLY_CAPACITY= \"$BAT\" | cut -d= -f2); STAT=$(grep POWER_SUPPLY_STATUS= \"$BAT\" | cut -d= -f2); echo \"$CAP $STAT\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(" ")
                if (parts.length >= 1 && parts[0] !== "") {
                    bat.visible = true
                    bat.percent = parseInt(parts[0]) || 0
                    bat.charging = parts.slice(1).join(" ").indexOf("Charg") !== -1
                } else {
                    bat.visible = false
                }
            }
        }
    }
}

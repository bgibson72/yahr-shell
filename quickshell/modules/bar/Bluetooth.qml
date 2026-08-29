import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

IconButton {
    id: bt
    compact: true
    visible: available
    glyph: powered ? "󰂯" : "󰂲"
    glyphColor: powered ? ThemeManager.accentGreen : ThemeManager.border0
    property bool available: true
    property bool powered: false
    signal togglePanel()

    onClicked: bt.togglePanel()

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!probe.running)
                probe.running = true
        }
    }

    Process {
        id: probe
        running: false
        command: ["sh", "-c", "command -v bluetoothctl >/dev/null 2>&1 || { echo missing; exit 0; }; rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes' && echo off || echo on"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                if (t === "missing") {
                    bt.available = false
                    bt.powered = false
                    return
                }
                bt.available = true
                bt.powered = t === "on"
            }
        }
    }
}

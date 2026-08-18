import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

IconButton {
    id: net
    glyph: connectionType === "wifi" ? "󰤨" : (connectionType === "ethernet" ? "󰈀" : "󰌙")
    glyphColor: connectionType === "wifi" ? ThemeManager.accentGreen : (connectionType === "ethernet" ? ThemeManager.accentBlue : ThemeManager.accentRed)
    property string connectionType: "ethernet"

    onClicked: Quickshell.execDetached(["nm-connection-editor"])

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process {
        id: probe
        running: false
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device status | awk -F: '$2==\"connected\"{print $1; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                if (t.indexOf("wifi") !== -1)
                    net.connectionType = "wifi"
                else if (t.indexOf("ethernet") !== -1)
                    net.connectionType = "ethernet"
                else
                    net.connectionType = "none"
            }
        }
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string connectionType: "none"
    property string device: ""
    property string connectionName: ""

    function refresh() {
        debounce.restart()
    }

    Timer {
        id: debounce
        interval: 200
        repeat: false
        onTriggered: {
            probe.running = false
            probe.running = true
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: probe
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/network-status.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    root.connectionType = data.type || "none"
                    root.device = data.device || ""
                    root.connectionName = data.name || ""
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: nmWatch
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.refresh()
        }
    }
}

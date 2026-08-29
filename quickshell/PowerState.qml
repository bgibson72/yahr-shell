pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool present: false
    property int percent: 0
    property bool acOnline: false
    property string status: "Unknown"
    property int seconds: 0

    readonly property bool hasBattery: present
    readonly property bool charging: status === "Charging"
    readonly property bool full: {
        const s = status.toLowerCase()
        return s === "full" || s === "fully charged"
    }
    readonly property bool pluggedIn: acOnline || charging || full || status === "Not charging"

    function refresh() {
        debounce.restart()
    }

    Timer {
        id: debounce
        interval: 150
        repeat: false
        onTriggered: {
            probe.running = false
            probe.running = true
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: probe
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/battery-status.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    root.present = !!data.present
                    root.percent = data.percent || 0
                    root.acOnline = !!data.ac
                    root.status = data.status || "Unknown"
                    root.seconds = data.seconds || 0
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: udevWatch
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=power_supply"]
        stdout: SplitParser {
            onRead: root.refresh()
        }
    }
}

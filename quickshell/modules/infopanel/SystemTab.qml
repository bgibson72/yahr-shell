import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Item {
    id: root
    property bool active: false

    property real cpuPercent: 0
    property var cpuHistory: []
    property int cpuCores: 0
    property real cpuAvg: 0

    property real memPercent: 0
    property var memHistory: []
    property real memUsedGb: 0
    property real memTotalGb: 0

    property real diskPercent: 0
    property real diskUsedGb: 0
    property real diskFreeGb: 0
    property real diskTotalGb: 0

    property real tempC: 0
    property var tempHistory: []
    property real tempMin: 999
    property real tempMax: 0

    function pushHistory(arr, value) {
        const next = arr.concat([value])
        if (next.length > 60)
            next.shift()
        return next
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProc.running = true
    }

    Process {
        id: statsProc
        running: false
        command: [`${Quickshell.shellDir}/scripts/system-stats.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                let data
                try {
                    data = JSON.parse(this.text)
                } catch (e) {
                    return
                }

                root.cpuPercent = data.cpuPercent
                root.cpuCores = data.cpuCores
                root.cpuHistory = root.pushHistory(root.cpuHistory, data.cpuPercent)
                const cpuSum = root.cpuHistory.reduce((a, b) => a + b, 0)
                root.cpuAvg = Math.round(cpuSum / root.cpuHistory.length)

                root.memPercent = data.memPercent
                root.memUsedGb = data.memUsedGb
                root.memTotalGb = data.memTotalGb
                root.memHistory = root.pushHistory(root.memHistory, data.memPercent)

                root.diskPercent = data.diskPercent
                root.diskUsedGb = data.diskUsedGb
                root.diskFreeGb = data.diskFreeGb
                root.diskTotalGb = data.diskTotalGb

                root.tempC = data.tempC
                root.tempHistory = root.pushHistory(root.tempHistory, data.tempC)
                if (root.tempHistory.length > 0) {
                    root.tempMin = Math.min(...root.tempHistory)
                    root.tempMax = Math.max(...root.tempHistory)
                }
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 10

        StatCard {
            width: (parent.width - 30) / 4
            height: parent.height
            compact: true
            glyph: "\uf2db"
            title: "CPU"
            valueText: Math.round(root.cpuPercent) + "%"
            valueColor: root.cpuPercent > 80 ? ThemeManager.accentRed : ThemeManager.accentBlue
            footerLeft: root.cpuCores + " cores"
            footerRight: "avg " + root.cpuAvg + "%"
        }

        StatCard {
            width: (parent.width - 30) / 4
            height: parent.height
            compact: true
            glyph: "\uf538"
            title: "RAM"
            valueText: Math.round(root.memPercent) + "%"
            valueColor: root.memPercent > 80 ? ThemeManager.accentRed : ThemeManager.accentCyan
            footerLeft: root.memUsedGb.toFixed(1) + " GB"
            footerRight: root.memTotalGb.toFixed(1) + " GB"
        }

        StatCard {
            width: (parent.width - 30) / 4
            height: parent.height
            compact: true
            glyph: "\uf2c9"
            title: "Temp"
            valueText: Math.round(root.tempC) + "\u00b0C"
            valueColor: root.tempC > 70 ? ThemeManager.accentRed : ThemeManager.accentGreen
            footerLeft: "min " + Math.round(root.tempMin) + "\u00b0"
            footerRight: "max " + Math.round(root.tempMax) + "\u00b0"
        }

        StatCard {
            width: (parent.width - 30) / 4
            height: parent.height
            compact: true
            glyph: "\uf0a0"
            title: "Disk"
            valueText: Math.round(root.diskPercent) + "%"
            valueColor: root.diskPercent > 80 ? ThemeManager.accentRed : ThemeManager.accentPurple
            footerLeft: root.diskUsedGb.toFixed(0) + " GB"
            footerRight: root.diskFreeGb.toFixed(0) + " GB free"
        }
    }
}

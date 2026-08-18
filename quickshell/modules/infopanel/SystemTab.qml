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

    Grid {
        anchors.fill: parent
        columns: 2
        columnSpacing: 16
        rowSpacing: 16

        StatCard {
            width: (parent.width - 16) / 2
            height: (parent.height - 16) / 2
            glyph: "\uf2db"
            title: "CPU Usage"
            valueText: Math.round(root.cpuPercent) + "%"
            valueColor: root.cpuPercent > 80 ? ThemeManager.accentRed : ThemeManager.accentBlue
            sparklineValues: root.cpuHistory
            footerLeft: "Cores: " + root.cpuCores
            footerRight: "Avg: " + root.cpuAvg + "%"
        }

        StatCard {
            width: (parent.width - 16) / 2
            height: (parent.height - 16) / 2
            glyph: "\uf538"
            title: "Memory Usage"
            valueText: Math.round(root.memPercent) + "%"
            valueColor: root.memPercent > 80 ? ThemeManager.accentRed : ThemeManager.accentCyan
            sparklineValues: root.memHistory
            footerLeft: "Used: " + root.memUsedGb.toFixed(1) + " GB"
            footerRight: "Total: " + root.memTotalGb.toFixed(1) + " GB"
        }

        Rectangle {
            width: (parent.width - 16) / 2
            height: (parent.height - 16) / 2
            color: Qt.rgba(1, 1, 1, 0.07)
            radius: 12
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "\uf0a0"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 18
                        color: ThemeManager.accentPurple
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Disk Usage"
                        font.family: ThemeManager.uiFont
                        font.pixelSize: ThemeManager.fontSizeNormal
                        font.weight: Font.Bold
                        color: ThemeManager.fgPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item { width: Math.max(0, parent.width - 210); height: 1 }
                    Text {
                        text: Math.round(root.diskPercent) + "%"
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: root.diskPercent > 80 ? ThemeManager.accentRed : ThemeManager.accentPurple
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Column {
                    width: parent.width
                    spacing: 10
                    topPadding: 8

                    Row {
                        spacing: 8
                        Text { width: 60; text: "Used:"; font.family: ThemeManager.uiFont; font.pixelSize: 13; color: ThemeManager.fgTertiary }
                        Text { text: root.diskUsedGb.toFixed(0) + " GB"; font.family: ThemeManager.uiFont; font.pixelSize: 14; font.weight: Font.Bold; color: ThemeManager.fgPrimary }
                    }
                    Row {
                        spacing: 8
                        Text { width: 60; text: "Free:"; font.family: ThemeManager.uiFont; font.pixelSize: 13; color: ThemeManager.fgTertiary }
                        Text { text: root.diskFreeGb.toFixed(0) + " GB"; font.family: ThemeManager.uiFont; font.pixelSize: 14; font.weight: Font.Bold; color: ThemeManager.accentGreen }
                    }
                    Row {
                        spacing: 8
                        Text { width: 60; text: "Total:"; font.family: ThemeManager.uiFont; font.pixelSize: 13; color: ThemeManager.fgTertiary }
                        Text { text: root.diskTotalGb.toFixed(0) + " GB"; font.family: ThemeManager.uiFont; font.pixelSize: 14; font.weight: Font.Bold; color: ThemeManager.fgPrimary }
                    }

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.10)

                        Rectangle {
                            width: parent.width * (root.diskPercent / 100)
                            height: parent.height
                            radius: 3
                            color: root.diskPercent > 80 ? ThemeManager.accentRed : ThemeManager.accentPurple
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }

        StatCard {
            width: (parent.width - 16) / 2
            height: (parent.height - 16) / 2
            glyph: "\uf2c9"
            title: "Temperature"
            valueText: Math.round(root.tempC) + "\u00b0C"
            valueColor: root.tempC > 70 ? ThemeManager.accentRed : ThemeManager.accentGreen
            sparklineValues: root.tempHistory
            footerLeft: "Min: " + Math.round(root.tempMin) + "\u00b0C"
            footerRight: "Max: " + Math.round(root.tempMax) + "\u00b0C"
        }
    }
}

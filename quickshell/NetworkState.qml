pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string connectionType: "none"
    property string device: ""
    property string connectionName: ""
    property real downloadBps: 0
    property real uploadBps: 0
    readonly property string downloadSpeedText: formatSpeed(downloadBps)
    readonly property string uploadSpeedText: formatSpeed(uploadBps)

    // Sliding window of byte counters. Displayed rates are the average over
    // this window (or whatever history we have until it fills), so the bar
    // stays calm instead of flickering with per-second spikes.
    readonly property int speedWindowSecs: 60
    property var _samples: []

    // Keep rates short and unit-suffixed so the bar's fixed-width fields
    // ("1024M") cover every value we emit without clipping.
    function formatSpeed(bps) {
        if (!(bps > 0))
            return "0B"
        if (bps < 1024)
            return `${Math.round(bps)}B`
        if (bps < 1024 * 1024) {
            const kb = bps / 1024
            return `${kb < 10 ? kb.toFixed(1) : Math.round(kb)}K`
        }
        if (bps < 1024 * 1024 * 1024) {
            const mb = bps / (1024 * 1024)
            return `${mb < 10 ? mb.toFixed(1) : Math.round(mb)}M`
        }
        const gb = bps / (1024 * 1024 * 1024)
        return `${gb < 10 ? gb.toFixed(1) : Math.round(gb)}G`
    }

    function refresh() {
        debounce.restart()
    }

    function resetSpeeds() {
        root.downloadBps = 0
        root.uploadBps = 0
        root._samples = []
    }

    function ingestCounters(rx, tx) {
        const now = Date.now() / 1000
        const prev = root._samples
        if (prev.length > 0) {
            const last = prev[prev.length - 1]
            if (rx < last.rx || tx < last.tx) {
                root.resetSpeeds()
            }
        }

        const next = []
        const cutoff = now - root.speedWindowSecs
        for (let i = 0; i < root._samples.length; i++) {
            const sample = root._samples[i]
            if (sample.t >= cutoff)
                next.push(sample)
        }
        next.push({ t: now, rx: rx, tx: tx })
        root._samples = next

        if (next.length < 2)
            return

        const first = next[0]
        const last = next[next.length - 1]
        const dt = last.t - first.t
        if (dt < 0.5)
            return

        root.downloadBps = Math.max(0, (last.rx - first.rx) / dt)
        root.uploadBps = Math.max(0, (last.tx - first.tx) / dt)
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

    Timer {
        id: speedPoll
        // Sample a few times a minute; the displayed value is the average
        // across the whole window, so sub-second polling is unnecessary.
        interval: 5000
        running: Settings.showNetworkSpeed
            && root.device.length > 0
            && root.connectionType !== "none"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!speedPoll.running)
                return
            speedProbe.running = false
            speedProbe.running = true
        }
        onRunningChanged: {
            if (!running)
                root.resetSpeeds()
        }
    }

    Process {
        id: probe
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/network-status.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    const nextType = data.type || "none"
                    const nextDevice = data.device || ""
                    if (nextDevice !== root.device || nextType !== root.connectionType)
                        root.resetSpeeds()
                    root.connectionType = nextType
                    root.device = nextDevice
                    root.connectionName = data.name || ""
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: speedProbe
        running: false
        command: ["sh", "-c", `cat /sys/class/net/${root.device}/statistics/rx_bytes /sys/class/net/${root.device}/statistics/tx_bytes 2>/dev/null`]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/)
                if (parts.length < 2)
                    return
                const rx = Number(parts[0])
                const tx = Number(parts[1])
                if (!isFinite(rx) || !isFinite(tx))
                    return
                root.ingestCounters(rx, tx)
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

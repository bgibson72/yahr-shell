import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"

IconButton {
    id: audio
    glyph: muted ? "󰝟" : (volume >= 66 ? "󰕾" : (volume >= 33 ? "󰖀" : "󰕿"))
    glyphColor: muted ? ThemeManager.border0 : ThemeManager.accentYellow
    property int volume: 50
    property bool muted: false

    onClicked: Quickshell.execDetached(["pavucontrol"])

    WheelHandler {
        onWheel: event => {
            const delta = event.angleDelta.y > 0 ? 5 : -5
            Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", delta > 0 ? "5%+" : "5%-"])
            refresh.running = true
        }
    }

    Timer {
        id: poll
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: refresh.running = true
    }

    Process {
        id: refresh
        running: false
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const match = text.match(/([0-9.]+)/)
                if (match)
                    audio.volume = Math.round(parseFloat(match[1]) * 100)
                audio.muted = text.indexOf("[MUTED]") !== -1
            }
        }
    }
}

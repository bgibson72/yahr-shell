import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Item {
    id: audio
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 40
    property int volume: 50
    property bool muted: false
    signal togglePanel()

    scale: audioMouse.pressed ? ThemeManager.iconPressScale : (audioMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
    Behavior on scale {
        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Text {
            id: audioGlyph
            text: audio.muted ? "󰝟" : (audio.volume >= 66 ? "󰕾" : (audio.volume >= 33 ? "󰖀" : "󰕿"))
            font.family: "Symbols Nerd Font"
            font.pixelSize: ThemeManager.fontSizeIcon
            color: audio.muted ? ThemeManager.border0 : ThemeManager.accentGreen
        }
        Text {
            visible: Settings.showVolumePercent
            text: audio.volume + "%"
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: audioGlyph.color
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: audioMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: audio.togglePanel()
    }

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

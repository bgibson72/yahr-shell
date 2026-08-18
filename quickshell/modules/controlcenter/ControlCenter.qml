import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 320
    height: 280
    property bool isVisible: false
    property int volume: 50
    property bool muted: false
    property int brightness: 50
    signal requestClose()

    onIsVisibleChanged: if (isVisible) { volProc.running = true; brightProc.running = true }

    Process {
        id: volProc
        running: false
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/([0-9.]+)/)
                if (match)
                    root.volume = Math.round(parseFloat(match[1]) * 100)
                root.muted = this.text.indexOf("[MUTED]") !== -1
            }
        }
    }

    Process {
        id: brightProc
        running: false
        command: ["sh", "-c", "brightnessctl -m | awk -F, '{gsub(/%/,\"\",$4); print $4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(this.text.trim())
                if (!isNaN(n))
                    root.brightness = n
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        Text {
            text: "Control Center"
            color: ThemeManager.fgPrimary
            font.family: ThemeManager.uiFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            text: `Volume  ${root.volume}%${root.muted ? " (muted)" : ""}`
            color: ThemeManager.fgSecondary
            font.family: ThemeManager.uiFont
            font.pixelSize: 12
        }
        Rectangle {
            width: parent.width
            height: 8
            radius: 4
            color: ThemeManager.surface1
            Rectangle {
                width: parent.width * root.volume / 100
                height: parent.height
                radius: 4
                color: ThemeManager.accentBlue
            }
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    const pct = Math.round(mouse.x / width * 100)
                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${pct}%`])
                    root.volume = pct
                }
            }
        }

        Text {
            text: `Brightness  ${root.brightness}%`
            color: ThemeManager.fgSecondary
            font.family: ThemeManager.uiFont
            font.pixelSize: 12
        }
        Rectangle {
            width: parent.width
            height: 8
            radius: 4
            color: ThemeManager.surface1
            Rectangle {
                width: parent.width * root.brightness / 100
                height: parent.height
                radius: 4
                color: ThemeManager.accentYellow
            }
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    const pct = Math.max(1, Math.round(mouse.x / width * 100))
                    Quickshell.execDetached(["brightnessctl", "set", `${pct}%`])
                    root.brightness = pct
                }
            }
        }

        Row {
            spacing: 8
            Repeater {
                model: [
                    { label: "Mute", cmd: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] },
                    { label: "Wi‑Fi", cmd: ["nm-connection-editor"] },
                    { label: "BT", cmd: ["blueman-manager"] }
                ]
                Rectangle {
                    id: ccBtn
                    required property var modelData
                    width: 88
                    height: 36
                    radius: 8
                    color: ccMouse.containsMouse ? ThemeManager.surface2 : ThemeManager.surface1

                    scale: ccMouse.pressed ? ThemeManager.bouncePressScale : (ccMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                    Behavior on scale {
                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: ccBtn.modelData.label
                        color: ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: ccMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(ccBtn.modelData.cmd)
                            if (ccBtn.modelData.label === "Mute")
                                volProc.running = true
                        }
                    }
                }
            }
        }
    }
}

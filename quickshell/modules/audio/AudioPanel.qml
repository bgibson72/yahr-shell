import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 300
    height: 360
    frameJoin: "right"
    slideOffsetX: -36
    slideOffsetY: -24
    entranceScale: 0.9

    property int volume: 50
    property bool muted: false
    property int micVolume: 50
    property bool micMuted: false
    property string defaultSink: ""
    property var sinks: []

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    onIsVisibleChanged: {
        if (isVisible)
            root.refresh()
    }

    function refresh() {
        volProc.running = false
        volProc.running = true
        micProc.running = false
        micProc.running = true
        sinkProc.running = false
        sinkProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Process {
        id: volProc
        running: false
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
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
        id: micProc
        running: false
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/([0-9.]+)/)
                if (match)
                    root.micVolume = Math.round(parseFloat(match[1]) * 100)
                root.micMuted = this.text.indexOf("[MUTED]") !== -1
            }
        }
    }

    Process {
        id: sinkProc
        running: false
        command: ["sh", "-c", "echo DEFAULT:$(pactl get-default-sink); pactl list short sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                let def = ""
                const out = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (line.indexOf("DEFAULT:") === 0) {
                        def = line.slice(8)
                        continue
                    }
                    const parts = line.split("\t")
                    if (parts.length < 2)
                        continue
                    const name = parts[1]
                    const desc = name.replace(/^alsa_output\./, "").replace(/[_.]/g, " ")
                    out.push({ name: name, label: desc })
                }
                root.defaultSink = def
                root.sinks = out
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: root.muted ? "󰝟" : (root.volume >= 66 ? "󰕾" : (root.volume >= 33 ? "󰖀" : "󰕿"))
                font.family: "Symbols Nerd Font"
                font.pixelSize: 18
                color: root.muted ? ThemeManager.fgTertiary : ThemeManager.accentGreen
            }
            Text {
                Layout.fillWidth: true
                text: root.muted ? "Output muted" : `Output  ${root.volume}%`
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: muteMouse.containsMouse ? ThemeManager.surface2 : ThemeManager.surface1
                Text {
                    anchors.centerIn: parent
                    text: root.muted ? "󰝟" : "󰕾"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 13
                    color: ThemeManager.fgPrimary
                }
                MouseArea {
                    id: muteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                        volProc.running = true
                    }
                }
            }
        }

        LevelSlider {
            Layout.fillWidth: true
            value: root.volume
            fillColor: root.muted ? ThemeManager.fgTertiary : ThemeManager.accentGreen
            onMoved: pct => {
                root.volume = pct
                root.muted = false
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", `${pct}%`])
            }
        }

        Text {
            text: "Output device"
            color: ThemeManager.fgTertiary
            font.family: ThemeManager.uiFont
            font.pixelSize: 11
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            clip: true
            spacing: 4
            model: root.sinks
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 28
                radius: 7
                readonly property bool active: modelData.name === root.defaultSink
                color: sinkMouse.containsMouse ? ThemeManager.surface2 : (active ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.18) : ThemeManager.surface1)

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.label
                    color: parent.active ? ThemeManager.accentBlue : ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                }

                MouseArea {
                    id: sinkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["pactl", "set-default-sink", modelData.name])
                        root.defaultSink = modelData.name
                        volProc.running = true
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: root.micMuted ? "󰍭" : "󰍬"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 16
                color: root.micMuted ? ThemeManager.fgTertiary : ThemeManager.accentBlue
            }
            Text {
                Layout.fillWidth: true
                text: root.micMuted ? "Input muted" : `Input  ${root.micVolume}%`
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: micMuteMouse.containsMouse ? ThemeManager.surface2 : ThemeManager.surface1
                Text {
                    anchors.centerIn: parent
                    text: root.micMuted ? "󰍭" : "󰍬"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 13
                    color: ThemeManager.fgPrimary
                }
                MouseArea {
                    id: micMuteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                        micProc.running = true
                    }
                }
            }
        }

        LevelSlider {
            Layout.fillWidth: true
            value: root.micVolume
            fillColor: root.micMuted ? ThemeManager.fgTertiary : ThemeManager.accentBlue
            onMoved: pct => {
                root.micVolume = pct
                root.micMuted = false
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SOURCE@", `${pct}%`])
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 8
            color: moreMouse.containsMouse ? ThemeManager.surface2 : ThemeManager.surface1
            scale: moreMouse.pressed ? ThemeManager.bouncePressScale : (moreMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            Text {
                anchors.centerIn: parent
                text: "Audio settings"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
            }
            MouseArea {
                id: moreMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["pavucontrol"])
                    root.requestClose()
                }
            }
        }
    }
}

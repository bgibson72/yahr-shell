import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../components"
import "../.."

Panel {
    id: root
    width: 280
    height: 288
    frameJoin: "right"
    slideOffsetX: -36
    slideOffsetY: -24
    entranceScale: 0.9

    property int brightness: 50

    signal requestClose()

    readonly property bool hasBattery: PowerState.hasBattery
    readonly property int percent: PowerState.percent
    readonly property bool charging: PowerState.charging
    readonly property bool pluggedIn: PowerState.pluggedIn

    focus: true
    Keys.onEscapePressed: root.requestClose()

    onIsVisibleChanged: {
        if (isVisible)
            brightProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    function formatEta(seconds) {
        const n = Math.round(seconds)
        if (!n || n <= 0)
            return ""
        const h = Math.floor(n / 3600)
        const m = Math.round((n % 3600) / 60)
        if (h > 0)
            return `${h}h ${m}m`
        return `${m}m`
    }

    readonly property string statusText: {
        if (!root.hasBattery)
            return root.pluggedIn ? "On AC power" : "No battery"
        if (root.charging) {
            const eta = root.formatEta(PowerState.seconds)
            return eta ? `Charging · ${eta} to full` : "Charging"
        }
        if (PowerState.full)
            return "Full"
        if (root.pluggedIn)
            return "Plugged in"
        const eta = root.formatEta(PowerState.seconds)
        return eta ? `${eta} remaining` : "On battery"
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

    function setProfile(id) {
        if (id === "saver")
            PowerProfiles.profile = PowerProfile.PowerSaver
        else if (id === "performance")
            PowerProfiles.profile = PowerProfile.Performance
        else
            PowerProfiles.profile = PowerProfile.Balanced
    }

    readonly property string activeProfile: {
        const p = PowerProfiles.profile
        if (p === PowerProfile.PowerSaver)
            return "saver"
        if (p === PowerProfile.Performance)
            return "performance"
        return "balanced"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: {
                    if (!root.hasBattery || (root.pluggedIn && !root.charging))
                        return "󰚥"
                    if (root.charging)
                        return "󰂄"
                    const pct = root.percent
                    if (pct >= 95) return "󰁹"
                    if (pct >= 80) return "󰂁"
                    if (pct >= 60) return "󰁿"
                    if (pct >= 40) return "󰁽"
                    if (pct >= 20) return "󰁻"
                    return "󰂃"
                }
                font.family: "Symbols Nerd Font"
                font.pixelSize: 22
                color: {
                    if (!root.hasBattery || (root.pluggedIn && !root.charging))
                        return ThemeManager.accentBlue
                    if (root.charging)
                        return ThemeManager.accentGreen
                    if (root.percent <= 15)
                        return ThemeManager.accentRed
                    if (root.percent <= 30)
                        return ThemeManager.accentYellow
                    return ThemeManager.accentGreen
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: root.hasBattery ? `${root.percent}%` : "Power"
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.statusText
                    color: ThemeManager.fgSecondary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                }
            }
        }

        Text {
            text: "Power profile"
            color: ThemeManager.fgTertiary
            font.family: ThemeManager.uiFont
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { id: "saver", label: "Saver", glyph: "󰌪" },
                    { id: "balanced", label: "Balanced", glyph: "󰗑" },
                    { id: "performance", label: "Perf", glyph: "󰓅" }
                ]

                Rectangle {
                    id: profChip
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 8
                    readonly property bool active: root.activeProfile === modelData.id
                    color: active ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.22) : ThemeManager.surface1
                    scale: profMouse.pressed ? ThemeManager.bouncePressScale : (profMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                    Behavior on scale {
                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: profChip.modelData.glyph
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 13
                            color: profChip.active ? ThemeManager.accentBlue : ThemeManager.fgSecondary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: profChip.modelData.label
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 10
                            color: ThemeManager.fgPrimary
                        }
                    }

                    MouseArea {
                        id: profMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setProfile(profChip.modelData.id)
                    }
                }
            }
        }

        Text {
            text: `Brightness  ${root.brightness}%`
            color: ThemeManager.fgSecondary
            font.family: ThemeManager.uiFont
            font.pixelSize: 12
        }

        LevelSlider {
            Layout.fillWidth: true
            value: root.brightness
            fillColor: ThemeManager.accentYellow
            onMoved: pct => {
                root.brightness = pct
                Quickshell.execDetached(["brightnessctl", "set", `${Math.max(1, pct)}%`])
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
                text: "Power settings"
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
                    Quickshell.execDetached(["tuned-gui"])
                    root.requestClose()
                }
            }
        }
    }
}

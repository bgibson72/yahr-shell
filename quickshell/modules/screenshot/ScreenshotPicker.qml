import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 420
    height: 200

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    function capture(mode) {
        proc.command = [
            `${Quickshell.shellDir}/scripts/take-screenshot.sh`,
            mode,
            Settings.screenshotSaveToDisk ? "true" : "false",
            Settings.screenshotCopyToClipboard ? "true" : "false",
            Settings.screenshotDir
        ]
        // Close first so the picker itself never ends up in the shot, and so
        // region/window selection isn't fighting it for input focus.
        root.requestClose()
        startTimer.mode = mode
        startTimer.start()
    }

    Timer {
        id: startTimer
        interval: 120
        repeat: false
        property string mode: ""
        onTriggered: proc.running = true
    }

    Process {
        id: proc
        running: false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Take a Screenshot"
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeLarge
            font.weight: Font.DemiBold
            color: ThemeManager.fgPrimary
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Repeater {
                model: [
                    { mode: "output", glyph: "\uf26c", label: "Workspace", color: ThemeManager.accentBlue },
                    { mode: "window", glyph: "\uf2d0", label: "Window", color: ThemeManager.accentGreen },
                    { mode: "region", glyph: "\uf125", label: "Selection", color: ThemeManager.accentPurple }
                ]

                Rectangle {
                    id: modeCard
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, modeMouse.containsMouse ? 0.25 : 0.10)
                    border.width: 1
                    border.color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, modeMouse.containsMouse ? 0.6 : 0.25)

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    scale: modeMouse.pressed ? ThemeManager.bouncePressScale : (modeMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                    Behavior on scale {
                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modeCard.modelData.glyph
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 28
                            color: modeCard.modelData.color
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modeCard.modelData.label
                            font.family: ThemeManager.uiFont
                            font.pixelSize: ThemeManager.fontSizeSmall
                            color: ThemeManager.fgPrimary
                        }
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.capture(modeCard.modelData.mode)
                    }
                }
            }
        }
    }
}

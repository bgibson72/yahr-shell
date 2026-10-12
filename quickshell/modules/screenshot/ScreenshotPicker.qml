import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../.."

Panel {
    id: root
    width: 420
    height: 310

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    function capture(mode) {
        // Detach before/as the picker closes. A child Process is torn down with
        // the overlay window, which aborted delayed captures (e.g. 5s Workspace).
        const cmd = [
            "bash",
            `${Quickshell.shellDir}/scripts/take-screenshot.sh`,
            mode,
            "true",
            Settings.screenshotCopyToClipboard ? "true" : "false",
            Settings.screenshotDir,
            String(Settings.screenshotDelay)
        ]
        root.requestClose()
        Quickshell.execDetached(cmd)
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
            Layout.preferredHeight: 100
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

                    Behavior on color { ColorAnimation { duration: 150 } }

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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Delay"
                font.family: ThemeManager.uiFont
                font.pixelSize: ThemeManager.fontSizeSmall
                color: ThemeManager.fgSecondary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [0, 1, 2, 3, 4, 5]

                    Rectangle {
                        id: delayChip
                        required property int modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 6
                        readonly property bool selected: Settings.screenshotDelay === modelData
                        color: selected ? ThemeManager.accentBlue : ThemeManager.surface1

                        scale: delayMouse.pressed ? ThemeManager.bouncePressScale : (delayMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                        Behavior on scale {
                            SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: delayChip.modelData === 0 ? "0s" : `${delayChip.modelData}s`
                            font.family: ThemeManager.uiFont
                            font.pixelSize: ThemeManager.fontSizeSmall
                            color: delayChip.selected ? ThemeManager.bgBase : ThemeManager.fgPrimary
                        }

                        MouseArea {
                            id: delayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Settings.screenshotDelay = delayChip.modelData
                                Settings.save()
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Copy to clipboard"
                font.family: ThemeManager.uiFont
                font.pixelSize: 13
                color: ThemeManager.fgPrimary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                id: clipToggle
                Layout.preferredWidth: 42
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                color: Settings.screenshotCopyToClipboard ? ThemeManager.accentBlue : ThemeManager.surface2

                scale: clipMouse.pressed ? ThemeManager.bouncePressScale : (clipMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    x: Settings.screenshotCopyToClipboard ? 22 : 2
                    y: 2
                    color: ThemeManager.fgPrimary
                    Behavior on x { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: clipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Settings.screenshotCopyToClipboard = !Settings.screenshotCopyToClipboard
                        Settings.save()
                    }
                }
            }
        }
    }
}

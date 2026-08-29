import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 300
    height: 280
    frameJoin: "right"
    slideOffsetX: -36
    slideOffsetY: -24
    entranceScale: 0.9

    property bool powered: false
    property bool available: true

    ListModel { id: deviceModel }

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    onIsVisibleChanged: {
        if (isVisible)
            root.refresh()
    }

    function refresh() {
        statusProc.running = false
        statusProc.running = true
        devicesProc.running = false
        devicesProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Process {
        id: statusProc
        running: false
        command: ["sh", "-c", "command -v bluetoothctl >/dev/null 2>&1 || { echo missing; exit 0; }; rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes' && echo off || echo on"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                if (t === "missing") {
                    root.available = false
                    root.powered = false
                    return
                }
                root.available = true
                root.powered = t === "on"
            }
        }
    }

    Process {
        id: devicesProc
        running: false
        command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | while IFS= read -r line; do echo \"${line#Device }\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                deviceModel.clear()
                const lines = this.text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (!line)
                        continue
                    const sp = line.indexOf(" ")
                    const name = sp === -1 ? line : line.slice(sp + 1).trim()
                    if (name)
                        deviceModel.append({ deviceName: name })
                }
            }
        }
    }

    Process {
        id: powerToggle
        running: false
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: root.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.powered ? "󰂯" : "󰂲"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 22
                color: root.powered ? ThemeManager.accentGreen : ThemeManager.fgTertiary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Bluetooth"
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: {
                        if (!root.available)
                            return "Adapter not found"
                        if (!root.powered)
                            return "Off"
                        if (deviceModel.count > 0)
                            return deviceModel.count === 1 ? "1 device connected" : `${deviceModel.count} devices connected`
                        return "No devices connected"
                    }
                    color: ThemeManager.fgSecondary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: 44
                height: 24
                radius: 12
                color: root.powered ? ThemeManager.accentGreen : ThemeManager.surface1
                Behavior on color { ColorAnimation { duration: 140 } }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: ThemeManager.fgPrimary
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.powered ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        powerToggle.command = ["rfkill", root.powered ? "block" : "unblock", "bluetooth"]
                        powerToggle.running = true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: ThemeManager.overlay(0.08)
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: deviceModel
            boundsBehavior: Flickable.StopAtBounds

            Text {
                visible: deviceModel.count === 0
                anchors.centerIn: parent
                text: !root.available ? "Bluetooth tools not installed" : (root.powered ? "No connected devices" : "Turn Bluetooth on to connect")
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
            }

            delegate: Rectangle {
                required property string deviceName
                width: ListView.view.width
                height: 32
                radius: 8
                color: ThemeManager.surface1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    text: deviceName
                    elide: Text.ElideRight
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                }
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
                text: "Bluetooth settings"
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
                    Quickshell.execDetached(["sh", "-c", "command -v blueman-manager >/dev/null && exec blueman-manager; command -v blueberry >/dev/null && exec blueberry; command -v gnome-control-center >/dev/null && exec gnome-control-center bluetooth; exec xdg-open bluetooth:"])
                    root.requestClose()
                }
            }
        }
    }
}

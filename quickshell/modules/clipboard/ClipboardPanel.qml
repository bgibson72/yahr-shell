import QtQuick
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 480
    height: 420
    property var items: []
    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()
    onIsVisibleChanged: if (isVisible) hist.running = true

    Process {
        id: hist
        running: false
        command: ["sh", "-c", "cliphist list | head -n 40"]
        stdout: StdioCollector {
            onStreamFinished: root.items = this.text.split("\n").filter(l => l.length > 0)
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
            text: "Clipboard"
            color: ThemeManager.fgPrimary
            font.family: ThemeManager.uiFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        ListView {
            width: parent.width
            height: parent.height - 36
            clip: true
            model: root.items
            spacing: 4
            delegate: Rectangle {
                id: clipRow
                required property var modelData
                width: ListView.view.width
                height: 40
                radius: 6
                color: mouse.containsMouse ? ThemeManager.surface1 : "transparent"

                scale: mouse.pressed ? ThemeManager.bouncePressScale : 1.0
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }

                Text {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: clipRow.modelData
                    elide: Text.ElideRight
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["sh", "-c", `cliphist decode ${JSON.stringify(clipRow.modelData.split("\t")[0])} | wl-copy`])
                        root.requestClose()
                    }
                }
            }
        }
    }
}

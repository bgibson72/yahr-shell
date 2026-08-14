import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../components"

Panel {
    id: root
    width: 340
    height: 480
    property bool isVisible: false
    property var themes: []
    property int hoverIndex: -1
    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    onIsVisibleChanged: if (isVisible) listProc.running = true

    Process {
        id: listProc
        running: false
        command: ["yahr-theme", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const out = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (!line)
                        continue
                    const parts = line.replace(/^\*\s*/, "").replace(/^\s+/, "").split(/\s{2,}/)
                    if (parts.length >= 1)
                        out.push({ id: parts[0].trim(), name: (parts[1] || parts[0]).trim(), active: line.trim().startsWith("*") })
                }
                root.themes = out
            }
        }
    }

    Process {
        id: applyProc
        running: false
        property string themeId: ""
        command: ["yahr-theme", "apply", themeId]
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            text: "Select Theme"
            color: ThemeManager.fgPrimary
            font.family: ThemeManager.uiFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            width: parent.width
            height: parent.height - 40
            clip: true
            model: root.themes
            spacing: 6

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 44
                radius: 8
                color: {
                    if (index === root.hoverIndex) return ThemeManager.accentBlue
                    if (modelData.active) return Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.25)
                    return "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 13
                    color: index === root.hoverIndex ? ThemeManager.bgBase : ThemeManager.fgPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverIndex = index
                    onExited: root.hoverIndex = -1
                    onClicked: {
                        applyProc.themeId = modelData.id
                        applyProc.running = true
                        root.requestClose()
                    }
                }
            }
        }
    }
}

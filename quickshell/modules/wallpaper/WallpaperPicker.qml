import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../components"

Panel {
    id: root
    width: 820
    height: 560
    property bool isVisible: false
    property bool themeOnly: true
    property var images: []
    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    onIsVisibleChanged: if (isVisible) scan.running = true

    Process {
        id: scan
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/list-wallpapers.py`, root.themeOnly ? ThemeManager.wallpaperDir : "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                root.images = lines
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Row {
            width: parent.width
            spacing: 8
            Text {
                text: "Wallpapers"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 16
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - 280; height: 1 }
            Repeater {
                model: [
                    { label: "Theme", value: true },
                    { label: "All", value: false }
                ]
                Rectangle {
                    required property var modelData
                    width: 72
                    height: 28
                    radius: 6
                    color: root.themeOnly === modelData.value ? ThemeManager.accentBlue : ThemeManager.surface1
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.themeOnly === modelData.value ? ThemeManager.bgBase : ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.themeOnly = modelData.value
                            scan.running = true
                        }
                    }
                }
            }
        }

        GridView {
            id: grid
            width: parent.width
            height: parent.height - 48
            cellWidth: 190
            cellHeight: 120
            clip: true
            model: root.images

            delegate: Item {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight

                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: "file://" + modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["swww", "img", modelData, "--transition-type", "fade"])
                        Quickshell.execDetached(["sh", "-c", `echo '${modelData}' > "$HOME/.config/yahr/last-wallpaper"`])
                        root.requestClose()
                    }
                }
            }
        }
    }
}

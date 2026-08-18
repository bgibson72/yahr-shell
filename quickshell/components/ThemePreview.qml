import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Small swatch strip showing a theme's accent + background colors, fetched
// on demand via scripts/theme-colors.py so switchers/cards don't need to
// apply a theme just to preview it.
Item {
    id: root

    property string themeId: ""
    property var colors: ({})
    readonly property bool loaded: colors.bgBase !== undefined

    implicitWidth: 64
    implicitHeight: 18

    onThemeIdChanged: {
        if (themeId) {
            colors = {}
            loader.running = true
        }
    }
    Component.onCompleted: if (themeId) loader.running = true

    Process {
        id: loader
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/theme-colors.py`, root.themeId]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.colors = JSON.parse(this.text)
                } catch (e) {
                    root.colors = {}
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.colors.bgMantle || "#181825"
        visible: root.loaded

        Row {
            anchors.fill: parent
            anchors.margins: 2
            spacing: 2

            Repeater {
                model: ["accentBlue", "accentPurple", "accentPink", "accentRed", "accentYellow", "accentGreen"]

                Rectangle {
                    width: (parent.width - 5 * 2) / 6
                    height: parent.height
                    radius: 2
                    color: root.colors[modelData] || "#89b4fa"
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 512
    height: 520
    frameJoin: "left"
    slideOffsetX: -70
    slideOffsetY: -50
    entranceScale: 0.82
    property int selectedIndex: 0
    property string searchText: ""
    readonly property bool gridView: Settings.launcherGridView
    readonly property int gridCols: 4

    signal requestClose()

    ListModel { id: apps }
    ListModel { id: filtered }

    function refreshFilter() {
        filtered.clear()
        const q = searchText.toLowerCase()
        for (let i = 0; i < apps.count; i++) {
            const app = apps.get(i)
            if (q === "" || app.appName.toLowerCase().includes(q) || app.appDescription.toLowerCase().includes(q))
                filtered.append(app)
        }
        selectedIndex = 0
    }

    function launch(index) {
        if (index < 0 || index >= filtered.count)
            return
        const app = filtered.get(index)
        root.requestClose()
        Qt.callLater(() => {
            if (app.needsTerminal)
                Quickshell.execDetached([ThemeManager.terminal, "-e", "sh", "-c", app.appCommand])
            else
                Quickshell.execDetached(["sh", "-c", app.appCommand])
        })
    }

    function setGridView(on) {
        Settings.launcherGridView = on
        Settings.save()
    }

    onIsVisibleChanged: {
        if (isVisible) {
            searchText = ""
            searchField.text = ""
            searchField.forceActiveFocus()
            loader.running = false
            loader.running = true
        }
    }

    Process {
        id: loader
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/list-apps.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                apps.clear()
                const lines = this.text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (!line)
                        continue
                    const parts = line.split("|")
                    if (parts.length >= 4) {
                        apps.append({
                            appName: parts[0],
                            appDescription: parts[1],
                            appIcon: parts[2],
                            appCommand: parts[3],
                            needsTerminal: parts.length >= 5 && parts[4].toLowerCase() === "true"
                        })
                    }
                }
                root.refreshFilter()
            }
        }
    }

    Keys.onEscapePressed: root.requestClose()
    Keys.onReturnPressed: root.launch(selectedIndex)
    Keys.onDownPressed: {
        const step = root.gridView ? root.gridCols : 1
        selectedIndex = Math.min(selectedIndex + step, filtered.count - 1)
    }
    Keys.onUpPressed: {
        const step = root.gridView ? root.gridCols : 1
        selectedIndex = Math.max(selectedIndex - step, 0)
    }
    Keys.onLeftPressed: {
        if (root.gridView)
            selectedIndex = Math.max(selectedIndex - 1, 0)
    }
    Keys.onRightPressed: {
        if (root.gridView)
            selectedIndex = Math.min(selectedIndex + 1, filtered.count - 1)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            InputField {
                id: searchField
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 36
                placeholderText: "Search apps…"
                font.pixelSize: 16
                background: Rectangle {
                    color: ThemeManager.cardColor
                    radius: 8
                }
                onTextChanged: {
                    root.searchText = text
                    root.refreshFilter()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                anchors.bottomMargin: 44
                visible: !root.gridView
                clip: true
                model: filtered
                currentIndex: root.selectedIndex
                spacing: 4
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: appRow
                    required property int index
                    required property string appName
                    required property string appDescription
                    required property string appIcon
                    width: list.width
                    height: 52
                    radius: 8
                    color: index === root.selectedIndex ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.25) : "transparent"

                    scale: rowMouse.pressed ? ThemeManager.bouncePressScale : 1.0
                    Behavior on scale {
                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12
                        AppIcon {
                            iconName: appIcon
                            pixelSize: 32
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: appName
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 14
                            }
                            Text {
                                text: appDescription
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: list.width - 80
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: root.launch(index)
                    }
                }
            }

            GridView {
                id: grid
                anchors.fill: parent
                anchors.bottomMargin: 44
                visible: root.gridView
                clip: true
                model: filtered
                currentIndex: root.selectedIndex
                cellWidth: Math.floor(width / root.gridCols)
                cellHeight: 108
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    id: gridCell
                    required property int index
                    required property string appName
                    required property string appIcon
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 10
                        color: {
                            if (gridMouse.pressed)
                                return Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.32)
                            if (gridCell.index === root.selectedIndex || gridMouse.containsMouse)
                                return Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.16)
                            return "transparent"
                        }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            width: parent.width - 10

                            AppIcon {
                                iconName: appIcon
                                pixelSize: 44
                                anchors.horizontalCenter: parent.horizontalCenter
                                fallbackColor: ThemeManager.fgPrimary
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: appName
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    MouseArea {
                        id: gridMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: root.launch(index)
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                spacing: 4

                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: root.gridView
                        ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.28)
                        : (gridToggleMouse.containsMouse ? ThemeManager.surface1 : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00a"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: root.gridView ? ThemeManager.accentBlue : ThemeManager.fgTertiary
                    }
                    MouseArea {
                        id: gridToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setGridView(true)
                    }
                }

                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: !root.gridView
                        ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.28)
                        : (listToggleMouse.containsMouse ? ThemeManager.surface1 : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00b"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: !root.gridView ? ThemeManager.accentBlue : ThemeManager.fgTertiary
                    }
                    MouseArea {
                        id: listToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setGridView(false)
                    }
                }
            }
        }
    }
}

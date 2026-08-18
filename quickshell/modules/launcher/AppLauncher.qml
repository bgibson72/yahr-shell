import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 720
    height: 520
    slideOffsetX: -70
    slideOffsetY: -50
    entranceScale: 0.82
    property int selectedIndex: 0
    property string searchText: ""

    signal requestClose()
    signal openSettings()

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
                Quickshell.execDetached(["kitty", "-e", "sh", "-c", app.appCommand])
            else
                Quickshell.execDetached(["sh", "-c", app.appCommand])
        })
    }

    onIsVisibleChanged: {
        if (isVisible) {
            searchText = ""
            searchField.text = ""
            searchField.forceActiveFocus()
            if (apps.count === 0)
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
    Keys.onDownPressed: selectedIndex = Math.min(selectedIndex + 1, filtered.count - 1)
    Keys.onUpPressed: selectedIndex = Math.max(selectedIndex - 1, 0)

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Row {
            width: parent.width
            spacing: 8
            TextField {
                id: searchField
                width: parent.width - 48
                placeholderText: "Search apps…"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 16
                background: Rectangle {
                    color: ThemeManager.surface0
                    radius: 8
                    border.color: ThemeManager.accentBorder
                    border.width: 1
                }
                onTextChanged: {
                    root.searchText = text
                    root.refreshFilter()
                }
            }
            Text {
                text: "󰒓"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 20
                color: ThemeManager.fgSecondary
                anchors.verticalCenter: parent.verticalCenter

                scale: launcherSettingsMouse.pressed ? ThemeManager.iconPressScale : (launcherSettingsMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }

                MouseArea {
                    id: launcherSettingsMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSettings()
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 56
            clip: true
            model: filtered
            currentIndex: root.selectedIndex
            spacing: 4

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
                    Image {
                        width: 32
                        height: 32
                        source: appIcon.startsWith("/") ? appIcon : `image://icon/${appIcon}`
                        fillMode: Image.PreserveAspectFit
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
    }
}

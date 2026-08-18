import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

// Searchable app list for pinning apps to the dock. Reuses the same
// scripts/list-apps.py discovery as AppLauncher.qml.
Panel {
    id: root
    width: 380
    height: 480
    property bool isVisible: false
    property string searchText: ""

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    ListModel { id: apps }
    ListModel { id: filtered }

    function refreshFilter() {
        filtered.clear()
        const q = searchText.toLowerCase()
        for (let i = 0; i < apps.count; i++) {
            const app = apps.get(i)
            if (q === "" || app.appName.toLowerCase().includes(q))
                filtered.append(app)
        }
    }

    function isPinned(desktopId) {
        const pinned = Settings.dockPinnedApps || []
        for (let i = 0; i < pinned.length; i++) {
            if (pinned[i].desktopId === desktopId)
                return true
        }
        return false
    }

    function togglePin(app) {
        const pinned = (Settings.dockPinnedApps || []).slice()
        const idx = pinned.findIndex(a => a.desktopId === app.desktopId)
        if (idx !== -1) {
            pinned.splice(idx, 1)
        } else {
            pinned.push({
                desktopId: app.desktopId,
                name: app.appName,
                icon: app.appIcon,
                exec: app.appCommand,
                terminal: app.needsTerminal
            })
        }
        Settings.dockPinnedApps = pinned
        Settings.save()
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
                    if (parts.length >= 6) {
                        apps.append({
                            appName: parts[0],
                            appIcon: parts[2],
                            appCommand: parts[3],
                            needsTerminal: parts[4].toLowerCase() === "true",
                            desktopId: parts[5]
                        })
                    }
                }
                root.refreshFilter()
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
                text: "Pin an Application"
                font.family: ThemeManager.uiFont
                font.pixelSize: ThemeManager.fontSizeLarge
                font.weight: Font.DemiBold
                color: ThemeManager.fgPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 220; height: 1 }

            Text {
                text: "\u2715"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: closeMouse.containsMouse ? ThemeManager.accentRed : ThemeManager.fgSecondary
                anchors.verticalCenter: parent.verticalCenter

                scale: closeMouse.pressed ? ThemeManager.iconPressScale : (closeMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestClose()
                }
            }
        }

        TextField {
            id: searchField
            width: parent.width
            placeholderText: "Search apps…"
            color: ThemeManager.fgPrimary
            font.family: ThemeManager.uiFont
            font.pixelSize: 14
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

        ListView {
            id: list
            width: parent.width
            height: parent.height - 88
            clip: true
            model: filtered
            spacing: 2

            delegate: Rectangle {
                id: appRow
                required property string appName
                required property string appIcon
                required property string desktopId
                width: list.width
                height: 44
                radius: 8
                readonly property bool pinned: root.isPinned(desktopId)
                color: rowMouse.containsMouse && !pinned ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 10

                    Image {
                        width: 26
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        source: appIcon.startsWith("/") ? appIcon : `image://icon/${appIcon}`
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        text: appName
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 13
                        color: ThemeManager.fgPrimary
                        anchors.verticalCenter: parent.verticalCenter
                        width: list.width - 90
                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: appRow.pinned
                    text: "Pinned"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 10
                    color: ThemeManager.accentGreen
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: appRow.pinned ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!appRow.pinned)
                            root.togglePin(filtered.get(index))
                    }
                }
            }
        }
    }
}

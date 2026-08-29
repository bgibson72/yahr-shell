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

    function copyPinned() {
        const src = Settings.dockPinnedApps || []
        const out = []
        for (let i = 0; i < src.length; i++) {
            const a = src[i]
            out.push({
                desktopId: a.desktopId,
                name: a.name,
                icon: a.icon,
                exec: a.exec,
                terminal: !!a.terminal
            })
        }
        return out
    }

    function isPinned(desktopId) {
        const pinned = Settings.dockPinnedApps || []
        for (let i = 0; i < pinned.length; i++) {
            if (pinned[i].desktopId === desktopId)
                return true
        }
        return false
    }

    function pinApp(app) {
        if (!app || !app.desktopId || root.isPinned(app.desktopId))
            return
        const pinned = root.copyPinned()
        pinned.push({
            desktopId: app.desktopId,
            name: app.appName,
            icon: app.appIcon,
            exec: app.appCommand,
            terminal: !!app.needsTerminal
        })
        Settings.dockPinnedApps = pinned
        Settings.save()
    }

    function unpinApp(desktopId) {
        if (!desktopId)
            return
        const pinned = root.copyPinned().filter(a => a.desktopId !== desktopId)
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

    Text {
        z: 2
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.rightMargin: 16
        text: "\u2715"
        font.family: "Symbols Nerd Font"
        font.pixelSize: 14
        color: closeMouse.containsMouse ? ThemeManager.accentRed : ThemeManager.fgSecondary

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

    Column {
        z: 1
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: "Pin an Application"
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeLarge
            font.weight: Font.DemiBold
            color: ThemeManager.fgPrimary
        }

        InputField {
            id: searchField
            width: parent.width
            placeholderText: "Search apps…"
            font.pixelSize: 14
            background: Rectangle {
                color: ThemeManager.cardColor
                radius: 8
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
                required property string appCommand
                required property var needsTerminal
                required property string desktopId
                width: list.width
                height: 44
                radius: 8
                readonly property bool pinned: root.isPinned(desktopId)
                color: rowMouse.containsMouse ? ThemeManager.overlay(0.08) : "transparent"

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !appRow.pinned
                    cursorShape: appRow.pinned ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.pinApp({
                        desktopId: appRow.desktopId,
                        appName: appRow.appName,
                        appIcon: appRow.appIcon,
                        appCommand: appRow.appCommand,
                        needsTerminal: appRow.needsTerminal
                    })
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    spacing: 10

                    AppIcon {
                        iconName: appRow.appIcon
                        pixelSize: 26
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: appRow.appName
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 13
                        color: ThemeManager.fgPrimary
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(40, parent.width - 36 - (appRow.pinned ? 128 : 0))
                        elide: Text.ElideRight
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    visible: appRow.pinned
                    z: 2

                    Text {
                        text: "Pinned"
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 10
                        color: ThemeManager.accentGreen
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 64
                        height: 24
                        radius: 6
                        color: removeMouse.containsMouse
                            ? Qt.rgba(ThemeManager.accentRed.r, ThemeManager.accentRed.g, ThemeManager.accentRed.b, 0.28)
                            : ThemeManager.overlay(0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "Remove"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                            color: removeMouse.containsMouse ? ThemeManager.accentRed : ThemeManager.fgSecondary
                        }

                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.unpinApp(appRow.desktopId)
                        }
                    }
                }
            }
        }
    }
}

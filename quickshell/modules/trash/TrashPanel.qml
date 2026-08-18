import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 480
    height: 600
    property bool isVisible: false
    property var items: []
    property var selectedNames: []

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    onIsVisibleChanged: {
        if (isVisible) {
            selectedNames = []
            refresh()
        }
    }

    function refresh() { listLoader.running = true }

    function isSelected(name) { return root.selectedNames.indexOf(name) !== -1 }

    function toggleSelected(name) {
        const idx = root.selectedNames.indexOf(name)
        if (idx === -1) root.selectedNames = root.selectedNames.concat([name])
        else root.selectedNames = root.selectedNames.filter(n => n !== name)
    }

    function restoreOne(name) {
        actionProc.pendingRefresh = true
        actionProc.command = ["bash", `${Quickshell.shellDir}/scripts/trash-manager.sh`, "restore", name]
        actionProc.running = true
    }

    function deleteOne(name) {
        actionProc.pendingRefresh = true
        actionProc.command = ["bash", `${Quickshell.shellDir}/scripts/trash-manager.sh`, "delete", name]
        actionProc.running = true
    }

    function restoreSelected() {
        const names = root.selectedNames.slice()
        root.selectedNames = []
        for (let i = 0; i < names.length; i++) {
            actionProc.pendingRefresh = (i === names.length - 1)
            actionProc.command = ["bash", `${Quickshell.shellDir}/scripts/trash-manager.sh`, "restore", names[i]]
            actionProc.running = true
        }
    }

    function emptyTrash() {
        root.selectedNames = []
        actionProc.pendingRefresh = true
        actionProc.command = ["bash", `${Quickshell.shellDir}/scripts/trash-manager.sh`, "empty"]
        actionProc.running = true
    }

    function humanSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    function formatDate(iso) {
        const d = new Date(iso)
        if (isNaN(d.getTime())) return iso
        return Qt.formatDateTime(d, "MMM d, h:mm AP")
    }

    Process {
        id: listLoader
        running: false
        command: ["bash", `${Quickshell.shellDir}/scripts/trash-manager.sh`, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.items = JSON.parse(this.text)
                } catch (e) {
                    root.items = []
                }
            }
        }
    }

    Process {
        id: actionProc
        running: false
        property bool pendingRefresh: false
        onExited: {
            if (pendingRefresh) {
                pendingRefresh = false
                root.refresh()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "\uf1f8  Trash"
                font.family: ThemeManager.uiFont
                font.pixelSize: ThemeManager.fontSizeLarge
                font.weight: Font.DemiBold
                color: ThemeManager.fgPrimary
            }

            Item { Layout.fillWidth: true }

            Text {
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
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: ThemeManager.surface0
            radius: 12

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6
                clip: true
                model: root.items

                delegate: Rectangle {
                    id: itemRow
                    required property var modelData
                    width: list.width
                    height: 60
                    radius: 8
                    color: itemArea.containsMouse ? ThemeManager.surface1 : ThemeManager.surface0
                    border.width: 1
                    border.color: root.isSelected(modelData.name) ? ThemeManager.accentBlue : ThemeManager.surface2

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        anchors.rightMargin: 96
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleSelected(itemRow.modelData.name)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            Layout.alignment: Qt.AlignVCenter
                            color: root.isSelected(itemRow.modelData.name) ? ThemeManager.accentBlue : "transparent"
                            border.width: 1
                            border.color: root.isSelected(itemRow.modelData.name) ? ThemeManager.accentBlue : ThemeManager.surface2

                            Text {
                                anchors.centerIn: parent
                                visible: root.isSelected(itemRow.modelData.name)
                                text: "\u2713"
                                font.pixelSize: 11
                                color: ThemeManager.bgBase
                            }
                        }

                        Text {
                            text: itemRow.modelData.isDir ? "\uf07b" : "\uf15b"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: ThemeManager.fgSecondary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: itemRow.modelData.name
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: ThemeManager.fgPrimary
                                elide: Text.ElideMiddle
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.formatDate(itemRow.modelData.deletionDate) + "  \u00b7  " + root.humanSize(itemRow.modelData.size)
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 10
                                color: ThemeManager.fgTertiary
                                elide: Text.ElideMiddle
                            }
                        }

                        Text {
                            text: "\uf2ea"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 15
                            color: restoreArea.containsMouse ? ThemeManager.accentGreen : ThemeManager.fgSecondary
                            Layout.alignment: Qt.AlignVCenter

                            scale: restoreArea.pressed ? ThemeManager.iconPressScale : (restoreArea.containsMouse ? ThemeManager.iconHoverScale : 1.0)
                            Behavior on scale {
                                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                            }

                            MouseArea {
                                id: restoreArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.restoreOne(itemRow.modelData.name)
                            }
                        }

                        Text {
                            text: "\uf1f8"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 15
                            color: deleteArea.containsMouse ? ThemeManager.accentRed : ThemeManager.fgSecondary
                            Layout.alignment: Qt.AlignVCenter

                            scale: deleteArea.pressed ? ThemeManager.iconPressScale : (deleteArea.containsMouse ? ThemeManager.iconHoverScale : 1.0)
                            Behavior on scale {
                                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                            }

                            MouseArea {
                                id: deleteArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteOne(itemRow.modelData.name)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Trash is empty"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 13
                    color: ThemeManager.fgTertiary
                    visible: list.count === 0
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: `${list.count} item${list.count !== 1 ? "s" : ""}`
                    + (root.selectedNames.length > 0 ? `  \u00b7  ${root.selectedNames.length} selected` : "")
                font.family: ThemeManager.uiFont
                font.pixelSize: 11
                color: ThemeManager.fgSecondary
            }

            Rectangle {
                visible: root.selectedNames.length > 0
                width: restoreSelectedLabel.implicitWidth + 20
                height: 30
                radius: 8
                color: Qt.rgba(ThemeManager.accentGreen.r, ThemeManager.accentGreen.g, ThemeManager.accentGreen.b, restoreSelectedArea.containsMouse ? 0.35 : 0.15)

                scale: restoreSelectedArea.pressed ? ThemeManager.bouncePressScale : (restoreSelectedArea.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }

                Text {
                    id: restoreSelectedLabel
                    anchors.centerIn: parent
                    text: "Restore Selected"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                    color: ThemeManager.fgPrimary
                }

                MouseArea {
                    id: restoreSelectedArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.restoreSelected()
                }
            }

            Rectangle {
                id: emptyBtn
                width: emptyLabel.implicitWidth + 20
                height: 30
                radius: 8
                property bool confirming: false
                color: confirming
                    ? Qt.rgba(ThemeManager.accentRed.r, ThemeManager.accentRed.g, ThemeManager.accentRed.b, 0.5)
                    : Qt.rgba(ThemeManager.accentRed.r, ThemeManager.accentRed.g, ThemeManager.accentRed.b, emptyArea.containsMouse ? 0.3 : 0.15)

                Behavior on color { ColorAnimation { duration: 150 } }

                scale: emptyArea.pressed ? ThemeManager.bouncePressScale : (emptyArea.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }

                Timer {
                    running: emptyBtn.confirming
                    interval: 3000
                    onTriggered: emptyBtn.confirming = false
                }

                Text {
                    id: emptyLabel
                    anchors.centerIn: parent
                    text: emptyBtn.confirming ? "Click again to confirm" : "Empty Trash"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                    color: ThemeManager.fgPrimary
                }

                MouseArea {
                    id: emptyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (emptyBtn.confirming) {
                            emptyBtn.confirming = false
                            root.emptyTrash()
                        } else {
                            emptyBtn.confirming = true
                        }
                    }
                }
            }
        }
    }
}

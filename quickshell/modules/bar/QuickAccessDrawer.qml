import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

// Collapsible strip of app launchers that live in the bar without permanently
// eating space. A "TOOLS ^" label toggles a reveal of quick-launch icons
// for apps that don't already have a dedicated bar icon elsewhere.
Item {
    id: drawer
    visible: Settings.showQuickLaunch

    signal toggleScreenshot()
    signal toggleWallpaper()
    signal toggleSettings()

    property bool expanded: false
    property bool gameModeOn: false

    implicitWidth: content.implicitWidth
    implicitHeight: 40
    Layout.leftMargin: 10

    function refreshGameMode() {
        gameModeProbe.running = false
        gameModeProbe.running = true
    }

    function toggleGameMode() {
        Quickshell.execDetached([`${Quickshell.shellDir}/scripts/toggle-gamemode.sh`, "toggle"])
        // State file write is nearly immediate; re-probe shortly after.
        gameModeRefresh.restart()
    }

    Timer {
        id: gameModeRefresh
        interval: 200
        repeat: false
        onTriggered: drawer.refreshGameMode()
    }

    Process {
        id: gameModeProbe
        running: false
        command: [`${Quickshell.shellDir}/scripts/toggle-gamemode.sh`, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = (this.text || "").trim()
                drawer.gameModeOn = text === "on"
            }
        }
    }

    FileView {
        id: gameModeFile
        path: `${Quickshell.env("HOME")}/.config/yahr/gamemode`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: drawer.refreshGameMode()
        onLoadFailed: drawer.gameModeOn = false
    }

    Component.onCompleted: drawer.refreshGameMode()

    RowLayout {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        PillGroup {
            horizontalPadding: 10
            // Scale pill chrome + TOOLS label together so the background
            // tracks the text instead of leaving a static capsule behind.
            scale: toggleMouse.pressed ? ThemeManager.barLabelPressScale : (toggleMouse.containsMouse ? ThemeManager.barLabelHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            Item {
                id: toggleBtn
                implicitWidth: labelRow.implicitWidth + 4
                implicitHeight: 40

                Row {
                    id: labelRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TOOLS"
                        font.family: ThemeManager.uiFont
                        font.pixelSize: ThemeManager.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: ThemeManager.accentBlue
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: drawer.expanded ? "\uf054" : "\uf077"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: ThemeManager.fontSizeSmall
                        color: ThemeManager.accentBlue
                    }
                }

                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: drawer.expanded = !drawer.expanded
                }
            }
        }

        Item {
            id: reveal
            Layout.preferredWidth: drawer.expanded ? revealRow.implicitWidth : 0
            Layout.preferredHeight: 40
            clip: true

            // Springy overshoot on the reveal width gives the slide its own
            // little bounce, on top of each icon plopping in individually
            // below.
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }

            RowLayout {
                id: revealRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: [
                        { glyph: "\uf07c", action: "files" },
                        { glyph: "󰊠", action: "terminal", md: true },
                        { glyph: "\uf030", action: "screenshot" },
                        { glyph: "󰈊", action: "picker", md: true },
                        { glyph: "\uf03e", action: "wallpaper" },
                        { glyph: "\uf11b", action: "gamemode" },
                        { glyph: "󰒓", action: "settings", md: true }
                    ]

                    Item {
                        id: wrap
                        required property var modelData
                        required property int index
                        width: 32
                        height: 40
                        scale: drawer.expanded ? 1.0 : 0.4
                        opacity: drawer.expanded ? 1.0 : 0.0
                        Behavior on scale {
                            SequentialAnimation {
                                PauseAnimation { duration: drawer.expanded ? wrap.index * 40 : 0 }
                                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }
                        IconButton {
                            anchors.fill: parent
                            glyph: wrap.modelData.glyph
                            glyphColor: (wrap.modelData.action === "gamemode" && drawer.gameModeOn)
                                ? ThemeManager.accentOrange
                                : ThemeManager.accentBlue
                            pixelSize: wrap.modelData.md ? ThemeManager.fontSizeIcon : ThemeManager.fontSizeIconFA
                            onClicked: {
                                switch (wrap.modelData.action) {
                                case "files": Quickshell.execDetached([`${Quickshell.shellDir}/scripts/launch-thunar.sh`]); break
                                case "terminal": Quickshell.execDetached([ThemeManager.terminal]); break
                                case "screenshot": drawer.toggleScreenshot(); break
                                case "picker": Quickshell.execDetached(["hyprpicker", "-a"]); break
                                case "wallpaper": drawer.toggleWallpaper(); break
                                case "gamemode": drawer.toggleGameMode(); break
                                case "settings": drawer.toggleSettings(); break
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

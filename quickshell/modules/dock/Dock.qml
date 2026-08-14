import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: dock
    radius: ThemeManager.hyprRounding
    color: {
        if (Settings.dockBackgroundStyle === "transparent") return "transparent"
        if (Settings.dockBackgroundStyle === "opaque") return ThemeManager.bgBase
        return Qt.rgba(ThemeManager.bgBase.r, ThemeManager.bgBase.g, ThemeManager.bgBase.b, Settings.dockOpacity)
    }
    border.width: Settings.dockShowBorder ? 1 : 0
    border.color: ThemeManager.accentBorder

    signal settingsRequested()

    readonly property int iconSize: Settings.dockIconSize
    implicitHeight: iconSize + 16
    implicitWidth: row.implicitWidth + 20

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: Settings.dockPinnedApps

            Item {
                required property var modelData
                width: dock.iconSize
                height: dock.iconSize

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: modelData.icon ? (modelData.icon.startsWith("/") || modelData.icon.startsWith("file:") ? modelData.icon : `image://icon/${modelData.icon}`) : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            const next = Settings.dockPinnedApps.filter(a => a.desktopId !== modelData.desktopId)
                            Settings.dockPinnedApps = next
                            Settings.save()
                            return
                        }
                        const cmd = modelData.exec || modelData.command
                        if (!cmd)
                            return
                        if (modelData.terminal)
                            Quickshell.execDetached(["kitty", "-e", "sh", "-c", cmd])
                        else
                            Quickshell.execDetached(["sh", "-c", cmd])
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: dock.iconSize * 0.55
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.15)
            visible: Settings.dockPinnedApps && Settings.dockPinnedApps.length > 0
        }

        Text {
            text: "󰒓"
            font.family: "Symbols Nerd Font"
            font.pixelSize: 22
            color: ThemeManager.fgSecondary
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: dock.settingsRequested()
            }
        }
    }
}

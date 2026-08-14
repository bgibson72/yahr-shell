import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"

Rectangle {
    id: bar
    color: {
        if (Settings.barBackgroundStyle === "transparent")
            return "transparent"
        if (Settings.barBackgroundStyle === "opaque")
            return ThemeManager.bgBase
        return Qt.rgba(ThemeManager.bgBase.r, ThemeManager.bgBase.g, ThemeManager.bgBase.b, Settings.barOpacity)
    }
    radius: Settings.barFloating ? ThemeManager.hyprRounding : 0
    border.width: Settings.barShowBorder ? 1 : 0
    border.color: ThemeManager.accentBorder

    signal toggleLauncher()
    signal togglePowerMenu()
    signal toggleSettings()
    signal toggleThemeSwitcher()
    signal toggleWallpaper()
    signal toggleControlCenter()
    signal toggleClipboard()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        RowLayout {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            IconButton {
                glyph: "󰣇"
                glyphColor: ThemeManager.accentBlue
                onClicked: bar.toggleLauncher()
            }

            WorkspaceBar {
                minWorkspaces: Settings.minWorkspaces
            }
        }

        Item { Layout.fillWidth: true }

        Clock {
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            IconButton {
                glyph: "󰉋"
                onClicked: Quickshell.execDetached(["thunar"])
            }
            IconButton {
                glyph: "󰘥"
                onClicked: bar.toggleThemeSwitcher()
            }
            IconButton {
                glyph: "󰸉"
                onClicked: bar.toggleWallpaper()
            }
            IconButton {
                glyph: "󰅍"
                onClicked: bar.toggleClipboard()
            }
            Audio {}
            Network {}
            Battery {}
            IconButton {
                glyph: "󰒓"
                onClicked: bar.toggleSettings()
            }
            IconButton {
                glyph: "󰐥"
                glyphColor: ThemeManager.accentRed
                onClicked: bar.togglePowerMenu()
            }
        }
    }

    MouseArea {
        z: -1
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: bar.toggleControlCenter()
    }
}

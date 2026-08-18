import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../.."

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

    Item {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            IconButton {
                glyph: "󰣇"
                glyphColor: ThemeManager.accentBlue
                onClicked: bar.toggleLauncher()
            }

            WorkspaceBar {
                minWorkspaces: Settings.minWorkspaces
            }
        }

        // Anchored to the bar's own center rather than the midpoint between
        // the two side groups, so it stays fixed relative to the display
        // regardless of how many icons end up on either side.
        Clock {
            anchors.centerIn: parent
        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            IconButton {
                glyph: "󰉋"
                onClicked: Quickshell.execDetached(["thunar"])
            }
            IconButton {
                glyph: "󰏘"
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
            SystemTray {}
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

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../.."

// Root is a plain Item (not the visual bar surface) so the bar window can be
// taller than the pill itself, letting the Arch logo button spill above and
// below the bar's edges. barBg below is the actual pill.
Item {
    id: bar

    signal toggleLauncher()
    signal togglePowerMenu()
    signal toggleSettings()
    signal toggleThemeSwitcher()
    signal toggleWallpaper()
    signal toggleControlCenter()
    signal toggleClipboard()
    signal toggleScreenshot()
    signal toggleInfoPanel()

    Rectangle {
        id: barBg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: ThemeManager.barHeight
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
    }

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
                width: ThemeManager.archIconSize
                height: ThemeManager.archIconSize
                pixelSize: Math.round(ThemeManager.archIconSize * 0.5)
                hoverScale: ThemeManager.archIconHoverScale
                pressScale: ThemeManager.archIconPressScale
                onClicked: bar.toggleLauncher()
            }

            WorkspaceBar {
                minWorkspaces: Settings.minWorkspaces
            }

            MediaPlayer {}

            QuickAccessDrawer {
                onToggleScreenshot: bar.toggleScreenshot()
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
            IconButton {
                glyph: "󰃭"
                onClicked: bar.toggleInfoPanel()
            }
            SystemTray {}
            UpdateChecker {}
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
        anchors.fill: barBg
        acceptedButtons: Qt.RightButton
        onClicked: bar.toggleControlCenter()
    }
}

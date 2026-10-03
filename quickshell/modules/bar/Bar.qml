import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../.."

// Root is a plain Item (not the visual bar surface) so the bar window can
// be slightly taller than the pill for hover bounce. barBg is the actual
// pill; archButton is the launcher mark, sized to fit inside the bar.
Item {
    id: bar

    signal toggleLauncher()
    signal togglePowerMenu()
    signal toggleNetwork()
    signal toggleBluetooth()
    signal toggleBattery()
    signal toggleAudio()
    signal toggleClipboard()
    signal toggleScreenshot()
    signal toggleWallpaper()
    signal toggleInfoPanel()
    signal toggleSettings()

    readonly property bool useIslands: Settings.barStyle === "islands"
    readonly property int islandOuterPad: 6
    readonly property int islandInnerPad: 10
    property alias maskBar: barBg
    property alias maskArch: archButton
    property alias maskLeftIsland: leftIsland
    property alias maskCenterIsland: centerIsland
    property alias maskRightIsland: rightIsland

    // In frame-and-emerge mode the bar fill and the top inverse corners are
    // the same canvas, so the corners read as a continuation of the bar
    // instead of a separate rounded cap sitting under it.
    ScreenFrame {
        z: 0
        anchors.fill: parent
        topSectionOnly: true
    }

    Rectangle {
        id: barBg
        visible: !bar.useIslands
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: ThemeManager.barPillTopMargin
        height: ThemeManager.barHeight
        color: ThemeManager.useFrameEmerge ? "transparent" : ThemeManager.barFillColor
        radius: ThemeManager.barRadius
        border.width: ThemeManager.useFrameEmerge ? 0
            : (ThemeManager.effectiveBarShowBorder ? ThemeManager.effectiveBarBorderWidth : 0)
        border.color: ThemeManager.chromeBorderColor
    }

    component IslandPill: Rectangle {
        visible: bar.useIslands
        height: ThemeManager.barHeight
        radius: ThemeManager.barRadius
        color: ThemeManager.barFillColor
        border.width: ThemeManager.effectiveBarShowBorder ? ThemeManager.effectiveBarBorderWidth : 0
        border.color: ThemeManager.chromeBorderColor
        z: 0
    }

    IslandPill {
        id: leftIsland
        anchors.verticalCenter: barBg.verticalCenter
        x: bar.islandOuterPad
        width: Math.max(ThemeManager.barHeight, leftRow.x + leftRow.width - x + bar.islandInnerPad)
    }

    IslandPill {
        id: centerIsland
        anchors.verticalCenter: barBg.verticalCenter
        anchors.horizontalCenter: clock.horizontalCenter
        width: clock.width + bar.islandInnerPad * 2
    }

    IslandPill {
        id: rightIsland
        anchors.verticalCenter: barBg.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: bar.islandOuterPad
        width: rightRow.width + bar.islandInnerPad * 2
    }

    IconButton {
        id: archButton
        z: 1
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: barBg.verticalCenter
        width: ThemeManager.archIconSize
        height: ThemeManager.archIconSize
        glyph: "󰣇"
        glyphColor: ThemeManager.accentBlue
        pixelSize: Math.round(ThemeManager.archIconSize * 0.85)
        hoverScale: ThemeManager.archIconHoverScale
        pressScale: ThemeManager.archIconPressScale
        onClicked: bar.toggleLauncher()
    }

    RowLayout {
        id: leftRow
        z: 1
        anchors.left: parent.left
        anchors.leftMargin: archButton.width + 16
        anchors.verticalCenter: barBg.verticalCenter
        spacing: 6

        PillGroup {
            horizontalPadding: 10
            WorkspaceBar {
                minWorkspaces: Settings.minWorkspaces
            }
        }

        MediaPlayer {}

        QuickAccessDrawer {
            onToggleScreenshot: bar.toggleScreenshot()
            onToggleWallpaper: bar.toggleWallpaper()
            onToggleSettings: bar.toggleSettings()
        }
    }

    Clock {
        id: clock
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: barBg.verticalCenter
        onClicked: bar.toggleInfoPanel()
    }

    RowLayout {
        id: rightRow
        z: 1
        anchors.right: parent.right
        // Islands: sit inside the right-island pill with the same inner pad
        // on both sides. Single style keeps a tighter 10px window inset.
        anchors.rightMargin: bar.useIslands ? bar.islandOuterPad + bar.islandInnerPad : 10
        anchors.verticalCenter: barBg.verticalCenter
        // Same gap between groups: updater→bluetooth and audio→power.
        spacing: 16

        PillGroup {
            SystemTray {}
            Clipboard {
                onToggleClipboard: bar.toggleClipboard()
            }
            UpdateChecker {}
        }

        PillGroup {
            Bluetooth {
                onTogglePanel: bar.toggleBluetooth()
            }
            Network {
                onTogglePanel: bar.toggleNetwork()
            }
            Battery {
                onTogglePanel: bar.toggleBattery()
            }
            Audio {
                onTogglePanel: bar.toggleAudio()
            }
        }

        PillGroup {
            circular: true
            IconButton {
                compact: true
                glyph: "󰐥"
                glyphColor: ThemeManager.accentRed
                onClicked: bar.togglePowerMenu()
            }
        }
    }
}

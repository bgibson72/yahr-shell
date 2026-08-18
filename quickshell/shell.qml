import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "modules/bar"
import "modules/dock"
import "modules/launcher"
import "modules/powermenu"
import "modules/controlcenter"
import "modules/settings"
import "modules/theme"
import "modules/wallpaper"
import "modules/clipboard"

ShellRoot {
    id: root

    property bool launcherVisible: false
    property bool powerMenuVisible: false
    property bool settingsVisible: false
    property bool themeSwitcherVisible: false
    property bool wallpaperVisible: false
    property bool controlCenterVisible: false
    property bool clipboardVisible: false
    property bool themeLoadingVisible: false
    property string themeLoadingName: ""
    property bool dockAppPickerVisible: false

    function hideOverlays() {
        launcherVisible = false
        powerMenuVisible = false
        settingsVisible = false
        themeSwitcherVisible = false
        wallpaperVisible = false
        controlCenterVisible = false
        clipboardVisible = false
        dockAppPickerVisible = false
    }

    IpcHandler {
        target: "yahr"
        function toggleLauncher() { root.launcherVisible = !root.launcherVisible }
        function togglePowerMenu() { root.powerMenuVisible = !root.powerMenuVisible }
        function toggleSettings() { root.settingsVisible = !root.settingsVisible }
        function toggleThemeSwitcher() { root.themeSwitcherVisible = !root.themeSwitcherVisible }
        function toggleWallpaper() { root.wallpaperVisible = !root.wallpaperVisible }
        function toggleControlCenter() { root.controlCenterVisible = !root.controlCenterVisible }
        function toggleClipboard() { root.clipboardVisible = !root.clipboardVisible }
        function toggleDockAppPicker() { root.dockAppPickerVisible = !root.dockAppPickerVisible }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusiveZone: Settings.barFloating ? 0 : implicitHeight
            implicitHeight: Settings.barSize === "large" ? 56 : 46

            WlrLayershell.namespace: "yahr-bar"
            WlrLayershell.layer: WlrLayer.Top

            anchors {
                left: true
                right: true
                top: Settings.barPosition !== "bottom"
                bottom: Settings.barPosition === "bottom"
            }

            margins {
                left: Settings.barFloating ? 8 : 0
                right: Settings.barFloating ? 8 : 0
                top: Settings.barPosition !== "bottom" && Settings.barFloating ? 6 : 0
                bottom: Settings.barPosition === "bottom" && Settings.barFloating ? 6 : 0
            }

            Bar {
                anchors.fill: parent
                onToggleLauncher: root.launcherVisible = !root.launcherVisible
                onTogglePowerMenu: root.powerMenuVisible = !root.powerMenuVisible
                onToggleSettings: root.settingsVisible = !root.settingsVisible
                onToggleThemeSwitcher: root.themeSwitcherVisible = !root.themeSwitcherVisible
                onToggleWallpaper: root.wallpaperVisible = !root.wallpaperVisible
                onToggleControlCenter: root.controlCenterVisible = !root.controlCenterVisible
                onToggleClipboard: root.clipboardVisible = !root.clipboardVisible
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: Settings.dockEnabled
            color: "transparent"
            exclusiveZone: Settings.dockFloating ? 0 : (Settings.dockIconSize + 20)

            WlrLayershell.namespace: "yahr-dock"
            WlrLayershell.layer: WlrLayer.Top

            implicitHeight: Settings.dockPosition === "left" || Settings.dockPosition === "right" ? 0 : Settings.dockIconSize + 20
            implicitWidth: Settings.dockPosition === "left" || Settings.dockPosition === "right" ? Settings.dockIconSize + 20 : 0

            anchors {
                left: Settings.dockPosition !== "right"
                right: Settings.dockPosition !== "left"
                top: Settings.dockPosition !== "bottom"
                bottom: Settings.dockPosition !== "top"
            }

            margins {
                left: Settings.dockPosition === "left" && Settings.dockFloating ? 8 : 0
                right: Settings.dockPosition === "right" && Settings.dockFloating ? 8 : 0
                top: Settings.dockPosition === "top" && Settings.dockFloating ? 8 : 0
                bottom: Settings.dockPosition === "bottom" && Settings.dockFloating ? 8 : 0
            }

            Dock {
                anchors.centerIn: parent
                onSettingsRequested: root.settingsVisible = !root.settingsVisible
                onAppPickerRequested: root.dockAppPickerVisible = !root.dockAppPickerVisible
            }
        }
    }

    PanelWindow {
        visible: root.launcherVisible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        AppLauncher {
            anchors.centerIn: parent
            isVisible: root.launcherVisible
            onRequestClose: root.launcherVisible = false
            onOpenSettings: {
                root.launcherVisible = false
                root.settingsVisible = true
            }
        }
    }

    PanelWindow {
        visible: root.powerMenuVisible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.powerMenuVisible = false
        }

        PowerMenu {
            anchors.centerIn: parent
            isVisible: root.powerMenuVisible
            onRequestClose: root.powerMenuVisible = false
        }
    }

    PanelWindow {
        visible: root.controlCenterVisible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; right: true }
        margins { top: 48; right: 12 }

        ControlCenter {
            isVisible: root.controlCenterVisible
            onRequestClose: root.controlCenterVisible = false
        }
    }

    PanelWindow {
        visible: root.themeSwitcherVisible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        ThemeSwitcher {
            anchors.centerIn: parent
            isVisible: root.themeSwitcherVisible
            onRequestClose: root.themeSwitcherVisible = false
            onThemeApplyStarted: name => { root.themeLoadingName = name; root.themeLoadingVisible = true }
            onThemeApplyFinished: root.themeLoadingVisible = false
        }
    }

    PanelWindow {
        visible: root.wallpaperVisible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        WallpaperPicker {
            anchors.centerIn: parent
            isVisible: root.wallpaperVisible
            onRequestClose: root.wallpaperVisible = false
        }
    }

    PanelWindow {
        visible: root.settingsVisible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        SettingsPanel {
            anchors.centerIn: parent
            isVisible: root.settingsVisible
            onRequestClose: root.settingsVisible = false
            onThemeApplyStarted: name => { root.themeLoadingName = name; root.themeLoadingVisible = true }
            onThemeApplyFinished: root.themeLoadingVisible = false
        }
    }

    PanelWindow {
        visible: root.dockAppPickerVisible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dockAppPickerVisible = false
        }

        DockAppPicker {
            anchors.centerIn: parent
            isVisible: root.dockAppPickerVisible
            onRequestClose: root.dockAppPickerVisible = false
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.themeLoadingVisible
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors { top: true; left: true; right: true; bottom: true }

            ThemeLoadingOverlay {
                anchors.fill: parent
                isVisible: root.themeLoadingVisible
                themeName: root.themeLoadingName
            }
        }
    }

    PanelWindow {
        visible: root.clipboardVisible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        ClipboardPanel {
            anchors.centerIn: parent
            isVisible: root.clipboardVisible
            onRequestClose: root.clipboardVisible = false
        }
    }
}

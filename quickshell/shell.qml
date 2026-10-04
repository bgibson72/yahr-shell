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
import "modules/network"
import "modules/bluetooth"
import "modules/power"
import "modules/audio"
import "modules/settings"
import "modules/theme"
import "modules/wallpaper"
import "modules/clipboard"
import "modules/screenshot"
import "modules/trash"
import "modules/infopanel"
import "modules/calendar"
import "modules/calculator"
import "modules/keybinds"
import "components"

ShellRoot {
    id: root

    property bool launcherVisible: false
    property bool powerMenuVisible: false
    property bool settingsVisible: false
    property bool wallpaperPickerVisible: false
    property bool networkVisible: false
    property bool bluetoothVisible: false
    property bool batteryVisible: false
    property bool audioVisible: false
    property bool clipboardVisible: false
    property bool themeLoadingVisible: false
    property string themeLoadingName: ""
    property bool dockAppPickerVisible: false
    property bool screenshotVisible: false
    property bool trashVisible: false
    property bool infoPanelVisible: false
    property bool calendarVisible: false
    property bool calculatorVisible: false
    property bool keybindsVisible: false
    property bool dockHovered: false
    property real dockHideAt: 0

    readonly property bool panelOverlayOpen: launcherVisible || powerMenuVisible || settingsVisible
        || wallpaperPickerVisible || networkVisible || bluetoothVisible || batteryVisible || audioVisible
        || clipboardVisible || screenshotVisible || trashVisible || infoPanelVisible
        || calendarVisible || calculatorVisible || keybindsVisible || dockAppPickerVisible || themeLoadingVisible

    function hideOverlays() {
        launcherVisible = false
        powerMenuVisible = false
        settingsVisible = false
        wallpaperPickerVisible = false
        networkVisible = false
        bluetoothVisible = false
        batteryVisible = false
        audioVisible = false
        clipboardVisible = false
        dockAppPickerVisible = false
        screenshotVisible = false
        trashVisible = false
        infoPanelVisible = false
        calendarVisible = false
        calculatorVisible = false
        keybindsVisible = false
    }

    function closeUtilityPanelsExcept(keep) {
        if (keep !== "network") root.networkVisible = false
        if (keep !== "bluetooth") root.bluetoothVisible = false
        if (keep !== "battery") root.batteryVisible = false
        if (keep !== "audio") root.audioVisible = false
    }

    function toggleNetworkPanel() {
        const next = !root.networkVisible
        root.closeUtilityPanelsExcept(next ? "network" : "")
        root.networkVisible = next
    }

    function toggleBluetoothPanel() {
        const next = !root.bluetoothVisible
        root.closeUtilityPanelsExcept(next ? "bluetooth" : "")
        root.bluetoothVisible = next
    }

    function toggleBatteryPanel() {
        const next = !root.batteryVisible
        root.closeUtilityPanelsExcept(next ? "battery" : "")
        root.batteryVisible = next
    }

    function toggleAudioPanel() {
        const next = !root.audioVisible
        root.closeUtilityPanelsExcept(next ? "audio" : "")
        root.audioVisible = next
    }

    IpcHandler {
        target: "yahr"
        function toggleLauncher() { root.launcherVisible = !root.launcherVisible }
        function togglePowerMenu() { root.powerMenuVisible = !root.powerMenuVisible }
        function toggleSettings() { root.settingsVisible = !root.settingsVisible }
        function toggleWallpaper() {
            root.wallpaperPickerVisible = !root.wallpaperPickerVisible
        }
        function toggleControlCenter() { root.toggleAudioPanel() }
        function toggleNetwork() { root.toggleNetworkPanel() }
        function toggleBluetooth() { root.toggleBluetoothPanel() }
        function toggleBattery() { root.toggleBatteryPanel() }
        function toggleAudio() { root.toggleAudioPanel() }
        function toggleThemeSwitcher() {
            if (root.settingsVisible && settingsPanel.tab === "theme") {
                root.settingsVisible = false
                return
            }
            settingsPanel.tab = "theme"
            root.settingsVisible = true
        }
        function toggleClipboard() { root.clipboardVisible = !root.clipboardVisible }
        function toggleDockAppPicker() { root.dockAppPickerVisible = !root.dockAppPickerVisible }
        function toggleScreenshot() { root.screenshotVisible = !root.screenshotVisible }
        function toggleTrash() { root.trashVisible = !root.trashVisible }
        function toggleInfoPanel() { root.infoPanelVisible = !root.infoPanelVisible }
        function toggleCalendar() { root.calendarVisible = !root.calendarVisible }
        function toggleCalculator() { root.calculatorVisible = !root.calculatorVisible }
        function toggleKeybinds() { root.keybindsVisible = !root.keybindsVisible }
    }

    Process {
        id: greeterProbe
        running: false
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text || ""
                ThemeManager.hideScreenFrame = /sddm-greeter/i.test(text)
            }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            greeterProbe.running = false
            greeterProbe.running = true
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData
            visible: !ThemeManager.hideScreenFrame
            color: "transparent"
            exclusiveZone: ThemeManager.hideScreenFrame ? 0 : ThemeManager.barExclusiveZone
            implicitHeight: ThemeManager.barWindowHeight

            WlrLayershell.namespace: "yahr-bar"
            WlrLayershell.layer: WlrLayer.Top

            anchors {
                left: true
                right: true
                top: Settings.barPosition !== "bottom"
                bottom: Settings.barPosition === "bottom"
            }

            margins {
                left: Settings.barFloating ? ThemeManager.barFloatingSideGap : 0
                right: Settings.barFloating ? ThemeManager.barFloatingSideGap : 0
                top: Settings.barPosition !== "bottom" && Settings.barFloating ? ThemeManager.barFloatingEdgeGap : 0
                bottom: Settings.barPosition === "bottom" && Settings.barFloating ? ThemeManager.barFloatingEdgeGap : 0
            }

            Bar {
                id: barContent
                anchors.fill: parent
                onToggleLauncher: root.launcherVisible = !root.launcherVisible
                onTogglePowerMenu: root.powerMenuVisible = !root.powerMenuVisible
                onToggleNetwork: root.toggleNetworkPanel()
                onToggleBluetooth: root.toggleBluetoothPanel()
                onToggleBattery: root.toggleBatteryPanel()
                onToggleAudio: root.toggleAudioPanel()
                onToggleClipboard: root.clipboardVisible = !root.clipboardVisible
                onToggleScreenshot: root.screenshotVisible = !root.screenshotVisible
                onToggleWallpaper: root.wallpaperPickerVisible = !root.wallpaperPickerVisible
                onToggleInfoPanel: root.infoPanelVisible = !root.infoPanelVisible
                onToggleSettings: root.settingsVisible = !root.settingsVisible
            }

            // Mask input to the visible pills so leftover transparent
            // window chrome does not steal clicks from windows below.
            mask: Region {
                Region {
                    item: barContent.useIslands ? barContent.maskLeftIsland : barContent.maskBar
                    radius: barContent.useIslands ? barContent.maskLeftIsland.radius : barContent.maskBar.radius
                }
                Region {
                    item: barContent.useIslands ? barContent.maskCenterIsland : barContent.maskArch
                    radius: barContent.useIslands ? barContent.maskCenterIsland.radius : 0
                }
                Region {
                    item: barContent.useIslands ? barContent.maskRightIsland : barContent.maskArch
                    radius: barContent.useIslands ? barContent.maskRightIsland.radius : 0
                }
                Region {
                    item: barContent.maskArch
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWindow
            required property var modelData
            screen: modelData
            visible: Settings.dockEnabled && !ThemeManager.hideScreenFrame
            color: "transparent"
            WlrLayershell.namespace: "yahr-dock"
            WlrLayershell.layer: Settings.dockBehavior === "behind-windows" ? WlrLayer.Bottom
                : (Settings.dockBehavior === "auto-hide" ? WlrLayer.Overlay : WlrLayer.Top)

            readonly property bool isHorizontal: Settings.dockPosition === "top" || Settings.dockPosition === "bottom"
            readonly property bool autoHideActive: Settings.dockBehavior === "auto-hide" && !root.dockHovered
            readonly property int hideOffset: autoHideActive ? -((isHorizontal ? implicitHeight : implicitWidth) + 20) : 0
            readonly property bool windowSpansFull: Settings.dockBehavior === "dodge" || Settings.dockSpanFullWidth
            readonly property bool frameDock: ThemeManager.useFrameDock
            readonly property int joinPad: dockContent.joinPad
            readonly property int dockGap: Settings.dockFloating ? 8 : 0
            readonly property int framePad: ThemeManager.frameEdgeInset
            readonly property int attachedInset: {
                if (!ThemeManager.useFrameEmerge)
                    return dockGap
                if (Settings.dockFloating)
                    return framePad + dockGap
                if (Settings.dockSpanFullWidth)
                    return 0
                return Math.max(0, framePad - 2)
            }
            readonly property int holeSidePad: {
                if (!ThemeManager.useFrameEmerge)
                    return 0
                if (Settings.dockFloating)
                    return framePad
                if (Settings.dockSpanFullWidth)
                    return 0
                return Math.max(0, framePad - 2)
            }

            anchors {
                top: Settings.dockPosition === "top" || (!isHorizontal && (Settings.dockAlignment === "start" || windowSpansFull))
                bottom: Settings.dockPosition === "bottom" || (!isHorizontal && (Settings.dockAlignment === "end" || windowSpansFull))
                left: Settings.dockPosition === "left" || (isHorizontal && (Settings.dockAlignment !== "end" || windowSpansFull))
                right: Settings.dockPosition === "right" || (isHorizontal && (Settings.dockAlignment === "end" || windowSpansFull))
            }

            implicitWidth: isHorizontal
                ? (windowSpansFull ? screen.width : dockContent.implicitWidth)
                : dockContent.implicitWidth
            implicitHeight: isHorizontal
                ? dockContent.implicitHeight
                : (windowSpansFull ? screen.height : dockContent.implicitHeight)

            exclusiveZone: {
                if (ThemeManager.hideScreenFrame)
                    return 0
                if (Settings.dockBehavior === "auto-hide")
                    return 0
                if (Settings.dockBehavior === "dodge")
                    return ThemeManager.dockChromeSize + attachedInset
                if (ThemeManager.frameDockSpansEdge)
                    return ThemeManager.dockChromeSize
                return 0
            }

            margins {
                left: {
                    let v = 0
                    if (Settings.dockPosition === "left")
                        v = attachedInset + hideOffset - joinPad
                    else if (isHorizontal && windowSpansFull)
                        v = holeSidePad
                    else if (isHorizontal && Settings.dockAlignment === "center")
                        v = Math.max(0, Math.round((screen.width - implicitWidth) / 2))
                    else if (isHorizontal && Settings.dockAlignment === "start")
                        v = holeSidePad > 0 ? holeSidePad : dockGap
                    return v
                }
                right: {
                    let v = 0
                    if (Settings.dockPosition === "right")
                        v = attachedInset + hideOffset - joinPad
                    else if (isHorizontal && windowSpansFull)
                        v = holeSidePad
                    else if (isHorizontal && Settings.dockAlignment === "end")
                        v = holeSidePad > 0 ? holeSidePad : dockGap
                    return v
                }
                top: {
                    let v = 0
                    if (Settings.dockPosition === "top")
                        v = attachedInset + hideOffset - joinPad
                    else if (!isHorizontal && windowSpansFull)
                        v = holeSidePad
                    else if (!isHorizontal && Settings.dockAlignment === "center")
                        v = Math.max(0, Math.round((screen.height - implicitHeight) / 2))
                    else if (!isHorizontal && Settings.dockAlignment === "start")
                        v = holeSidePad > 0 ? holeSidePad : dockGap
                    return v
                }
                bottom: {
                    let v = 0
                    if (Settings.dockPosition === "bottom")
                        v = attachedInset + hideOffset - joinPad
                    else if (!isHorizontal && windowSpansFull)
                        v = holeSidePad
                    else if (!isHorizontal && Settings.dockAlignment === "end")
                        v = holeSidePad > 0 ? holeSidePad : dockGap
                    return v
                }
            }

            Behavior on margins.left { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on margins.right { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on margins.top { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on margins.bottom { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Dock {
                id: dockContent
                anchors.fill: parent
                onSettingsRequested: root.settingsVisible = !root.settingsVisible
                onAppPickerRequested: root.dockAppPickerVisible = !root.dockAppPickerVisible
                onTrashRequested: root.trashVisible = !root.trashVisible
            }

            mask: Region {
                item: dockContent.maskBackground
                radius: dockContent.maskBackground.radius
            }

            Process {
                id: cursorPosChecker
                running: false
                command: ["hyprctl", "cursorpos", "-j"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const pos = JSON.parse(text)
                            const scr = dockWindow.screen
                            if (!scr)
                                return
                            const sx = scr.x || 0
                            const sy = scr.y || 0
                            const sw = scr.width
                            const sh = scr.height
                            if (pos.x < sx || pos.x > sx + sw || pos.y < sy || pos.y > sy + sh)
                                return
                            const thickness = Settings.dockIconSize + 20
                            const revealThreshold = 20
                            const hideThreshold = thickness + 40
                            let distanceFromEdge
                            switch (Settings.dockPosition) {
                                case "top": distanceFromEdge = pos.y - sy; break
                                case "bottom": distanceFromEdge = (sy + sh) - pos.y; break
                                case "left": distanceFromEdge = pos.x - sx; break
                                case "right": distanceFromEdge = (sx + sw) - pos.x; break
                                default: distanceFromEdge = 9999
                            }
                            if (distanceFromEdge <= revealThreshold) {
                                root.dockHideAt = 0
                                root.dockHovered = true
                            } else if (root.dockHovered && distanceFromEdge > hideThreshold) {
                                if (root.dockHideAt === 0)
                                    root.dockHideAt = Date.now() + 400
                            } else if (distanceFromEdge <= hideThreshold) {
                                root.dockHideAt = 0
                            }
                            if (root.dockHideAt !== 0 && Date.now() >= root.dockHideAt) {
                                root.dockHovered = false
                                root.dockHideAt = 0
                            }
                        } catch (e) {}
                    }
                }
            }

            Timer {
                interval: 150
                running: Settings.dockBehavior === "auto-hide" && Settings.dockEnabled
                repeat: true
                onTriggered: cursorPosChecker.running = true
            }
        }
    }

    PanelWindow {
        visible: launcherPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.launcherVisible = false
        }

        AppLauncher {
            id: launcherPanel
            x: ThemeManager.panelLeftMargin
            y: ThemeManager.overlayAttachedY(parent.height, height)
            isVisible: root.launcherVisible
            onRequestClose: root.launcherVisible = false
        }
    }

    PanelWindow {
        visible: powerMenuPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.powerMenuVisible = false
        }

        PowerMenu {
            id: powerMenuPanel
            x: parent.width - width - ThemeManager.panelRightMargin
            y: ThemeManager.overlayMidY(parent.height, height)
            isVisible: root.powerMenuVisible
            onRequestClose: root.powerMenuVisible = false
        }
    }

    PanelWindow {
        visible: networkPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.networkVisible = false
        }

        NetworkPanel {
            id: networkPanel
            x: parent.width - width - ThemeManager.panelRightMargin
            y: ThemeManager.overlayAttachedY(parent.height, height)
            isVisible: root.networkVisible
            onRequestClose: root.networkVisible = false
        }
    }

    PanelWindow {
        visible: bluetoothPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.bluetoothVisible = false
        }

        BluetoothPanel {
            id: bluetoothPanel
            x: parent.width - width - ThemeManager.panelRightMargin
            y: ThemeManager.overlayAttachedY(parent.height, height)
            isVisible: root.bluetoothVisible
            onRequestClose: root.bluetoothVisible = false
        }
    }

    PanelWindow {
        visible: batteryPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.batteryVisible = false
        }

        PowerPanel {
            id: batteryPanel
            x: parent.width - width - ThemeManager.panelRightMargin
            y: ThemeManager.overlayAttachedY(parent.height, height)
            isVisible: root.batteryVisible
            onRequestClose: root.batteryVisible = false
        }
    }

    PanelWindow {
        visible: audioPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.audioVisible = false
        }

        AudioPanel {
            id: audioPanel
            x: parent.width - width - ThemeManager.panelRightMargin
            y: ThemeManager.overlayAttachedY(parent.height, height)
            isVisible: root.audioVisible
            onRequestClose: root.audioVisible = false
        }
    }

    PanelWindow {
        visible: (root.settingsVisible || settingsPanel.onScreen) && !settingsPanel.filePickerOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        mask: Region {
            item: settingsPanel
            radius: settingsPanel.chromeRadius
        }

        SettingsPanel {
            id: settingsPanel
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            isVisible: root.settingsVisible
            onRequestClose: root.settingsVisible = false
            onOpenWallpaperPicker: {
                root.settingsVisible = false
                root.wallpaperPickerVisible = true
            }
            onThemeApplyStarted: name => { root.themeLoadingName = name; root.themeLoadingVisible = true }
            onThemeApplyFinished: root.themeLoadingVisible = false
        }
    }

    WallpaperSlideshow {
        id: wallpaperSlideshow
    }

    PanelWindow {
        visible: root.wallpaperPickerVisible || wallpaperPickerPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        WallpaperPicker {
            id: wallpaperPickerPanel
            anchors.fill: parent
            isVisible: root.wallpaperPickerVisible
            onRequestClose: root.wallpaperPickerVisible = false
            onWallpaperApplied: path => {
                // Keep slideshow index aligned if the user re-enables slideshow later
                wallpaperSlideshow.syncIndexToCurrent()
            }
        }
    }

    PanelWindow {
        visible: trashPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.trashVisible = false
        }

        TrashPanel {
            id: trashPanel
            x: (parent.width - width) / 2
            y: ThemeManager.overlayCenteredY(parent.height, height)
            isVisible: root.trashVisible
            onRequestClose: root.trashVisible = false
        }
    }

    PanelWindow {
        visible: screenshotPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.screenshotVisible = false
        }

        ScreenshotPicker {
            id: screenshotPanel
            x: (parent.width - width) / 2
            y: ThemeManager.overlayCenteredY(parent.height, height)
            isVisible: root.screenshotVisible
            onRequestClose: root.screenshotVisible = false
        }
    }

    PanelWindow {
        visible: dockAppPickerPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dockAppPickerVisible = false
        }

        DockAppPicker {
            id: dockAppPickerPanel
            x: (parent.width - width) / 2
            y: ThemeManager.overlayCenteredY(parent.height, height)
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
            exclusionMode: ExclusionMode.Ignore
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
        visible: infoPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.infoPanelVisible = false
        }

        InfoPanel {
            id: infoPanel
            x: (parent.width - width) / 2
            y: ThemeManager.overlayAttachedY(parent.height, height)
            slideOffsetY: -110
            entranceScale: 0.8
            isVisible: root.infoPanelVisible
            onRequestClose: root.infoPanelVisible = false
        }
    }

    PanelWindow {
        visible: (root.calendarVisible || calendarPanel.onScreen) && !calendarPanel.filePickerOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        mask: Region {
            item: calendarPanel
            radius: calendarPanel.chromeRadius
        }

        CalendarApp {
            id: calendarPanel
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            isVisible: root.calendarVisible
            onRequestClose: root.calendarVisible = false
        }
    }

    PanelWindow {
        visible: root.calculatorVisible || calculatorPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        mask: Region {
            item: calculatorPanel
            radius: calculatorPanel.chromeRadius
        }

        Calculator {
            id: calculatorPanel
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            isVisible: root.calculatorVisible
            onRequestClose: root.calculatorVisible = false
        }
    }

    PanelWindow {
        visible: root.keybindsVisible || keybindsPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        mask: Region {
            item: keybindsPanel
            radius: keybindsPanel.chromeRadius
        }

        KeybindsApp {
            id: keybindsPanel
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            isVisible: root.keybindsVisible
            onRequestClose: root.keybindsVisible = false
        }
    }

    PanelWindow {
        visible: clipboardPanel.onScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.clipboardVisible = false
        }

        ClipboardPanel {
            id: clipboardPanel
            x: (parent.width - width) / 2
            y: ThemeManager.overlayCenteredY(parent.height, height)
            isVisible: root.clipboardVisible
            onRequestClose: root.clipboardVisible = false
        }
    }

    Process {
        id: calendarAlertProc
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/calendar-store.py`, "fire-due"]
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            calendarAlertProc.running = false
            calendarAlertProc.running = true
        }
    }

    // Click-through frame on Overlay, declared last so the bezel stays
    // painted above Settings and other popups. The bar window draws the
    // matching top strip and top corners so those join as one piece.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: ThemeManager.useFrameEmerge && !ThemeManager.hideScreenFrame
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "yahr-frame"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors { left: true; right: true; top: true; bottom: true }
            mask: Region {}

            ScreenFrame {
                anchors.fill: parent
            }
        }
    }
}

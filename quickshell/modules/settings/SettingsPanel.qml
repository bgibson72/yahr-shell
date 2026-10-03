import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 980
    height: 720
    floatCenter: true
    slideOffsetY: 0
    entranceScale: 0.92
    property string tab: "widgets"
    property bool sidebarExpanded: true
    readonly property int sidebarCollapsedWidth: 60
    readonly property int sidebarExpandedWidth: 176
    readonly property var tabsModel: [
        { id: "widgets", label: "Widgets", glyph: "\uf013" },
        { id: "bar", label: "Bar", glyph: "\uf0c9" },
        { id: "dock", label: "Dock", glyph: "\uf2d0" },
        { id: "theme", label: "Theme", glyph: "\uf1fc" },
        { id: "wallpaper", label: "Wallpaper", glyph: "\uf03e" },
        { id: "hypr", label: "Hyprland", glyph: "\uf359" },
        { id: "sddm", label: "SDDM", glyph: "\uf2bd" },
        { id: "about", label: "About", glyph: "\uf05a" }
    ]
    property var themes: []
    readonly property var filteredThemes: {
        const mode = Settings.themeMode
        const src = root.themes
        const out = []
        for (let i = 0; i < src.length; i++) {
            const theme = src[i]
            if ((theme.mode || "dark") === mode)
                out.push(theme)
        }
        return out
    }
    property var wallpaperImages: []
    property string seedBg: "#1e1e2e"
    property string seedBlue: "#89b4fa"
    property string seedPurple: "#cba6f7"
    property string seedPink: "#f5c2e7"
    property string seedRed: "#f38ba8"
    property string seedOrange: "#fab387"
    property string seedYellow: "#f9e2af"
    property string seedGreen: "#a6e3a1"
    property string seedTeal: "#94e2d5"
    property string seedPapirus: "auto"
    property string saveName: "Custom"
    property string lastWallpaperPath: ""
    property bool sddmAvatarExists: false
    property bool sddmAvatarSuccess: false
    property bool sddmOpacitySuccess: false
    property bool sddmOpacityError: false
    property string sddmAvatarPath: ""
    property string sddmAvatarPreview: ""
    property string sddmStatusMessage: ""
    property bool filePickerOpen: false

    signal requestClose()
    signal openWallpaperPicker()
    signal themeApplyStarted(string name)
    signal themeApplyFinished()
    focus: true

    onIsVisibleChanged: {
        if (isVisible) {
            root.sidebarExpanded = true
            themeList.running = true
            if (root.tab === "wallpaper")
                root.refreshWallpapers()
            if (root.tab === "sddm")
                root.refreshSddm()
        }
    }
    onTabChanged: {
        if (tab === "wallpaper")
            root.refreshWallpapers()
        if (tab === "sddm")
            root.refreshSddm()
    }

    function refreshSddm() {
        sddmThemeReader.running = false
        sddmThemeReader.running = true
        sddmAvatarChecker.running = false
        sddmAvatarChecker.running = true
    }

    function hyprEval(expr) {
        Quickshell.execDetached(["hyprctl", "eval", expr])
    }

    function applyHyprBorderSizeLive() {
        const px = Settings.hyprShowBorder ? Settings.hyprBorderSize : 0
        root.hyprEval(`hl.config({general={border_size=${px}}})`)
    }

    function applyBorderSize(px) {
        Settings.hyprBorderSize = px
        Settings.widgetBorderWidth = px
        Settings.save()
        root.applyHyprBorderSizeLive()
    }

    function colorHexRgb(c) {
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return r + g + b
    }

    function alphaHex(opacityPct) {
        return Math.round(Math.max(0, Math.min(100, opacityPct)) / 100 * 255).toString(16).padStart(2, "0")
    }

    function applyWindowBorder() {
        const opacity = Settings.hyprBorderTransparent ? (100 - Settings.hyprBorderTransparency) : 100
        const accent = root.colorHexRgb(ThemeManager.accentBlue)
        const border0 = root.colorHexRgb(ThemeManager.border0)
        const a = root.alphaHex(opacity)
        if (Settings.hyprBorderFill === "solid") {
            const ia = root.alphaHex(opacity * 0.5)
            root.hyprEval(`hl.config({general={col={active_border="rgba(${accent}${a})",inactive_border="rgba(${border0}${ia})"}}})`)
        } else {
            const scale = opacity / 100
            const a0 = root.alphaHex(25 * scale)
            const a1 = root.alphaHex(35 * scale)
            const a2 = root.alphaHex(15 * scale)
            const i0 = root.alphaHex(10 * scale)
            const i1 = root.alphaHex(7 * scale)
            const ang = Settings.hyprBorderAngle
            root.hyprEval(`hl.config({general={col={active_border={colors={"rgba(000000${a0})","rgba(${accent}${a1})","rgba(ffffff${a2})"},angle=${ang}},inactive_border={colors={"rgba(000000${i0})","rgba(ffffff${i1})"},angle=${ang}}}}})`)
        }
        root.applyBorderAngleAnim()
    }

    function applyBorderAngleAnim() {
        const mode = Settings.hyprBorderFill === "gradient" ? Settings.hyprBorderAnimation : "none"
        if (mode === "none") {
            root.hyprEval('hl.animation({leaf="borderangle",enabled=false})')
            return
        }
        const speed = mode === "loop" ? 30 : 8
        root.hyprEval(`hl.animation({leaf="borderangle",enabled=true,speed=${speed},bezier="linear",style="${mode}"})`)
    }

    function applyShadowPreset(id) {
        const presets = {
            off: { range: 0, alpha: 0 },
            light: { range: 10, alpha: 18 },
            moderate: { range: 20, alpha: 33 },
            heavy: { range: 40, alpha: 55 }
        }
        const p = presets[id] || presets.moderate
        Settings.hyprShadowPreset = id
        Settings.hyprShadowRange = p.range
        Settings.hyprShadowAlpha = p.alpha
        Settings.save()
        const on = id !== "off"
        root.hyprEval(`hl.config({decoration={shadow={enabled=${on}}}})`)
        if (on)
            root.applyWindowShadowColor()
    }

    function applyWindowShadowColor() {
        const rgb = Settings.hyprShadowUseAccent ? root.colorHexRgb(ThemeManager.accentBlue) : "000000"
        const a = root.alphaHex(Settings.hyprShadowAlpha)
        root.hyprEval(`hl.config({decoration={shadow={range=${Settings.hyprShadowRange},color="rgba(${rgb}${a})"}}})`)
    }

    function applyHyprBlurLive() {
        const on = Settings.hyprBlurEnabled
        root.hyprEval(`hl.config({decoration={blur={enabled=${on}}}})`)
        root.hyprEval(`hl.layer_rule({match={namespace="^quickshell"},blur=${on}})`)
        root.hyprEval(`hl.layer_rule({match={namespace="^mako"},blur=${on}})`)
        if (on)
            root.hyprEval(`hl.config({decoration={blur={size=${Settings.hyprBlurSize}}}})`)
    }

    function applyHyprBlur() {
        Settings.blur = Settings.hyprBlurEnabled
        Settings.save()
        root.applyHyprBlurLive()
    }

    function applyHyprShadowLive() {
        const on = Settings.hyprShadowPreset !== "off"
        root.hyprEval(`hl.config({decoration={shadow={enabled=${on}}}})`)
        if (on)
            root.applyWindowShadowColor()
    }

    function applyWindowOpacityLive() {
        const on = Settings.hyprWindowTransparent
        const a = Settings.hyprWindowOpacity
        root.hyprEval(`yahrApplyWindowOpacity(${on}, ${a})`)
        Quickshell.execDetached(["python3", `${Quickshell.shellDir}/scripts/sync-ghostty-opacity.py`])
    }

    function applyWindowOpacity() {
        Settings.save()
        root.applyWindowOpacityLive()
    }

    function syncHyprlandFromSettings() {
        root.applyHyprBorderSizeLive()
        root.applyWindowBorder()
        root.applyHyprBlurLive()
        root.applyHyprShadowLive()
        root.applyWindowOpacityLive()
        root.hyprEval(`hl.config({animations={enabled=${Settings.hyprAnimations}}})`)
        ThemeManager.applyHyprWorkspaceLayout()
    }

    function tidyHomePath(path) {
        const home = Quickshell.env("HOME")
        if (home && path.startsWith(home))
            return "~" + path.slice(home.length)
        return path
    }

    function expandHome(path) {
        if (!path)
            return ""
        const text = String(path)
        if (text.startsWith("~"))
            return Quickshell.env("HOME") + text.slice(1)
        return text
    }

    function sddmWallpaperPath() {
        if (Settings.sddmFollowDesktop)
            return root.expandHome(Settings.currentWallpaper || root.lastWallpaperPath)
        return root.expandHome(Settings.sddmCustomWallpaper)
    }

    function applySddm() {
        Settings.save()
        const blur = Settings.sddmBlurEnabled ? Settings.sddmBlurAmount : 0
        const wallpaper = Settings.sddmFollowDesktop ? "desktop" : (root.sddmWallpaperPath() || "none")
        root.sddmOpacityError = false
        root.sddmStatusMessage = ""
        sddmThemeWriter.command = [
            "python3",
            `${Quickshell.shellDir}/scripts/sddm-apply.py`,
            "--opacity",
            Settings.sddmLoginOpacity.toFixed(2),
            "--blur",
            String(blur),
            "--wallpaper",
            wallpaper
        ]
        sddmThemeWriter.running = true
    }

    function wallpaperScanRoot() {
        const rootDir = root.expandHome(Settings.wallpaperDir || "~/Pictures/Wallpapers")
        if (Settings.wallpaperSource === "theme" && ThemeManager.wallpaperDir)
            return `${rootDir}/${ThemeManager.wallpaperDir}`
        return rootDir
    }

    function refreshWallpapers() {
        wallpaperScan.command = [
            "python3",
            `${Quickshell.shellDir}/scripts/list-wallpapers.py`,
            root.wallpaperScanRoot()
        ]
        wallpaperScan.running = false
        wallpaperScan.running = true
    }

    function applyWallpaper(path) {
        Settings.currentWallpaper = path
        Settings.save()
        Quickshell.execDetached([
            "python3",
            `${Quickshell.shellDir}/scripts/set-wallpaper.py`,
            path,
            Settings.wallpaperTransition
        ])
    }

    function startFilePicker(proc) {
        filePickerOpen = true
        pickerKick.proc = proc
        pickerKick.restart()
    }

    function endFilePicker() {
        if (wallpaperFolderPicker.running || sddmImagePicker.running || sddmWallpaperPicker.running)
            return
        filePickerOpen = false
    }

    Timer {
        id: pickerKick
        interval: 120
        repeat: false
        property var proc: null
        onTriggered: {
            if (pickerKick.proc)
                pickerKick.proc.running = true
        }
    }

    Connections {
        target: Settings
        function onWallpaperDirChanged() {
            if (root.tab === "wallpaper")
                root.refreshWallpapers()
        }
        function onLoaded() { root.syncHyprlandFromSettings() }
    }

    Component.onCompleted: {
        if (Settings.ready)
            root.syncHyprlandFromSettings()
    }

    Process {
        id: themeList
        running: false
        command: ["bash", `${Quickshell.shellDir}/scripts/yahr-theme-cli`, "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text)
                    root.themes = Array.isArray(parsed) ? parsed : []
                } catch (e) {
                    root.themes = []
                }
            }
        }
    }

    Process {
        id: applyTheme
        running: false
        property string themeId: "catppuccin"
        command: ["bash", `${Quickshell.shellDir}/scripts/yahr-theme-cli`, "apply", themeId]
        onStarted: root.themeApplyStarted(applyTheme.themeId)
        onExited: {
            themeList.running = true
            root.themeApplyFinished()
        }
    }

    Process {
        id: saveTheme
        running: false
        command: ["bash", `${Quickshell.shellDir}/scripts/yahr-theme-cli`, "save",
            "--name", root.saveName,
            "--bg", root.seedBg,
            "--blue", root.seedBlue,
            "--purple", root.seedPurple,
            "--pink", root.seedPink,
            "--red", root.seedRed,
            "--orange", root.seedOrange,
            "--yellow", root.seedYellow,
            "--green", root.seedGreen,
            "--teal", root.seedTeal,
            "--papirus-folder", root.seedPapirus
        ]
        onExited: themeList.running = true
    }

    Process {
        id: deleteTheme
        running: false
        property string themeId: ""
        command: ["bash", `${Quickshell.shellDir}/scripts/yahr-theme-cli`, "delete", themeId]
        onExited: themeList.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Yahr Settings"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 18
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            IconButton {
                compact: true
                glyph: "\uf00d"
                pixelSize: 14
                onClicked: root.requestClose()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 10
            spacing: 22

            // Left nav rail: rounded card, slightly lighter than the panel
            // background. Opens with icon + label; the chevron collapses it
            // to icons-only.
            Rectangle {
                id: sidebar
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                // Items inside a Layout must be sized via the Layout.*
                // attached properties rather than width/height directly --
                // setting width itself left the sibling content column
                // unaware the available space had changed, so it never
                // shrank to make room as the sidebar expanded.
                Layout.preferredWidth: root.sidebarExpanded ? root.sidebarExpandedWidth : root.sidebarCollapsedWidth
                radius: 14
                color: ThemeManager.chromeColor
                clip: true

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Repeater {
                        model: root.tabsModel

                        Rectangle {
                            id: navItem
                            required property var modelData
                            Layout.fillWidth: true
                            height: 40
                            radius: 10
                            color: root.tab === navItem.modelData.id
                                ? ThemeManager.accentBlue
                                : (navMouse.containsMouse ? ThemeManager.surface1 : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }

                            scale: navMouse.pressed ? ThemeManager.bouncePressScale : 1.0
                            Behavior on scale {
                                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                            }

                            Text {
                                id: navIcon
                                text: navItem.modelData.glyph
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: ThemeManager.fontSizeIconFA
                                color: root.tab === navItem.modelData.id ? ThemeManager.bgBase : ThemeManager.fgPrimary
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.sidebarExpanded ? 12 : (navItem.width - width) / 2
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                            }

                            Text {
                                text: navItem.modelData.label
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                                color: root.tab === navItem.modelData.id ? ThemeManager.bgBase : ThemeManager.fgPrimary
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: navIcon.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                elide: Text.ElideRight
                                opacity: root.sidebarExpanded ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tab = navItem.modelData.id
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        id: chevronBtn
                        Layout.fillWidth: true
                        height: 40
                        radius: 10
                        color: chevronMouse.containsMouse ? ThemeManager.surface1 : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        scale: chevronMouse.pressed ? ThemeManager.bouncePressScale : 1.0
                        Behavior on scale {
                            SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                        }

                        Text {
                            id: chevronIcon
                            text: "\uf054"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: ThemeManager.fontSizeIconFA
                            color: ThemeManager.fgPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.sidebarExpanded ? 12 : (chevronBtn.width - width) / 2
                            rotation: root.sidebarExpanded ? 180 : 0
                            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                            Behavior on rotation {
                                NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                            }
                        }

                        Text {
                            text: "Collapse"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                            color: ThemeManager.fgPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: chevronIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            elide: Text.ElideRight
                            opacity: root.sidebarExpanded ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        MouseArea {
                            id: chevronMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sidebarExpanded = !root.sidebarExpanded
                        }
                    }
                }
            }

            ColumnLayout {
                id: contentColumn
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                spacing: 12

        // Widgets
        Flickable {
            visible: root.tab === "widgets"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: widgetsCol.implicitHeight
            clip: true

            ColumnLayout {
                id: widgetsCol
                width: parent.width
                spacing: 16

            SettingsSection {
                title: "Clock & Date"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow { label: "24-hour clock"; checked: Settings.clockFormat24hr; onToggled: { Settings.clockFormat24hr = !checked; Settings.save() } }
                        ToggleRow { label: "Show seconds"; checked: Settings.showSeconds; onToggled: { Settings.showSeconds = !checked; Settings.save() } }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow { label: "Day of week"; checked: Settings.showDayOfWeek; onToggled: { Settings.showDayOfWeek = !checked; Settings.save() } }
                        ToggleRow { label: "Long date"; checked: Settings.dateLong; onToggled: { Settings.dateLong = !checked; Settings.save() } }
                    }
                    SettingsSubcard {
                        Text {
                            text: "Date format"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ChoiceChipRow {
                            options: [
                                { id: "MDY", label: "MM/DD/YYYY" },
                                { id: "DMY", label: "DD/MM/YYYY" }
                            ]
                            current: Settings.dateFormat
                            onPicked: id => { Settings.dateFormat = id; Settings.save() }
                        }
                    }
                    SettingsSubcard {
                        Text {
                            text: "First day of the week"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ChoiceChipRow {
                            options: [
                                { id: "sunday", label: "Sunday" },
                                { id: "monday", label: "Monday" }
                            ]
                            current: Settings.calendarWeekStart
                            onPicked: id => { Settings.calendarWeekStart = id; Settings.save() }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Weather"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Show weather in bar"
                            checked: Settings.showWeatherInBar
                            onToggled: { Settings.showWeatherInBar = !checked; Settings.save() }
                        }
                        Text {
                            text: "Condition icon and current temperature sit between the date and time."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Weather units"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipRow {
                                options: [
                                    { id: "fahrenheit", label: "Fahrenheit" },
                                    { id: "celsius", label: "Celsius" }
                                ]
                                current: Settings.weatherUseFahrenheit ? "fahrenheit" : "celsius"
                                onPicked: id => {
                                    Settings.weatherUseFahrenheit = id === "fahrenheit"
                                    Settings.save()
                                }
                            }
                        }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Weather location"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                height: 30
                                InputField {
                                    id: locField
                                    anchors.fill: parent
                                    text: Settings.weatherLocation
                                    font.pixelSize: 12
                                    background: Rectangle {
                                        color: ThemeManager.surface1
                                        radius: 6
                                    }
                                    onEditingFinished: { Settings.weatherLocation = text; Settings.save() }
                                }
                                Text {
                                    visible: locField.text.length === 0
                                    text: "auto (IP-based)"
                                    color: ThemeManager.placeholderColor
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                }
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Interface"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Follow Hyprland Window Rules"
                            checked: Settings.followHyprlandRules
                            onToggled: { Settings.followHyprlandRules = !checked; Settings.save() }
                        }
                        Text {
                            text: Settings.followHyprlandRules
                            ? "Rounding, border thickness, and border fill/opacity match the Hyprland tab."
                            : "Widget chrome can be set independently. Turn this on to match Hyprland window rules."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
                SettingsCard {
                    enabled: !Settings.followHyprlandRules
                    SettingsSubcard {
                        ToggleRow {
                            label: "Transparent backgrounds"
                            checked: Settings.widgetTransparent
                            onToggled: {
                                Settings.widgetTransparent = !checked
                                if (!checked && Settings.widgetOpacity >= 0.99)
                                Settings.widgetOpacity = 0.70
                                Settings.save()
                            }
                        }
                        Text {
                            text: "Glassy content area so the wallpaper shows through. Window chrome (frame, sidebar) stays more solid."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        TransparencySlider {
                            visible: Settings.widgetTransparent
                            opacityValue: Settings.widgetOpacity
                            onChanged: value => Settings.widgetOpacity = value
                            onReleased: Settings.save()
                        }
                    }
                }
                SettingsCard {
                    enabled: !Settings.followHyprlandRules
                    SettingsSubcard {
                        ToggleRow {
                            label: "Widget borders"
                            checked: Settings.showWidgetBorders
                            onToggled: { Settings.showWidgetBorders = !checked; Settings.save() }
                        }
                        Text {
                            text: "Border properties can be configured in the Hyprland tab."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
                SettingsCard {
                    enabled: !Settings.followHyprlandRules
                    visible: Settings.showWidgetBorders || (Settings.followHyprlandRules && Settings.hyprShowBorder)
                    SettingsSubcard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: `Border thickness: ${Settings.hyprBorderSize}px`
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ValueChipRow {
                                values: [1, 2, 3, 4, 5]
                                current: Settings.hyprBorderSize
                                onPicked: value => root.applyBorderSize(value)
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "UI Font"
                SettingsCard {
                    SettingsSubcard {
                        Text {
                            text: "Fonts used by the shell, independent of other system fonts."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }
                        FontChipFlow {
                            Layout.fillWidth: true
                            current: Settings.uiFont
                            onPicked: key => {
                                Settings.uiFont = key
                                Settings.save()
                            }
                        }
                    }
                }
            }
            }
        }

        // Bar
        Flickable {
            visible: root.tab === "bar"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: barCol.implicitHeight
            clip: true

            ColumnLayout {
                id: barCol
                width: parent.width
                spacing: 16

            SettingsSection {
                title: "Position & Size"
                SettingsCard {
                    SettingsSubcard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Bar position"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipRow {
                                options: [
                                    { id: "top", label: "Top" },
                                    { id: "bottom", label: "Bottom" }
                                ]
                                current: Settings.barPosition
                                onPicked: id => {
                                    Settings.barPosition = id
                                    if (id === "bottom")
                                        Settings.dockEnabled = false
                                    Settings.save()
                                }
                            }
                            Text {
                                visible: Settings.barPosition === "bottom"
                                text: "The dock is turned off while the bar is on the bottom."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Bar size"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipRow {
                                options: [
                                    { id: "small", label: "Normal" },
                                    { id: "large", label: "Large" }
                                ]
                                current: Settings.barSize === "large" ? "large" : "small"
                                onPicked: id => { Settings.barSize = id; Settings.save() }
                            }
                        }
                    }
                }
                SettingsCard {
                    enabled: Settings.barStyle !== "islands"
                    SettingsSubcard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Bar mode"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipRow {
                                options: [
                                    { id: "floating", label: "Floating" },
                                    { id: "docked", label: "Docked" }
                                ]
                                current: Settings.barFloating ? "floating" : "docked"
                                disabledIds: Settings.barStyle === "islands" ? ["docked"] : []
                                onPicked: id => {
                                    Settings.barFloating = id === "floating"
                                    if (id === "docked")
                                        Settings.barStyle = "single"
                                    Settings.save()
                                }
                            }
                            Text {
                                text: Settings.barStyle === "islands"
                                    ? "Islands stay floating. Switch Appearance → Bar style to Single to dock the bar."
                                    : (Settings.barFloating
                                        ? "Inset from the screen edge with a small gap. Panels open with an elastic pop."
                                        : "Flush against the screen edge. Widgets emerge from a screen frame.")
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Appearance"
                SettingsCard {
                    SettingsSubcard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Bar style"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipRow {
                                options: [
                                    { id: "single", label: "Single" },
                                    { id: "islands", label: "Islands" }
                                ]
                                current: Settings.barStyle
                                disabledIds: Settings.barFloating ? [] : ["islands"]
                                onPicked: id => {
                                    Settings.barStyle = id
                                    if (id === "islands")
                                        Settings.barFloating = true
                                    Settings.save()
                                }
                            }
                            Text {
                                text: Settings.barStyle === "islands"
                                    ? "Left, center, and right each sit in their own pill. Islands require a floating bar."
                                    : "One continuous bar across the screen."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Numbered workspaces"
                            checked: Settings.workspaceStyle === "numbers"
                            onToggled: { Settings.workspaceStyle = !checked ? "numbers" : "dots"; Settings.save() }
                        }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Follow Hyprland Window Rules"
                            checked: Settings.barFollowHyprland
                            onToggled: { Settings.barFollowHyprland = !checked; Settings.save() }
                        }
                        Text {
                            text: Settings.barFollowHyprland
                                ? "Fill, borders, and thickness match the Hyprland tab."
                                : "Bar chrome can be set independently. Turn this on to match Hyprland window rules."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    SettingsSubcard {
                        enabled: !Settings.barFollowHyprland
                        ToggleRow {
                            label: "Bar border"
                            checked: Settings.barShowBorder
                            onToggled: { Settings.barShowBorder = !checked; Settings.save() }
                        }
                        ColumnLayout {
                            visible: Settings.barShowBorder || (Settings.barFollowHyprland && Settings.hyprShowBorder)
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: `Border size: ${Settings.hyprBorderSize}px`
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ValueChipRow {
                                values: [1, 2, 3, 4, 5]
                                current: Settings.hyprBorderSize
                                onPicked: value => root.applyBorderSize(value)
                            }
                        }
                    }
                    SettingsSubcard {
                        ToggleRow {
                            label: "Follow Hyprland rounding"
                            checked: Settings.barRoundingFollowHyprland
                            onToggled: { Settings.barRoundingFollowHyprland = !checked; Settings.save() }
                        }
                        Text {
                            text: Settings.barRoundingFollowHyprland
                                ? `Using Hyprland window rounding (${Settings.hyprRounding}px). Docked frame bars stay square against the screen edge.`
                                : "Set an independent radius for floating single and island bars. Docked frame bars stay square against the screen edge."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        ColumnLayout {
                            visible: !Settings.barRoundingFollowHyprland
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: `Corner radius: ${Settings.barRounding}px`
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ValueChipRow {
                                values: [0, 4, 8, 12, 16, 20, 24]
                                current: Settings.barRounding
                                onPicked: value => { Settings.barRounding = value; Settings.save() }
                            }
                        }
                    }
                }
                SettingsCard {
                    enabled: !Settings.barFollowHyprland
                    SettingsSubcard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Background fill"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipRow {
                                options: [
                                    { id: "opaque", label: "Solid" },
                                    { id: "translucent", label: "Transparent" }
                                ]
                                current: Settings.barBackgroundStyle === "opaque" ? "opaque" : "translucent"
                                onPicked: id => { Settings.barBackgroundStyle = id; Settings.save() }
                            }
                        }
                        TransparencySlider {
                            visible: Settings.barBackgroundStyle !== "opaque"
                            opacityValue: Settings.barOpacity
                            onChanged: value => Settings.barOpacity = value
                            onReleased: Settings.save()
                        }
                    }
                }
            }

            SettingsSection {
                title: "System Tray"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Show application tray icons"
                            checked: Settings.showSystemTray
                            onToggled: { Settings.showSystemTray = !checked; Settings.save() }
                        }
                        Text {
                            text: "Icons that apps put in the tray, such as Cursor. Off by default because those pixmaps rarely line up with the bar icons."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Show battery percentage"
                            checked: Settings.showBatteryPercent
                            onToggled: { Settings.showBatteryPercent = !checked; Settings.save() }
                        }
                        Text {
                            text: "Shows the charge percentage to the right of the battery icon. Desktops on AC power still show the adapter icon."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Show volume percentage"
                            checked: Settings.showVolumePercent
                            onToggled: { Settings.showVolumePercent = !checked; Settings.save() }
                        }
                        Text {
                            text: "Shows the current output volume to the right of the speaker icon."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Show network up/down speeds"
                            checked: Settings.showNetworkSpeed
                            onToggled: { Settings.showNetworkSpeed = !checked; Settings.save() }
                        }
                        Text {
                            text: "Shows download and upload rates next to the network icon while connected. Values are a rolling average over the last minute so the tray stays steady."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
            }
        }

        // Dock
        Flickable {
            visible: root.tab === "dock"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: dockCol.implicitHeight
            clip: true

            ColumnLayout {
                id: dockCol
                width: parent.width
                spacing: 16

            SettingsSection {
                title: "Dock"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow { label: "Enable dock"; checked: Settings.dockEnabled; onToggled: { Settings.dockEnabled = !checked; Settings.save() } }
                    }
                    SettingsSubcard {
                        ToggleRow {
                            label: "Floating dock"
                            checked: Settings.dockFloating
                            onToggled: { Settings.dockFloating = !checked; Settings.save() }
                        }
                        Text {
                            text: Settings.dockFloating
                                ? "Inset from the screen edge with a small gap."
                                : (ThemeManager.useFrameEmerge
                                    ? "Joins the screen frame, with the same inverse corners as the widget panels."
                                    : "Flush against the screen edge.")
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            SettingsSection {
                title: "Position"
                SettingsCard {
                    SettingsSubcard {
                        Text {
                            text: "Dock position"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ChoiceChipRow {
                            options: [
                                { id: "bottom", label: "Bottom" },
                                { id: "left", label: "Left" },
                                { id: "right", label: "Right" }
                            ]
                            current: Settings.dockPosition
                            onPicked: id => { Settings.dockPosition = id; Settings.save() }
                        }
                    }
                    SettingsSubcard {
                        Text {
                            text: "Alignment"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ChoiceChipRow {
                            options: [
                                { id: "start", label: "Start" },
                                { id: "center", label: "Center" },
                                { id: "end", label: "End" }
                            ]
                            current: Settings.dockAlignment
                            onPicked: id => { Settings.dockAlignment = id; Settings.save() }
                        }
                    }
                    SettingsSubcard {
                        ToggleRow {
                            label: (Settings.dockPosition === "left" || Settings.dockPosition === "right")
                                ? "Span full height"
                                : "Span full width"
                            checked: Settings.dockSpanFullWidth
                            onToggled: { Settings.dockSpanFullWidth = !checked; Settings.save() }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Window Behavior"
                SettingsCard {
                    SettingsSubcard {
                        Text {
                            text: "Works together with Floating dock. Dodge reserves space for windows; the others overlay."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 8
                            Repeater {
                                model: [
                                    { id: "always-on-top", label: "Always On Top", desc: "Stays above app windows" },
                                    { id: "behind-windows", label: "Behind", desc: "Windows can cover the dock" },
                                    { id: "dodge", label: "Dodge", desc: "Windows shrink to avoid it" },
                                    { id: "auto-hide", label: "Auto-Hide", desc: "Hides until you hover the edge" }
                                ]
                                Rectangle {
                                    id: behaviorCard
                                    required property var modelData
                                    readonly property bool active: Settings.dockBehavior === modelData.id
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    height: 56
                                    radius: 8
                                    color: active ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.30) : ThemeManager.surface1
                                    scale: behaviorMouse.pressed ? ThemeManager.bouncePressScale : (behaviorMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                    Behavior on scale {
                                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            text: behaviorCard.modelData.label
                                            color: ThemeManager.fgPrimary
                                            font.family: ThemeManager.uiFont
                                            font.pixelSize: 13
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: behaviorCard.modelData.desc
                                            color: ThemeManager.fgTertiary
                                            font.family: ThemeManager.uiFont
                                            font.pixelSize: 11
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: behaviorMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { Settings.dockBehavior = behaviorCard.modelData.id; Settings.save() }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Appearance"
                SettingsCard {
                    SettingsSubcard {
                        Text {
                            text: "Dock shape"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ChoiceChipRow {
                            options: [
                                { id: "square", label: "Square corners" },
                                { id: "rounded", label: "Rounded corners" }
                            ]
                            current: Settings.dockShape
                            onPicked: id => { Settings.dockShape = id; Settings.save() }
                        }
                        ColumnLayout {
                            visible: Settings.dockShape === "rounded"
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: `Corner radius: ${Settings.dockRounding}px`
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ValueChipRow {
                                values: [0, 4, 8, 12, 16, 20]
                                current: Settings.dockRounding
                                onPicked: value => { Settings.dockRounding = value; Settings.save() }
                            }
                        }
                    }
                    SettingsSubcard {
                        ToggleRow {
                            label: "Follow Hyprland Window Rules"
                            checked: Settings.dockFollowHyprland
                            onToggled: { Settings.dockFollowHyprland = !checked; Settings.save() }
                        }
                        Text {
                            text: Settings.dockFollowHyprland
                                ? "Fill, borders, and thickness match the Hyprland tab."
                                : "Dock chrome can be set independently. Turn this on to match Hyprland window rules."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    SettingsSubcard {
                        enabled: !Settings.dockFollowHyprland
                        Text {
                            text: "Background fill"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ChoiceChipRow {
                            options: [
                                { id: "opaque", label: "Solid" },
                                { id: "translucent", label: "Transparent" }
                            ]
                            current: Settings.dockBackgroundStyle === "opaque" ? "opaque" : "translucent"
                            onPicked: id => { Settings.dockBackgroundStyle = id; Settings.save() }
                        }
                        TransparencySlider {
                            visible: Settings.dockBackgroundStyle !== "opaque"
                            opacityValue: Settings.dockOpacity
                            onChanged: value => Settings.dockOpacity = value
                            onReleased: Settings.save()
                        }
                        ToggleRow {
                            label: "Dock border"
                            checked: Settings.dockShowBorder
                            onToggled: { Settings.dockShowBorder = !checked; Settings.save() }
                        }
                        ColumnLayout {
                            visible: Settings.dockShowBorder || (Settings.dockFollowHyprland && Settings.hyprShowBorder)
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: `Border size: ${Settings.hyprBorderSize}px`
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ValueChipRow {
                                values: [1, 2, 3, 4, 5]
                                current: Settings.hyprBorderSize
                                onPicked: value => root.applyBorderSize(value)
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Icons"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Show settings icon"
                            checked: Settings.dockShowSettingsIcon
                            onToggled: { Settings.dockShowSettingsIcon = !checked; Settings.save() }
                        }
                    }
                    SettingsSubcard {
                        ToggleRow {
                            label: "Show trash icon"
                            checked: Settings.dockShowTrashIcon
                            onToggled: { Settings.dockShowTrashIcon = !checked; Settings.save() }
                        }
                        Text {
                            text: "Pin apps with the Add icon on the dock. Right-click a pinned app to unpin it."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
            }
        }

        // Theme
        Flickable {
            visible: root.tab === "theme"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: themeCol.implicitHeight
            clip: true

            ColumnLayout {
                id: themeCol
                width: parent.width
                spacing: 16

                SettingsSection {
                    title: "Presets"
                    SettingsCard {
                        ChoiceChipRow {
                            options: [
                            { id: "dark", label: "Dark" },
                            { id: "light", label: "Light" }
                            ]
                            current: Settings.themeMode
                            onPicked: id => { Settings.themeMode = id; Settings.save() }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: 8
                            rowSpacing: 8
                            Repeater {
                                model: root.filteredThemes
                                Rectangle {
                                    id: themeCard
                                    required property var modelData
                                    readonly property color chipBg: modelData.bgBase || ThemeManager.surface1
                                    readonly property color chipFg: modelData.fgPrimary || ThemeManager.fgPrimary
                                    readonly property color chipAccent: modelData.accentBlue || ThemeManager.accentBlue
                                    readonly property color chipBorder: modelData.border0 || ThemeManager.border0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    height: 56
                                    radius: 8
                                    color: chipBg

                                    scale: themeCardMouse.pressed ? ThemeManager.bouncePressScale : (themeCardMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                    Behavior on scale {
                                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        ThemePreview {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            themeId: themeCard.modelData.id
                                            implicitWidth: 120
                                            implicitHeight: 14
                                        }
                                        Text {
                                            text: themeCard.modelData.name
                                            color: themeCard.chipFg
                                            font.family: ThemeManager.uiFont
                                            font.pixelSize: 13
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            visible: themeCard.modelData.custom
                                            text: "custom"
                                            color: themeCard.modelData.fgTertiary || themeCard.chipFg
                                            font.pixelSize: 10
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                    Rectangle {
                                        visible: themeCard.modelData.active
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 5
                                        width: 28
                                        height: 3
                                        radius: 2
                                        color: themeCard.chipAccent
                                    }
                                    MouseArea {
                                        id: themeCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton && themeCard.modelData.custom) {
                                                deleteTheme.themeId = themeCard.modelData.id
                                                deleteTheme.running = true
                                                return
                                            }
                                            Settings.themeMode = themeCard.modelData.mode || Settings.themeMode
                                            Settings.save()
                                            applyTheme.themeId = themeCard.modelData.id
                                            applyTheme.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                SettingsSection {
                    title: "Custom Theme"
                    SettingsCard {
                        Text {
                            text: "Background + 8 accents (hex). Right-click a custom preset above to delete it."
                            color: ThemeManager.fgSecondary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: 8
                            rowSpacing: 8
                            ColorSeed { label: "Background"; text: root.seedBg; onEdited: root.seedBg = value }
                            ColorSeed { label: "Blue"; text: root.seedBlue; onEdited: root.seedBlue = value }
                            ColorSeed { label: "Purple"; text: root.seedPurple; onEdited: root.seedPurple = value }
                            ColorSeed { label: "Pink"; text: root.seedPink; onEdited: root.seedPink = value }
                            ColorSeed { label: "Red"; text: root.seedRed; onEdited: root.seedRed = value }
                            ColorSeed { label: "Orange"; text: root.seedOrange; onEdited: root.seedOrange = value }
                            ColorSeed { label: "Yellow"; text: root.seedYellow; onEdited: root.seedYellow = value }
                            ColorSeed { label: "Green"; text: root.seedGreen; onEdited: root.seedGreen = value }
                            ColorSeed { label: "Teal"; text: root.seedTeal; onEdited: root.seedTeal = value }
                        }

                        Text {
                            text: "Papirus folder color. Auto picks the closest Papirus shade to the Blue accent."
                            color: ThemeManager.fgSecondary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        ComboBox {
                            id: papirusFolderBox
                            Layout.preferredWidth: 280
                            Layout.preferredHeight: 32
                            model: [
                            { id: "auto", label: "Auto (closest to accent)" },
                            { id: "adwaita", label: "adwaita" },
                            { id: "black", label: "black" },
                            { id: "blue", label: "blue" },
                            { id: "bluegrey", label: "bluegrey" },
                            { id: "breeze", label: "breeze" },
                            { id: "brown", label: "brown" },
                            { id: "carmine", label: "carmine" },
                            { id: "cyan", label: "cyan" },
                            { id: "darkcyan", label: "darkcyan" },
                            { id: "deeporange", label: "deeporange" },
                            { id: "green", label: "green" },
                            { id: "grey", label: "grey" },
                            { id: "indigo", label: "indigo" },
                            { id: "magenta", label: "magenta" },
                            { id: "nordic", label: "nordic" },
                            { id: "orange", label: "orange" },
                            { id: "palebrown", label: "palebrown" },
                            { id: "paleorange", label: "paleorange" },
                            { id: "pink", label: "pink" },
                            { id: "red", label: "red" },
                            { id: "teal", label: "teal" },
                            { id: "violet", label: "violet" },
                            { id: "white", label: "white" },
                            { id: "yaru", label: "yaru" },
                            { id: "yellow", label: "yellow" }
                            ]
                            textRole: "label"
                            currentIndex: {
                                const rows = papirusFolderBox.model
                                for (let i = 0; i < rows.length; i++) {
                                    if (rows[i].id === root.seedPapirus)
                                    return i
                                }
                                return 0
                            }
                            onActivated: index => root.seedPapirus = model[index].id
                            background: Rectangle {
                                implicitWidth: 280
                                implicitHeight: 32
                                color: ThemeManager.surface1
                                radius: 6
                            }
                            contentItem: Text {
                                leftPadding: 10
                                rightPadding: 28
                                text: papirusFolderBox.displayText
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            InputField {
                                id: nameField
                                Layout.fillWidth: true
                                text: root.saveName
                                onTextChanged: root.saveName = text
                                background: Rectangle { color: ThemeManager.surface1; radius: 6 }
                            }
                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 32
                                width: 110
                                height: 32
                                radius: 6
                                color: ThemeManager.accentBlue
                                scale: saveMouse.pressed ? ThemeManager.bouncePressScale : (saveMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                Behavior on scale {
                                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                }
                                Text { anchors.centerIn: parent; text: "Save & Apply"; color: ThemeManager.bgBase; font.pixelSize: 12 }
                                MouseArea { id: saveMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: saveTheme.running = true }
                            }
                        }
                    }
                }
            }
        }

        // Wallpaper
        Flickable {
            visible: root.tab === "wallpaper"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: wallpaperCol.implicitHeight
            clip: true

            ColumnLayout {
                id: wallpaperCol
                width: parent.width
                spacing: 16

                SettingsSection {
                    title: "Wallpaper"
                    SettingsCard {
                        SettingsSubcard {
                            Text {
                                text: "Wallpaper folder"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            Text {
                                text: "Root folder for All wallpapers mode, and the parent of theme subfolders used by Theme-based mode."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                InputField {
                                    id: wpDirField
                                    Layout.fillWidth: true
                                    height: 30
                                    text: Settings.wallpaperDir
                                    font.pixelSize: 12
                                    background: Rectangle {
                                        color: ThemeManager.surface1
                                        radius: 6
                                    }
                                    onEditingFinished: {
                                        Settings.wallpaperDir = text
                                        Settings.save()
                                        root.refreshWallpapers()
                                    }
                                }
                                Rectangle {
                                    width: 88
                                    height: 30
                                    radius: 6
                                    color: ThemeManager.accentBlue
                                    scale: wpBrowseMouse.pressed ? ThemeManager.bouncePressScale : (wpBrowseMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                    Behavior on scale {
                                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Browse"
                                        color: ThemeManager.bgBase
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: wpBrowseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            wallpaperFolderPicker.startPath = Settings.wallpaperDir
                                            root.startFilePicker(wallpaperFolderPicker)
                                        }
                                    }
                                }
                            }
                        }
                        SettingsSubcard {
                            Text {
                                text: "Wallpaper source"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            Text {
                                text: Settings.wallpaperSource === "theme"
                                    ? `Theme-based — only images in ${ThemeManager.wallpaperDir} for the active theme.`
                                    : "All wallpapers — every image under the wallpaper folder and its subfolders."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            ChoiceChipFlow {
                                Layout.fillWidth: true
                                options: [
                                    { id: "theme", label: "Theme-based" },
                                    { id: "all", label: "All wallpapers" }
                                ]
                                current: Settings.wallpaperSource
                                onPicked: id => {
                                    Settings.wallpaperSource = id
                                    Settings.save()
                                    root.refreshWallpapers()
                                }
                            }
                        }
                        SettingsSubcard {
                            Text {
                                text: "Wallpaper changer"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            Text {
                                text: Settings.wallpaperMode === "slideshow"
                                    ? "Slideshow cycles through the source set above using the transition below."
                                    : "Static keeps a single wallpaper until you change it in the picker."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            ChoiceChipFlow {
                                Layout.fillWidth: true
                                options: [
                                    { id: "static", label: "Static" },
                                    { id: "slideshow", label: "Slideshow" }
                                ]
                                current: Settings.wallpaperMode
                                onPicked: id => { Settings.wallpaperMode = id; Settings.save() }
                            }
                            Text {
                                visible: Settings.wallpaperMode === "slideshow"
                                text: "Duration"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                                Layout.topMargin: 4
                            }
                            ChoiceChipFlow {
                                visible: Settings.wallpaperMode === "slideshow"
                                Layout.fillWidth: true
                                options: [
                                    { id: "10", label: "10s" },
                                    { id: "30", label: "30s" },
                                    { id: "60", label: "1m" },
                                    { id: "120", label: "2m" },
                                    { id: "300", label: "5m" },
                                    { id: "600", label: "10m" },
                                    { id: "900", label: "15m" },
                                    { id: "1800", label: "30m" },
                                    { id: "3600", label: "60m" }
                                ]
                                current: String(Settings.wallpaperSlideshowInterval)
                                onPicked: id => {
                                    Settings.wallpaperSlideshowInterval = parseInt(id, 10)
                                    Settings.save()
                                }
                            }
                        }
                        SettingsSubcard {
                            Text {
                                text: "Transition"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipFlow {
                                Layout.fillWidth: true
                                options: [
                                    { id: "none", label: "None" },
                                    { id: "simple", label: "Simple" },
                                    { id: "fade", label: "Fade" },
                                    { id: "left", label: "Left" },
                                    { id: "right", label: "Right" },
                                    { id: "top", label: "Top" },
                                    { id: "bottom", label: "Bottom" },
                                    { id: "wipe", label: "Wipe" },
                                    { id: "wave", label: "Wave" },
                                    { id: "grow", label: "Grow" },
                                    { id: "center", label: "Center" },
                                    { id: "any", label: "Any" },
                                    { id: "outer", label: "Outer" },
                                    { id: "random", label: "Random" }
                                ]
                                current: Settings.wallpaperTransition
                                onPicked: id => { Settings.wallpaperTransition = id; Settings.save() }
                            }
                        }
                        SettingsSubcard {
                            Text {
                                text: "Wallpaper Picker"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            Text {
                                text: "Browse wallpapers in a Cover Flow overlay. The list follows the wallpaper source setting above."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 34
                                width: 180
                                height: 34
                                radius: 8
                                color: ThemeManager.accentBlue
                                scale: wpPickerMouse.pressed ? ThemeManager.bouncePressScale : (wpPickerMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                Behavior on scale {
                                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "Open Wallpaper Picker"
                                    color: ThemeManager.bgBase
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: wpPickerMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openWallpaperPicker()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hyprland
        Flickable {
            visible: root.tab === "hypr"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: hyprCol.implicitHeight
            clip: true

            ColumnLayout {
                id: hyprCol
                width: parent.width
                spacing: 16

            SettingsSection {
                title: "Window Rounding"
                SettingsCard {
                    SettingsSubcard {
                        Text {
                            text: ThemeManager.useFrameEmerge
                                ? "In framed (solid + docked) mode, window corners use this same radius as the inner frame corners."
                                : "These rules apply to Hyprland windows. Widgets can follow them from the Widgets tab."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Text {
                            text: `Corner radius: ${Settings.hyprRounding}px`
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ValueChipRow {
                            values: [0, 4, 8, 12, 16, 20, 24, 28, 32, 36]
                            current: Settings.hyprRounding
                            onPicked: value => {
                                Settings.hyprRounding = value
                                Settings.save()
                                ThemeManager.applyHyprWorkspaceLayout()
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Window Borders"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Show borders"
                            checked: Settings.hyprShowBorder
                            onToggled: {
                                Settings.hyprShowBorder = !checked
                                Settings.save()
                                root.applyHyprBorderSizeLive()
                            }
                        }
                        ColumnLayout {
                            visible: Settings.hyprShowBorder
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: `Thickness: ${Settings.hyprBorderSize}px`
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ValueChipRow {
                                values: [1, 2, 3, 4, 5]
                                current: Settings.hyprBorderSize
                                onPicked: value => root.applyBorderSize(value)
                            }
                        }
                    }
                    SettingsSubcard {
                        visible: Settings.hyprShowBorder
                        Text {
                            text: "Fill"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ChoiceChipRow {
                            options: [
                                { id: "solid", label: "Solid" },
                                { id: "gradient", label: "Gradient" }
                            ]
                            current: Settings.hyprBorderFill
                            onPicked: id => {
                                Settings.hyprBorderFill = id
                                Settings.save()
                                root.applyWindowBorder()
                            }
                        }
                        IntSlider {
                            visible: Settings.hyprBorderFill === "gradient"
                            Layout.fillWidth: true
                            label: `Gradient angle: ${Settings.hyprBorderAngle}°`
                            value: Settings.hyprBorderAngle
                            minValue: 0
                            maxValue: 360
                            onChanged: value => Settings.hyprBorderAngle = value
                            onReleased: {
                                Settings.save()
                                root.applyWindowBorder()
                            }
                        }
                        ColumnLayout {
                            visible: Settings.hyprBorderFill === "gradient"
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Border animation"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipRow {
                                options: [
                                    { id: "none", label: "None" },
                                    { id: "once", label: "Once" },
                                    { id: "loop", label: "Loop" }
                                ]
                                current: Settings.hyprBorderAnimation
                                onPicked: id => {
                                    Settings.hyprBorderAnimation = id
                                    Settings.save()
                                    root.applyBorderAngleAnim()
                                }
                            }
                        }
                    }
                    SettingsSubcard {
                        visible: Settings.hyprShowBorder
                        ToggleRow {
                            label: "Transparent borders"
                            checked: Settings.hyprBorderTransparent
                            onToggled: {
                                Settings.hyprBorderTransparent = !checked
                                Settings.save()
                                root.applyWindowBorder()
                            }
                        }
                        IntSlider {
                            visible: Settings.hyprBorderTransparent
                            Layout.fillWidth: true
                            label: `Transparency: ${Settings.hyprBorderTransparency}%`
                            value: Settings.hyprBorderTransparency
                            minValue: 0
                            maxValue: 90
                            onChanged: value => Settings.hyprBorderTransparency = value
                            onReleased: {
                                Settings.save()
                                root.applyWindowBorder()
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Window Gaps"
                SettingsCard {
                    SettingsSubcard {
                        Text {
                            text: `Inner gaps: ${Settings.hyprGapsIn}px`
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ValueChipRow {
                            values: [0, 2, 4, 6, 8, 10, 12, 16, 20]
                            current: Settings.hyprGapsIn
                            onPicked: value => {
                                Settings.hyprGapsIn = value
                                Settings.save()
                                Quickshell.execDetached(["hyprctl", "eval", `hl.config({general={gaps_in=${value}}})`])
                            }
                        }
                    }
                    SettingsSubcard {
                        Text {
                            text: ThemeManager.useFrameEmerge
                                ? `Outer gaps: ${Settings.hyprGapsOut}px (frame thickness; windows sit inside the hole)`
                                : `Outer gaps: ${Settings.hyprGapsOut}px`
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
                        }
                        ValueChipRow {
                            values: [0, 2, 4, 6, 8, 10, 12, 16, 20]
                            current: Settings.hyprGapsOut
                            onPicked: value => {
                                Settings.hyprGapsOut = value
                                Settings.save()
                                ThemeManager.applyHyprWorkspaceLayout()
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Window Animations"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Enable animations"
                            checked: Settings.hyprAnimations
                            onToggled: {
                                Settings.hyprAnimations = !checked
                                Settings.save()
                                Quickshell.execDetached(["hyprctl", "eval", `hl.config({animations={enabled=${Settings.hyprAnimations}}})`])
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Window Shadows"
                SettingsCard {
                    SettingsSubcard {
                        Text {
                            text: "Presets set distance and transparency together."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        ChoiceChipRow {
                            options: [
                                { id: "off", label: "Off" },
                                { id: "light", label: "Light" },
                                { id: "moderate", label: "Moderate" },
                                { id: "heavy", label: "Heavy" }
                            ]
                            current: Settings.hyprShadowPreset
                            onPicked: id => root.applyShadowPreset(id)
                        }
                    }
                    SettingsSubcard {
                        enabled: Settings.hyprShadowPreset !== "off"
                        ToggleRow {
                            label: "Accent-colored shadow"
                            checked: Settings.hyprShadowUseAccent
                            onToggled: {
                                Settings.hyprShadowUseAccent = !checked
                                Settings.save()
                                root.applyWindowShadowColor()
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Background Blur"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Enable blur"
                            checked: Settings.hyprBlurEnabled
                            onToggled: {
                                Settings.hyprBlurEnabled = !checked
                                root.applyHyprBlur()
                            }
                        }
                        IntSlider {
                            visible: Settings.hyprBlurEnabled
                            Layout.fillWidth: true
                            label: `Intensity: ${Settings.hyprBlurSize}`
                            value: Settings.hyprBlurSize
                            minValue: 1
                            maxValue: 20
                            onChanged: value => Settings.hyprBlurSize = value
                            onReleased: {
                                Settings.save()
                                Quickshell.execDetached(["hyprctl", "eval", `hl.config({decoration={blur={size=${Settings.hyprBlurSize}}}})`])
                            }
                        }
                    }
                }
            }

            SettingsSection {
                title: "Window Transparency"
                SettingsCard {
                    SettingsSubcard {
                        ToggleRow {
                            label: "Transparent app windows"
                            checked: Settings.hyprWindowTransparent
                            onToggled: {
                                Settings.hyprWindowTransparent = !checked
                                root.applyWindowOpacity()
                            }
                        }
                        Text {
                            text: "Thunar, Ghostty, VS Code / Codium, Cursor, and Zed. Wallpaper shows through when Background Blur is on."
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        TransparencySlider {
                            visible: Settings.hyprWindowTransparent
                            minOpacity: 0.50
                            opacityValue: Settings.hyprWindowOpacity
                            onChanged: value => Settings.hyprWindowOpacity = value
                            onReleased: root.applyWindowOpacity()
                        }
                    }
                }
            }
            }
        }

        Flickable {
            visible: root.tab === "sddm"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: sddmCol.implicitHeight
            clip: true

            ColumnLayout {
                id: sddmCol
                width: parent.width
                spacing: 16

                SettingsSection {
                    title: "User Avatar"
                    SettingsCard {
                    SettingsSubcard {
                            Text {
                                text: "Shown on the SDDM login screen in place of the first-letter placeholder. The image is saved to ~/.face.icon and copied into /usr/share/sddm/faces."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16

                                Rectangle {
                                    id: avatarRing
                                    width: 80
                                    height: 80
                                    radius: 40
                                    color: ThemeManager.surface1

                                    Image {
                                        id: sddmAvatarImage
                                        anchors.fill: parent
                                        source: root.sddmAvatarPreview
                                        fillMode: Image.PreserveAspectCrop
                                        visible: root.sddmAvatarExists && status === Image.Ready
                                        cache: false
                                        asynchronous: true
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: sddmAvatarImage.width
                                                height: sddmAvatarImage.height
                                                radius: width / 2
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !sddmAvatarImage.visible
                                        text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 32
                                        font.weight: Font.DemiBold
                                        color: ThemeManager.accentBlue
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: root.sddmAvatarExists ? "Current: ~/.face.icon" : "No avatar set — login will show your first initial"
                                        color: root.sddmAvatarExists ? ThemeManager.accentGreen : ThemeManager.fgTertiary
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }

                                    InputField {
                                        id: sddmAvatarPathField
                                        Layout.fillWidth: true
                                        height: 30
                                        placeholderText: "Path to image, e.g. ~/Pictures/avatar.png"
                                        text: root.sddmAvatarPath
                                        font.pixelSize: 12
                                        background: Rectangle {
                                            color: ThemeManager.surface1
                                            radius: 6
                                        }
                                        onTextChanged: root.sddmAvatarPath = text
                                    }

                                    Row {
                                        spacing: 8

                                        Rectangle {
                                            width: 88
                                            height: 30
                                            radius: 6
                                            color: ThemeManager.accentBlue
                                            scale: sddmBrowseMouse.pressed ? ThemeManager.bouncePressScale : (sddmBrowseMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                            Behavior on scale {
                                                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Browse"
                                                color: ThemeManager.bgBase
                                                font.family: ThemeManager.uiFont
                                                font.pixelSize: 12
                                            }
                                            MouseArea {
                                                id: sddmBrowseMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    sddmImagePicker.startPath = root.sddmAvatarPath || `${Quickshell.env("HOME")}/Pictures`
                                                    root.startFilePicker(sddmImagePicker)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 110
                                            height: 30
                                            radius: 6
                                            color: ThemeManager.surface1
                                            scale: sddmSetMouse.pressed ? ThemeManager.bouncePressScale : (sddmSetMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                            Behavior on scale {
                                                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: root.sddmAvatarSuccess ? "Set!" : "Set Avatar"
                                                color: root.sddmAvatarSuccess ? ThemeManager.accentGreen : ThemeManager.accentBlue
                                                font.family: ThemeManager.uiFont
                                                font.pixelSize: 12
                                            }
                                            MouseArea {
                                                id: sddmSetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    let imgPath = root.sddmAvatarPath.trim()
                                                    if (!imgPath)
                                                    return
                                                    if (imgPath.startsWith("~"))
                                                    imgPath = Quickshell.env("HOME") + imgPath.slice(1)
                                                    root.sddmStatusMessage = ""
                                                    sddmAvatarCopier.command = ["bash", `${Quickshell.shellDir}/scripts/sddm-set-avatar.sh`, imgPath]
                                                    sddmAvatarCopier.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                    
                    }
                }
                }

                SettingsSection {
                    title: "Login Background"
                    SettingsCard {
                        SettingsSubcard {
                            Text {
                                text: "Match the desktop wallpaper, or pick a different image. Theme colors update with Settings → Theme. Wallpaper and blur refresh when the desktop wallpaper changes (if Match desktop is on) or when you Apply."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "Wallpaper source"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            ChoiceChipRow {
                                options: [
                                    { id: "desktop", label: "Match desktop" },
                                    { id: "custom", label: "Custom image" }
                                ]
                                current: Settings.sddmFollowDesktop ? "desktop" : "custom"
                                onPicked: id => {
                                    Settings.sddmFollowDesktop = id === "desktop"
                                    Settings.save()
                                }
                            }
                            Text {
                                visible: Settings.sddmFollowDesktop
                                text: {
                                    const p = root.sddmWallpaperPath()
                                    return p ? `Current: ${root.tidyHomePath(p)}` : "No desktop wallpaper set yet"
                                }
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            ColumnLayout {
                                visible: !Settings.sddmFollowDesktop
                                Layout.fillWidth: true
                                spacing: 8
                                InputField {
                                    id: sddmWallpaperPathField
                                    Layout.fillWidth: true
                                    height: 30
                                    placeholderText: "Path to image in your wallpaper folder"
                                    text: Settings.sddmCustomWallpaper
                                    font.pixelSize: 12
                                    background: Rectangle {
                                        color: ThemeManager.surface1
                                        radius: 6
                                    }
                                    onTextChanged: Settings.sddmCustomWallpaper = text
                                }
                                Rectangle {
                                    width: 88
                                    height: 30
                                    radius: 6
                                    color: ThemeManager.accentBlue
                                    scale: sddmWpBrowseMouse.pressed ? ThemeManager.bouncePressScale : (sddmWpBrowseMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                    Behavior on scale {
                                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Browse"
                                        color: ThemeManager.bgBase
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: sddmWpBrowseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const start = root.expandHome(Settings.sddmCustomWallpaper || Settings.wallpaperDir)
                                            sddmWallpaperPicker.startPath = start || `${Quickshell.env("HOME")}/Pictures/Wallpapers`
                                            root.startFilePicker(sddmWallpaperPicker)
                                        }
                                    }
                                }
                            }
                        }
                        SettingsSubcard {
                            Text {
                                text: "Preview"
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 13
                            }
                            Rectangle {
                                Layout.preferredWidth: 220
                                Layout.preferredHeight: 124
                                radius: 8
                                color: ThemeManager.surface1
                                clip: true

                                Image {
                                    id: sddmWpPreview
                                    anchors.fill: parent
                                    source: {
                                        const p = root.sddmWallpaperPath()
                                        return p ? `file://${p}` : ""
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                    layer.enabled: visible && Settings.sddmBlurEnabled && Settings.sddmBlurAmount > 0
                                    layer.effect: FastBlur {
                                        radius: Settings.sddmBlurAmount
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !sddmWpPreview.visible
                                    text: "No preview"
                                    color: ThemeManager.fgTertiary
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 12
                                }
                            }
                        }
                        SettingsSubcard {
                            ToggleRow {
                                label: "Blur background"
                                checked: Settings.sddmBlurEnabled
                                onToggled: {
                                    Settings.sddmBlurEnabled = !checked
                                    Settings.save()
                                }
                            }
                            IntSlider {
                                visible: Settings.sddmBlurEnabled
                                label: `Blur amount  ${Settings.sddmBlurAmount}`
                                value: Settings.sddmBlurAmount
                                minValue: 1
                                maxValue: 40
                                onChanged: value => Settings.sddmBlurAmount = value
                                onReleased: Settings.save()
                            }
                        }
                    }
                }

                SettingsSection {
                    title: "Login Window Transparency"
                    SettingsCard {
                        SettingsSubcard {
                            Text {
                                text: "Opacity of the login plate. Apply writes colors, wallpaper, blur, and opacity. Passwordless apply needs the yahr-sddm sudoers rule."
                                color: ThemeManager.fgTertiary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            TransparencySlider {
                                opacityValue: Settings.sddmLoginOpacity
                                onChanged: value => {
                                    Settings.sddmLoginOpacity = value
                                    Settings.save()
                                }
                            }
                        }
                        SettingsSubcard {
                            Row {
                                spacing: 10
                                Rectangle {
                                    width: 56
                                    height: 30
                                    radius: 6
                                    color: ThemeManager.surface1
                                    Text {
                                        anchors.centerIn: parent
                                        text: `${Math.round(Settings.sddmLoginOpacity * 100)}%`
                                        color: ThemeManager.fgPrimary
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 13
                                    }
                                }
                                Rectangle {
                                    width: 130
                                    height: 30
                                    radius: 6
                                    color: ThemeManager.accentBlue
                                    scale: sddmApplyMouse.pressed ? ThemeManager.bouncePressScale : (sddmApplyMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                                    Behavior on scale {
                                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.sddmOpacitySuccess ? "Applied!" : "Apply to SDDM"
                                        color: ThemeManager.bgBase
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: sddmApplyMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applySddm()
                                    }
                                }
                            }
                            Text {
                                visible: root.sddmOpacityError || root.sddmStatusMessage.length > 0
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: root.sddmOpacityError
                                    ? "Could not write theme.conf. Install passwordless sudo with: ~/.local/share/yahr-shell/sddm/setup-sudoers.sh"
                                    : root.sddmStatusMessage
                                color: root.sddmOpacityError ? ThemeManager.accentRed : ThemeManager.fgSecondary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }

        Item {
            visible: root.tab === "about"
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: aboutFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: aboutContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: aboutContent
                    width: parent.width
                    spacing: 8

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(160, aboutFlick.height - 180)
                        source: ThemeManager.aboutLogoSource
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        antialiasing: true
                        asynchronous: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Yahr Shell"
                        color: ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Yet Another Hyprland Rice"
                        color: ThemeManager.fgSecondary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 13
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "v2.0"
                        color: ThemeManager.accentBlue
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        spacing: 12

                        Rectangle {
                            width: 196
                            height: 40
                            radius: 8
                            color: ghMouse.containsMouse
                                ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.22)
                                : ThemeManager.overlay(0.06)
                            scale: ghMouse.pressed ? ThemeManager.bouncePressScale : (ghMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                            Behavior on scale {
                                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "\uf09b"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 17
                                    color: ThemeManager.accentBlue
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "GitHub Repository"
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 13
                                    color: ThemeManager.fgPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                id: ghMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/bgibson72/yahr-shell"])
                            }
                        }

                        Rectangle {
                            width: 196
                            height: 40
                            radius: 8
                            color: webMouse.containsMouse
                                ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.22)
                                : ThemeManager.overlay(0.06)
                            scale: webMouse.pressed ? ThemeManager.bouncePressScale : (webMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                            Behavior on scale {
                                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "\uf0ac"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 15
                                    color: ThemeManager.accentBlue
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "vegvisirdesign.me"
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 13
                                    color: ThemeManager.fgPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                id: webMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["xdg-open", "https://vegvisirdesign.me"])
                            }
                        }
                    }

                    Item { Layout.fillWidth: true; height: 10 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: ThemeManager.overlay(0.10) }

                    Row {
                        Layout.topMargin: 6
                        spacing: 8
                        Text {
                            text: "\uf1da"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 15
                            color: ThemeManager.accentBlue
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Update Log"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: ThemeManager.fgPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Repeater {
                        model: [
                            {
                                version: "v2.0",
                                date: "August 2026",
                                summary: "Full rewrite of the Quickshell desktop: modular bar, dock, launcher, and settings; Control Center split into Network, Bluetooth, Power, and Audio popups; Hyprland-matched chrome (borders, rounding, shadows); click-outside-to-close panels; searchable app launcher with list/grid views; dock pin/unpin from the add-item panel; theme-aware About logos and placeholder colors."
                            },
                            {
                                version: "v1.6",
                                date: "June 2026",
                                summary: "Widget color consistency across all panels; workspace style toggle (numbers/dots); live widget borders; ThemeManager preferences persist across theme switches; flat All Wallpapers grid; GTK theme mapping fixes."
                            },
                            {
                                version: "v1.5",
                                date: "2026",
                                summary: "Flexible date format controls; SDDM & Hyprlock date sync; wallpaper persistence across reboots; awww daemon support."
                            },
                            {
                                version: "v1.4",
                                date: "2026",
                                summary: "Glass UI overhaul — frosted panels, hover transitions, glass window borders, and Mako notification styling."
                            },
                            {
                                version: "v1.0",
                                date: "2025",
                                summary: "Initial yahr-quickshell release — Hyprland + Quickshell desktop with unified theming and a glassmorphism UI."
                            }
                        ]
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.version
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: ThemeManager.accentBlue
                                }
                                Text {
                                    text: "— " + modelData.date
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 12
                                    color: ThemeManager.fgTertiary
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                color: ThemeManager.fgSecondary
                                wrapMode: Text.WordWrap
                                lineHeight: 1.35
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                height: 1
                                color: ThemeManager.overlay(0.07)
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        textFormat: Text.RichText
                        text: '<a href="https://opensource.org/license/mit">MIT License</a>'
                        color: ThemeManager.fgTertiary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                        linkColor: ThemeManager.accentBlue
                        onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
                        HoverHandler {
                            cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 8
                        text: "Made with love for the Arch + Hyprland community"
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                        color: ThemeManager.fgTertiary
                    }
                }
            }
        }
            }
        }
    }

    component ValueChipRow: Flow {
        id: chips
        property var values: []
        property int current: 0
        signal picked(int value)
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: chips.values
            Rectangle {
                id: chip
                required property var modelData
                width: 40
                height: 28
                radius: 6
                color: chips.current === modelData ? ThemeManager.accentBlue : ThemeManager.surface1
                scale: chipMouse.pressed ? ThemeManager.bouncePressScale : (chipMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }
                Text {
                    anchors.centerIn: parent
                    text: chip.modelData
                    color: chips.current === chip.modelData ? ThemeManager.bgBase : ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    enabled: chips.enabled
                    hoverEnabled: chips.enabled
                    cursorShape: chips.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: chips.picked(chip.modelData)
                }
            }
        }
    }

    component ToggleRow: RowLayout {
        id: tog
        property string label
        property bool checked
        signal toggled()
        spacing: 10
        Layout.fillWidth: true
        Text {
            text: tog.label
            color: tog.enabled ? ThemeManager.fgPrimary : ThemeManager.fgTertiary
            font.family: ThemeManager.uiFont
            font.pixelSize: 13
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Rectangle {
            id: toggleTrack
            Layout.preferredWidth: 42
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            width: 42
            height: 22
            radius: 11
            color: tog.checked ? ThemeManager.accentBlue : ThemeManager.surface2

            scale: tog.enabled && toggleMouse.pressed ? ThemeManager.bouncePressScale : (tog.enabled && toggleMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                x: tog.checked ? 22 : 2
                y: 2
                color: ThemeManager.fgPrimary
                Behavior on x { NumberAnimation { duration: 120 } }
            }
        // Keep `checked` as a binding to Settings. Assigning it here would
        // detach the switch from saved values after the first click.
        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            enabled: tog.enabled
            hoverEnabled: tog.enabled
            cursorShape: tog.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: tog.toggled()
        }
        }
    }

    component TransparencySlider: ColumnLayout {
        id: sliderRoot
        property real opacityValue: 0.7
        property real minOpacity: 0.15
        signal changed(real value)
        signal released()
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: `Transparency: ${Math.round((1.0 - sliderRoot.opacityValue) * 100)}%`
            color: ThemeManager.fgPrimary
            font.family: ThemeManager.uiFont
            font.pixelSize: 13
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 28

            Rectangle {
                id: tTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: ThemeManager.surface1
                Rectangle {
                    width: Math.max(tHandle.width / 2, tHandle.x + tHandle.width / 2)
                    height: parent.height
                    radius: parent.radius
                    color: ThemeManager.accentBlue
                }
            }
            Rectangle {
                id: tHandle
                width: 18
                height: 18
                radius: 9
                color: tSliderMouse.pressed || tSliderMouse.containsMouse ? ThemeManager.accentBlue : ThemeManager.fgPrimary
                anchors.verticalCenter: parent.verticalCenter
                x: {
                    const span = Math.max(0, parent.width - width)
                    const t = (sliderRoot.opacityValue - sliderRoot.minOpacity) / (1.0 - sliderRoot.minOpacity)
                    return Math.max(0, Math.min(span, span * t))
                }
            }
            MouseArea {
                id: tSliderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function apply(mx) {
                    const span = Math.max(1, width - tHandle.width)
                    const t = Math.max(0, Math.min(1, (mx - tHandle.width / 2) / span))
                    sliderRoot.changed(sliderRoot.minOpacity + t * (1.0 - sliderRoot.minOpacity))
                }
                onPressed: apply(mouse.x)
                onPositionChanged: if (pressed) apply(mouse.x)
                onReleased: sliderRoot.released()
            }
        }
    }

    component IntSlider: ColumnLayout {
        id: sliderRoot
        property string label: ""
        property int value: 0
        property int minValue: 0
        property int maxValue: 100
        signal changed(int value)
        signal released()
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: sliderRoot.label
            color: ThemeManager.fgPrimary
            font.family: ThemeManager.uiFont
            font.pixelSize: 13
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 28

            Rectangle {
                id: iTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: ThemeManager.surface1
                Rectangle {
                    width: Math.max(iHandle.width / 2, iHandle.x + iHandle.width / 2)
                    height: parent.height
                    radius: parent.radius
                    color: ThemeManager.accentBlue
                }
            }
            Rectangle {
                id: iHandle
                width: 18
                height: 18
                radius: 9
                color: iSliderMouse.pressed || iSliderMouse.containsMouse ? ThemeManager.accentBlue : ThemeManager.fgPrimary
                anchors.verticalCenter: parent.verticalCenter
                x: {
                    const span = Math.max(0, parent.width - width)
                    const range = Math.max(1, sliderRoot.maxValue - sliderRoot.minValue)
                    const t = (sliderRoot.value - sliderRoot.minValue) / range
                    return Math.max(0, Math.min(span, span * t))
                }
            }
            MouseArea {
                id: iSliderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function apply(mx) {
                    const span = Math.max(1, width - iHandle.width)
                    const t = Math.max(0, Math.min(1, (mx - iHandle.width / 2) / span))
                    const range = sliderRoot.maxValue - sliderRoot.minValue
                    sliderRoot.changed(Math.round(sliderRoot.minValue + t * range))
                }
                onPressed: apply(mouse.x)
                onPositionChanged: if (pressed) apply(mouse.x)
                onReleased: sliderRoot.released()
            }
        }
    }

    component ColorSeed: RowLayout {
        property string label
        property string text
        signal edited(string value)
        spacing: 6
        Layout.fillWidth: true
        Text {
            text: label
            Layout.preferredWidth: 80
            color: ThemeManager.fgSecondary
            font.pixelSize: 12
        }
        Rectangle {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            width: 18
            height: 18
            radius: 4
            color: parent.text
            border.color: ThemeManager.border0
        }
        InputField {
            Layout.fillWidth: true
            text: parent.text
            font.pixelSize: 12
            background: Rectangle { color: ThemeManager.cardColor; radius: 4 }
            onEditingFinished: parent.edited(text)
        }
    }

    Process {
        id: wallpaperScan
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/list-wallpapers.py`, root.wallpaperScanRoot()]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                root.wallpaperImages = lines
            }
        }
    }

    Connections {
        target: ThemeManager
        function onWallpaperDirChanged() {
            if (root.tab === "wallpaper" || Settings.wallpaperSource === "theme")
                root.refreshWallpapers()
        }
    }

    Process {
        id: wallpaperFolderPicker
        running: false
        property string startPath: ""
        command: ["python3", `${Quickshell.shellDir}/scripts/pick-folder.py`, startPath]
        onRunningChanged: if (!running) root.endFilePicker()
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length > 0) {
                    Settings.wallpaperDir = root.tidyHomePath(path)
                    Settings.save()
                    root.refreshWallpapers()
                }
            }
        }
    }

    Process {
        id: sddmThemeReader
        running: false
        command: ["sh", "-c", "grep '^WidgetOpacity=' /usr/share/sddm/themes/yahr-theme/theme.conf 2>/dev/null | grep -oE '[0-9]+\\.?[0-9]*'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(this.text.trim())
                if (!isNaN(v))
                    Settings.sddmLoginOpacity = v
            }
        }
    }

    Process {
        id: sddmThemeWriter
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = this.text.trim()
                if (result === "OK" || result === "OK_NO_WALLPAPER") {
                    root.sddmOpacityError = false
                    root.sddmOpacitySuccess = true
                    sddmOpacitySuccessTimer.restart()
                    if (result === "OK_NO_WALLPAPER")
                        root.sddmStatusMessage = "Applied colors. No wallpaper file was found to copy."
                } else {
                    root.sddmOpacityError = true
                }
            }
        }
    }

    Process {
        id: sddmAvatarChecker
        running: false
        command: ["sh", "-c", "[ -f \"$HOME/.face.icon\" ] && echo exists || echo missing"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sddmAvatarExists = this.text.trim() === "exists"
                if (root.sddmAvatarExists)
                    root.sddmAvatarPreview = `file://${Quickshell.env("HOME")}/.face.icon?${Date.now()}`
                else
                    root.sddmAvatarPreview = ""
            }
        }
    }

    Process {
        id: sddmAvatarCopier
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = this.text.trim()
                if (result === "OK" || result === "HOME_ONLY") {
                    root.sddmAvatarSuccess = true
                    sddmAvatarSuccessTimer.restart()
                    if (result === "HOME_ONLY")
                        root.sddmStatusMessage = "Saved ~/.face.icon. Run ~/.local/share/yahr-shell/sddm/setup-sudoers.sh so the login screen can use the system face file."
                    root.refreshSddm()
                } else {
                    root.sddmStatusMessage = "Could not copy the image. Check the path and try again."
                }
            }
        }
    }

    Process {
        id: sddmImagePicker
        running: false
        property string startPath: ""
        command: ["python3", `${Quickshell.shellDir}/scripts/pick-image.py`, startPath]
        onRunningChanged: if (!running) root.endFilePicker()
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length > 0) {
                    root.sddmAvatarPath = path
                    sddmAvatarPathField.text = path
                }
            }
        }
    }

    Process {
        id: sddmWallpaperPicker
        running: false
        property string startPath: ""
        command: ["python3", `${Quickshell.shellDir}/scripts/pick-image.py`, startPath, "Select Login Wallpaper"]
        onRunningChanged: if (!running) root.endFilePicker()
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length > 0) {
                    Settings.sddmCustomWallpaper = root.tidyHomePath(path)
                    Settings.save()
                    sddmWallpaperPathField.text = Settings.sddmCustomWallpaper
                }
            }
        }
    }

    FileView {
        id: lastWallpaperFile
        path: `${Quickshell.env("HOME")}/.config/yahr/last-wallpaper`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.lastWallpaperPath = lastWallpaperFile.text().trim()
            } catch (e) {
                root.lastWallpaperPath = ""
            }
        }
        onLoadFailed: root.lastWallpaperPath = ""
    }

    Timer {
        id: sddmOpacitySuccessTimer
        interval: 1600
        repeat: false
        onTriggered: root.sddmOpacitySuccess = false
    }

    Timer {
        id: sddmAvatarSuccessTimer
        interval: 1600
        repeat: false
        onTriggered: root.sddmAvatarSuccess = false
    }

    component ChoiceChipFlow: Flow {
        id: chips
        property var options: []
        property string current: ""
        signal picked(string id)
        spacing: 8
        Repeater {
            model: chips.options
            Rectangle {
                id: chip
                required property var modelData
                width: chipLabel.implicitWidth + 20
                height: 28
                radius: 8
                color: chips.current === modelData.id ? ThemeManager.accentBlue : ThemeManager.surface1
                scale: chipMouse.pressed ? ThemeManager.bouncePressScale : (chipMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }
                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chips.current === chip.modelData.id ? ThemeManager.bgBase : ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chips.picked(chip.modelData.id)
                }
            }
        }
    }

    component ChoiceChipRow: Flow {
        id: chips
        property var options: []
        property string current: ""
        property var disabledIds: []
        signal picked(string id)
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: chips.options
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool selected: chips.current === modelData.id
                readonly property bool chipDisabled: chips.disabledIds.indexOf(modelData.id) !== -1
                width: chipLabel.implicitWidth + 20
                height: 28
                radius: 8
                opacity: chipDisabled ? 0.45 : 1
                color: chip.selected ? ThemeManager.accentBlue : ThemeManager.surface1
                scale: !chip.chipDisabled && chipMouse.pressed ? ThemeManager.bouncePressScale : (!chip.chipDisabled && chipMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }
                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chip.selected ? ThemeManager.bgBase : ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    enabled: !chip.chipDisabled
                    hoverEnabled: !chip.chipDisabled
                    cursorShape: chip.chipDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: chips.picked(chip.modelData.id)
                }
            }
        }
    }

    component FontChipFlow: Flow {
        id: fonts
        property string current: ""
        signal picked(string key)
        spacing: 8
        Repeater {
            model: ThemeManager.uiFontCatalog
            Rectangle {
                id: fontChip
                required property var modelData
                readonly property bool selected: fonts.current === modelData.key || ThemeManager.listHas(modelData.families, fonts.current)
                width: fontChipLabel.implicitWidth + 20
                height: 30
                radius: 8
                color: selected ? ThemeManager.accentBlue : ThemeManager.surface1
                scale: fontChipMouse.pressed ? ThemeManager.bouncePressScale : (fontChipMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                }
                Text {
                    id: fontChipLabel
                    anchors.centerIn: parent
                    text: fontChip.modelData.label
                    color: fontChip.selected ? ThemeManager.bgBase : ThemeManager.fgPrimary
                    font.family: ThemeManager.resolveUiFont(fontChip.modelData.key)
                    font.pixelSize: 12
                }
                MouseArea {
                    id: fontChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fonts.picked(fontChip.modelData.key)
                }
            }
        }
    }
}

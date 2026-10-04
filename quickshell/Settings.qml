pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string uiFont: "Inter"
    property string themeMode: "dark"
    property real widgetOpacity: 1.0
    property bool widgetTransparent: false
    property bool followHyprlandRules: false
    property bool showWidgetBorders: false
    property int widgetBorderWidth: 1
    property bool blur: false
    property bool clockFormat24hr: false
    property bool showSeconds: false
    property string dateFormat: "MDY"
    property bool dateLong: false
    property bool showDayOfWeek: false
    property bool weatherUseFahrenheit: true
    property string weatherLocation: ""

    property string barPosition: "top"
    property string barSize: "small"
    property string barStyle: "single"
    property string barBackgroundStyle: "translucent"
    property real barOpacity: 0.70
    property bool barFloating: false
    property bool barShowBorder: false
    property bool barFollowHyprland: false
    property bool barRoundingFollowHyprland: false
    property int barRounding: 24
    property bool showWeatherInBar: false
    property bool showBatteryPercent: false
    property bool showVolumePercent: false
    property bool showNetworkSpeed: false
    property bool showQuickLaunch: true
    property bool showSystemTray: false
    property bool showMediaPlayer: false
    property bool showUpdateChecker: true
    property int minWorkspaces: 4
    property string workspaceStyle: "dots"

    property bool dockEnabled: true
    property string dockPosition: "bottom"
    property string dockAlignment: "center"
    property bool dockFloating: true
    property string dockBehavior: "always-on-top"
    property string dockBackgroundStyle: "translucent"
    property real dockOpacity: 0.70
    property bool dockShowBorder: false
    property bool dockFollowHyprland: false
    property string dockShape: "rounded"
    property int dockRounding: 12
    property int dockIconSize: 58
    property bool dockSpanFullWidth: false
    property bool dockShowSettingsIcon: true
    property bool dockShowTrashIcon: true
    property var dockPinnedApps: []

    property int hyprRounding: 12
    property bool hyprShowBorder: true
    property int hyprBorderSize: 3
    property bool hyprBorderTransparent: true
    property int hyprBorderTransparency: 65
    property string hyprBorderFill: "gradient"
    property int hyprBorderAngle: 45
    property string hyprBorderAnimation: "none"
    property int hyprGapsIn: 5
    property int hyprGapsOut: 10
    property bool hyprAnimations: true
    property string hyprShadowPreset: "moderate"
    property int hyprShadowRange: 20
    property int hyprShadowAlpha: 33
    property bool hyprShadowUseAccent: false
    property bool hyprBlurEnabled: false
    property int hyprBlurSize: 10
    property bool hyprWindowTransparent: false
    property real hyprWindowOpacity: 0.92
    property string screenshotDir: "~/Pictures/Screenshots"
    property string wallpaperDir: "~/Pictures/Wallpapers"
    property string currentWallpaper: ""
    property string wallpaperTransition: "fade"
    // "theme" → only images under the active theme folder; "all" → recurse the wallpaper root
    property string wallpaperSource: "theme"
    // "static" → single wallpaper; "slideshow" → cycle using wallpaperSlideshowInterval
    property string wallpaperMode: "static"
    // Slideshow step in seconds (10 … 3600)
    property int wallpaperSlideshowInterval: 300
    property string calendarFilePath: "~/.config/yahr/calendar.ics"
    property int calendarRefreshInterval: 15
    property string calendarWeekStart: "sunday"
    property bool screenshotSaveToDisk: true
    property bool screenshotCopyToClipboard: true
    property bool launcherGridView: false
    property bool sddmFollowDesktop: true
    property string sddmCustomWallpaper: ""
    property bool sddmBlurEnabled: true
    property int sddmBlurAmount: 20
    property real sddmLoginOpacity: 0.75

    readonly property string settingsPath: `${Quickshell.env("HOME")}/.config/yahr/settings.json`
    property bool ready: false
    signal loaded()

    function toObject() {
        return {
            general: {
                uiFont: uiFont,
                themeMode: themeMode,
                widgetOpacity: widgetOpacity,
                widgetTransparent: widgetTransparent,
                followHyprlandRules: followHyprlandRules,
                showWidgetBorders: showWidgetBorders,
                widgetBorderWidth: widgetBorderWidth,
                blur: blur,
                clockFormat24hr: clockFormat24hr,
                showSeconds: showSeconds,
                dateFormat: dateFormat,
                dateLong: dateLong,
                showDayOfWeek: showDayOfWeek,
                weatherUseFahrenheit: weatherUseFahrenheit,
                weatherLocation: weatherLocation,
                launcherGridView: launcherGridView
            },
            bar: {
                position: barPosition,
                barSize: barSize,
                barStyle: barStyle,
                backgroundStyle: barBackgroundStyle,
                barOpacity: barOpacity,
                floating: barFloating,
                showBorder: barShowBorder,
                followHyprland: barFollowHyprland,
                roundingFollowHyprland: barRoundingFollowHyprland,
                rounding: barRounding,
                showWeatherInBar: showWeatherInBar,
                showBatteryPercent: showBatteryPercent,
                showVolumePercent: showVolumePercent,
                showNetworkSpeed: showNetworkSpeed,
                showQuickLaunch: showQuickLaunch,
                showSystemTray: showSystemTray,
                showMediaPlayer: showMediaPlayer,
                showUpdateChecker: showUpdateChecker,
                minWorkspaces: minWorkspaces,
                workspaceStyle: workspaceStyle
            },
            dock: {
                enabled: dockEnabled,
                position: dockPosition,
                alignment: dockAlignment,
                floating: dockFloating,
                behavior: dockBehavior,
                backgroundStyle: dockBackgroundStyle,
                opacity: dockOpacity,
                showBorder: dockShowBorder,
                followHyprland: dockFollowHyprland,
                shape: dockShape,
                rounding: dockRounding,
                iconSize: dockIconSize,
                spanFullWidth: dockSpanFullWidth,
                showSettingsIcon: dockShowSettingsIcon,
                showTrashIcon: dockShowTrashIcon,
                pinned: dockPinnedApps
            },
            hypr: {
                rounding: hyprRounding,
                showBorder: hyprShowBorder,
                borderSize: hyprBorderSize,
                borderTransparent: hyprBorderTransparent,
                borderTransparency: hyprBorderTransparency,
                borderFill: hyprBorderFill,
                borderAngle: hyprBorderAngle,
                borderAnimation: hyprBorderAnimation,
                gapsIn: hyprGapsIn,
                gapsOut: hyprGapsOut,
                animations: hyprAnimations,
                shadowPreset: hyprShadowPreset,
                shadowRange: hyprShadowRange,
                shadowAlpha: hyprShadowAlpha,
                shadowUseAccent: hyprShadowUseAccent,
                blurEnabled: hyprBlurEnabled,
                blurSize: hyprBlurSize,
                windowTransparent: hyprWindowTransparent,
                windowOpacity: hyprWindowOpacity
            },
            screenshot: {
                saveLocation: screenshotDir,
                saveToDisk: screenshotSaveToDisk,
                copyToClipboard: screenshotCopyToClipboard
            },
            wallpaper: {
                directory: wallpaperDir,
                current: currentWallpaper,
                transition: wallpaperTransition,
                source: wallpaperSource,
                mode: wallpaperMode,
                slideshowInterval: wallpaperSlideshowInterval
            },
            calendar: {
                filePath: calendarFilePath,
                refreshInterval: calendarRefreshInterval,
                weekStart: calendarWeekStart
            },
            sddm: {
                followDesktop: sddmFollowDesktop,
                customWallpaper: sddmCustomWallpaper,
                blurEnabled: sddmBlurEnabled,
                blurAmount: sddmBlurAmount,
                loginOpacity: sddmLoginOpacity
            }
        }
    }

    function applyObject(data) {
        if (!data)
            return
        const g = data.general || {}
        if (g.uiFont !== undefined) uiFont = g.uiFont
        if (g.themeMode !== undefined) themeMode = g.themeMode
        if (g.widgetOpacity !== undefined) widgetOpacity = g.widgetOpacity
        if (g.widgetTransparent !== undefined) widgetTransparent = g.widgetTransparent
        if (g.followHyprlandRules !== undefined) followHyprlandRules = g.followHyprlandRules
        if (g.showWidgetBorders !== undefined) showWidgetBorders = g.showWidgetBorders
        if (g.widgetBorderWidth !== undefined) widgetBorderWidth = g.widgetBorderWidth
        if (g.blur !== undefined) blur = g.blur
        if (g.clockFormat24hr !== undefined) clockFormat24hr = g.clockFormat24hr
        if (g.showSeconds !== undefined) showSeconds = g.showSeconds
        if (g.dateFormat !== undefined) dateFormat = g.dateFormat
        if (g.dateLong !== undefined) dateLong = g.dateLong
        if (g.showDayOfWeek !== undefined) showDayOfWeek = g.showDayOfWeek
        if (g.weatherUseFahrenheit !== undefined) weatherUseFahrenheit = g.weatherUseFahrenheit
        if (g.weatherLocation !== undefined) weatherLocation = g.weatherLocation
        if (g.launcherGridView !== undefined) launcherGridView = g.launcherGridView

        const b = data.bar || {}
        if (b.position !== undefined) barPosition = b.position
        if (b.barSize !== undefined) barSize = b.barSize
        if (b.barStyle !== undefined) barStyle = b.barStyle
        if (b.backgroundStyle !== undefined) barBackgroundStyle = b.backgroundStyle
        if (b.barOpacity !== undefined) barOpacity = b.barOpacity
        if (b.floating !== undefined) barFloating = b.floating
        if (b.showBorder !== undefined) barShowBorder = b.showBorder
        if (b.followHyprland !== undefined) barFollowHyprland = b.followHyprland
        if (b.roundingFollowHyprland !== undefined) barRoundingFollowHyprland = b.roundingFollowHyprland
        if (b.rounding !== undefined) barRounding = b.rounding
        if (b.showWeatherInBar !== undefined) showWeatherInBar = b.showWeatherInBar
        if (b.showBatteryPercent !== undefined) showBatteryPercent = b.showBatteryPercent
        if (b.showVolumePercent !== undefined) showVolumePercent = b.showVolumePercent
        if (b.showNetworkSpeed !== undefined) showNetworkSpeed = b.showNetworkSpeed
        if (b.showQuickLaunch !== undefined) showQuickLaunch = b.showQuickLaunch
        if (b.showSystemTray !== undefined) showSystemTray = b.showSystemTray
        if (b.showMediaPlayer !== undefined) showMediaPlayer = b.showMediaPlayer
        if (b.showUpdateChecker !== undefined) showUpdateChecker = b.showUpdateChecker
        if (b.minWorkspaces !== undefined) minWorkspaces = b.minWorkspaces
        if (b.workspaceStyle !== undefined) workspaceStyle = b.workspaceStyle
        normalizeBarLayout()

        const d = data.dock || {}
        if (d.enabled !== undefined) dockEnabled = d.enabled
        if (d.position !== undefined)
            dockPosition = d.position === "top" ? "bottom" : d.position
        if (d.alignment !== undefined) dockAlignment = d.alignment
        if (d.floating !== undefined) dockFloating = d.floating
        if (d.behavior !== undefined) dockBehavior = d.behavior
        if (d.backgroundStyle !== undefined) dockBackgroundStyle = d.backgroundStyle
        if (d.opacity !== undefined) dockOpacity = d.opacity
        if (d.showBorder !== undefined) dockShowBorder = d.showBorder
        if (d.followHyprland !== undefined) dockFollowHyprland = d.followHyprland
        if (d.shape !== undefined) dockShape = d.shape
        if (d.rounding !== undefined) dockRounding = d.rounding
        if (d.iconSize !== undefined) dockIconSize = d.iconSize
        if (d.spanFullWidth !== undefined) dockSpanFullWidth = d.spanFullWidth
        if (d.showSettingsIcon !== undefined) dockShowSettingsIcon = d.showSettingsIcon
        if (d.showTrashIcon !== undefined) dockShowTrashIcon = d.showTrashIcon
        if (d.pinned !== undefined) dockPinnedApps = d.pinned

        const h = data.hypr || {}
        if (h.rounding !== undefined) hyprRounding = h.rounding
        if (h.showBorder !== undefined) hyprShowBorder = h.showBorder
        if (h.borderSize !== undefined) hyprBorderSize = h.borderSize
        if (h.borderTransparent !== undefined) hyprBorderTransparent = h.borderTransparent
        if (h.borderTransparency !== undefined) hyprBorderTransparency = h.borderTransparency
        if (h.borderFill !== undefined) hyprBorderFill = h.borderFill
        if (h.borderAngle !== undefined) hyprBorderAngle = h.borderAngle
        if (h.borderAnimation !== undefined) hyprBorderAnimation = h.borderAnimation
        if (h.gapsIn !== undefined) hyprGapsIn = h.gapsIn
        if (h.gapsOut !== undefined) hyprGapsOut = h.gapsOut
        if (h.animations !== undefined) hyprAnimations = h.animations
        if (h.shadowPreset !== undefined) hyprShadowPreset = h.shadowPreset
        if (h.shadowRange !== undefined) hyprShadowRange = h.shadowRange
        if (h.shadowAlpha !== undefined) hyprShadowAlpha = h.shadowAlpha
        if (h.shadowUseAccent !== undefined) hyprShadowUseAccent = h.shadowUseAccent
        if (h.blurEnabled !== undefined) hyprBlurEnabled = h.blurEnabled
        if (h.blurSize !== undefined) hyprBlurSize = h.blurSize
        if (h.windowTransparent !== undefined) hyprWindowTransparent = h.windowTransparent
        if (h.windowOpacity !== undefined) hyprWindowOpacity = h.windowOpacity

        const s = data.screenshot || {}
        if (s.saveLocation !== undefined) screenshotDir = s.saveLocation
        if (s.saveToDisk !== undefined) screenshotSaveToDisk = s.saveToDisk
        if (s.copyToClipboard !== undefined) screenshotCopyToClipboard = s.copyToClipboard

        const w = data.wallpaper || {}
        if (w.directory !== undefined) wallpaperDir = w.directory
        if (w.current !== undefined) currentWallpaper = w.current
        if (w.transition !== undefined) wallpaperTransition = w.transition
        if (w.source !== undefined) wallpaperSource = w.source
        if (w.mode !== undefined) wallpaperMode = w.mode
        if (w.slideshowInterval !== undefined) wallpaperSlideshowInterval = w.slideshowInterval

        const c = data.calendar || {}
        if (c.filePath !== undefined) calendarFilePath = c.filePath
        if (c.refreshInterval !== undefined) calendarRefreshInterval = c.refreshInterval
        if (c.weekStart !== undefined) calendarWeekStart = c.weekStart

        const sm = data.sddm || {}
        if (sm.followDesktop !== undefined) sddmFollowDesktop = sm.followDesktop
        if (sm.customWallpaper !== undefined) sddmCustomWallpaper = sm.customWallpaper
        if (sm.blurEnabled !== undefined) sddmBlurEnabled = sm.blurEnabled
        if (sm.blurAmount !== undefined) sddmBlurAmount = sm.blurAmount
        if (sm.loginOpacity !== undefined) sddmLoginOpacity = sm.loginOpacity
    }

    function normalizeBarLayout() {
        // Islands only work as a floating bar; a docked bar is always single.
        if (barStyle === "islands")
            barFloating = true
        else if (!barFloating)
            barStyle = "single"
    }

    function save() {
        normalizeBarLayout()
        settingsFile.setText(JSON.stringify(toObject(), null, 2) + "\n")
    }

    function patch(mutator) {
        mutator(root)
        save()
    }

    function ingest() {
        try {
            const text = settingsFile.text()
            if (text && text.length > 2)
                root.applyObject(JSON.parse(text))
            else if (!root.ready)
                root.save()
        } catch (e) {
            console.log("Settings: parse failed", e)
            if (!root.ready)
                root.save()
        }
        root.ready = true
        root.loaded()
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        // Load before shell windows so toggles bind to saved values, not defaults.
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.ingest()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.save()
            else
                console.log("Settings: load failed", error)
            root.ready = true
            root.loaded()
        }
    }

    Component.onCompleted: settingsFile.text()
}

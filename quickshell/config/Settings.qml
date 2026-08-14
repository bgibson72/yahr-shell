pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string uiFont: "Inter"
    property real widgetOpacity: 1.0
    property bool showWidgetBorders: false
    property int widgetBorderWidth: 1
    property bool blur: true
    property bool clockFormat24hr: false
    property bool showSeconds: false
    property string dateFormat: "MDY"
    property bool dateLong: false
    property bool showDayOfWeek: false

    property string barPosition: "top"
    property string barSize: "small"
    property string barStyle: "single"
    property string barBackgroundStyle: "translucent"
    property real barOpacity: 0.70
    property bool barFloating: false
    property bool barShowBorder: false
    property bool showQuickLaunch: true
    property bool showSystemTray: true
    property bool showMediaPlayer: false
    property int minWorkspaces: 4
    property string workspaceStyle: "dots"

    property bool dockEnabled: true
    property string dockPosition: "bottom"
    property string dockAlignment: "center"
    property bool dockFloating: true
    property string dockBackgroundStyle: "translucent"
    property real dockOpacity: 0.70
    property bool dockShowBorder: false
    property int dockIconSize: 48
    property bool dockSpanFullWidth: false
    property var dockPinnedApps: []

    property int hyprRounding: 12
    property int hyprBorderSize: 3
    property string screenshotDir: "~/Pictures/Screenshots"

    readonly property string settingsPath: `${Quickshell.env("HOME")}/.config/yahr/settings.json`

    function toObject() {
        return {
            general: {
                uiFont: uiFont,
                widgetOpacity: widgetOpacity,
                showWidgetBorders: showWidgetBorders,
                widgetBorderWidth: widgetBorderWidth,
                blur: blur,
                clockFormat24hr: clockFormat24hr,
                showSeconds: showSeconds,
                dateFormat: dateFormat,
                dateLong: dateLong,
                showDayOfWeek: showDayOfWeek
            },
            bar: {
                position: barPosition,
                barSize: barSize,
                barStyle: barStyle,
                backgroundStyle: barBackgroundStyle,
                barOpacity: barOpacity,
                floating: barFloating,
                showBorder: barShowBorder,
                showQuickLaunch: showQuickLaunch,
                showSystemTray: showSystemTray,
                showMediaPlayer: showMediaPlayer,
                minWorkspaces: minWorkspaces,
                workspaceStyle: workspaceStyle
            },
            dock: {
                enabled: dockEnabled,
                position: dockPosition,
                alignment: dockAlignment,
                floating: dockFloating,
                backgroundStyle: dockBackgroundStyle,
                opacity: dockOpacity,
                showBorder: dockShowBorder,
                iconSize: dockIconSize,
                spanFullWidth: dockSpanFullWidth,
                pinned: dockPinnedApps
            },
            hypr: {
                rounding: hyprRounding,
                borderSize: hyprBorderSize
            },
            screenshot: {
                saveLocation: screenshotDir
            }
        }
    }

    function applyObject(data) {
        if (!data)
            return
        const g = data.general || {}
        if (g.uiFont !== undefined) uiFont = g.uiFont
        if (g.widgetOpacity !== undefined) widgetOpacity = g.widgetOpacity
        if (g.showWidgetBorders !== undefined) showWidgetBorders = g.showWidgetBorders
        if (g.widgetBorderWidth !== undefined) widgetBorderWidth = g.widgetBorderWidth
        if (g.blur !== undefined) blur = g.blur
        if (g.clockFormat24hr !== undefined) clockFormat24hr = g.clockFormat24hr
        if (g.showSeconds !== undefined) showSeconds = g.showSeconds
        if (g.dateFormat !== undefined) dateFormat = g.dateFormat
        if (g.dateLong !== undefined) dateLong = g.dateLong
        if (g.showDayOfWeek !== undefined) showDayOfWeek = g.showDayOfWeek

        const b = data.bar || {}
        if (b.position !== undefined) barPosition = b.position
        if (b.barSize !== undefined) barSize = b.barSize
        if (b.barStyle !== undefined) barStyle = b.barStyle
        if (b.backgroundStyle !== undefined) barBackgroundStyle = b.backgroundStyle
        if (b.barOpacity !== undefined) barOpacity = b.barOpacity
        if (b.floating !== undefined) barFloating = b.floating
        if (b.showBorder !== undefined) barShowBorder = b.showBorder
        if (b.showQuickLaunch !== undefined) showQuickLaunch = b.showQuickLaunch
        if (b.showSystemTray !== undefined) showSystemTray = b.showSystemTray
        if (b.showMediaPlayer !== undefined) showMediaPlayer = b.showMediaPlayer
        if (b.minWorkspaces !== undefined) minWorkspaces = b.minWorkspaces
        if (b.workspaceStyle !== undefined) workspaceStyle = b.workspaceStyle

        const d = data.dock || {}
        if (d.enabled !== undefined) dockEnabled = d.enabled
        if (d.position !== undefined) dockPosition = d.position
        if (d.alignment !== undefined) dockAlignment = d.alignment
        if (d.floating !== undefined) dockFloating = d.floating
        if (d.backgroundStyle !== undefined) dockBackgroundStyle = d.backgroundStyle
        if (d.opacity !== undefined) dockOpacity = d.opacity
        if (d.showBorder !== undefined) dockShowBorder = d.showBorder
        if (d.iconSize !== undefined) dockIconSize = d.iconSize
        if (d.spanFullWidth !== undefined) dockSpanFullWidth = d.spanFullWidth
        if (d.pinned !== undefined) dockPinnedApps = d.pinned

        const h = data.hypr || {}
        if (h.rounding !== undefined) hyprRounding = h.rounding
        if (h.borderSize !== undefined) hyprBorderSize = h.borderSize

        const s = data.screenshot || {}
        if (s.saveLocation !== undefined) screenshotDir = s.saveLocation
    }

    function save() {
        settingsFile.setText(JSON.stringify(toObject(), null, 2) + "\n")
    }

    function patch(mutator) {
        mutator(root)
        save()
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const text = settingsFile.text()
                if (text && text.length > 2)
                    root.applyObject(JSON.parse(text))
                else
                    root.save()
            } catch (e) {
                console.log("Settings: parse failed, writing defaults", e)
                root.save()
            }
        }
        onLoadFailed: root.save()
    }
}

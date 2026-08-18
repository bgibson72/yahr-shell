pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string themeId: "catppuccin"
    property string themeName: "Catppuccin"
    property bool custom: false
    property string wallpaperDir: "Catppuccin"

    property color accentRose: "#f5e0dc"
    property color accentCoral: "#f2cdcd"
    property color accentPink: "#f5c2e7"
    property color accentPurple: "#cba6f7"
    property color accentRed: "#f38ba8"
    property color accentMaroon: "#eba0ac"
    property color accentOrange: "#fab387"
    property color accentYellow: "#f9e2af"
    property color accentGreen: "#a6e3a1"
    property color accentTeal: "#94e2d5"
    property color accentCyan: "#89dceb"
    property color accentSapphire: "#74c7ec"
    property color accentBlue: "#89b4fa"
    property color accentLavender: "#b4befe"

    property color fgPrimary: "#cdd6f4"
    property color fgSecondary: "#bac2de"
    property color fgTertiary: "#a6adc8"
    property color border2: "#9399b2"
    property color border1: "#7f849c"
    property color border0: "#6c7086"
    property color surface2: "#585b70"
    property color surface1: "#45475a"
    property color surface0: "#313244"
    property color bgBase: "#1e1e2e"
    property color bgMantle: "#181825"
    property color bgCrust: "#11111b"
    property color glassAccent: "#89b4fa59"

    readonly property color bgBaseAlpha: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, Settings.barOpacity)
    readonly property color panelColor: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, Settings.widgetOpacity)
    readonly property color accentBorder: Qt.rgba(accentBlue.r, accentBlue.g, accentBlue.b, 0.35)

    readonly property int fontSizeSmall: Settings.barSize === "large" ? 14 : 13
    readonly property int fontSizeNormal: Settings.barSize === "large" ? 16 : 15
    readonly property int fontSizeLarge: Settings.barSize === "large" ? 18 : 17
    readonly property int fontSizeIcon: Settings.barSize === "large" ? 22 : 18
    readonly property bool barLarge: Settings.barSize === "large"
    readonly property string uiFont: Settings.uiFont
    readonly property int hyprRounding: Settings.hyprRounding
    readonly property bool hyprShadowEnabled: Settings.hyprShadowEnabled
    readonly property int hyprShadowRange: Settings.hyprShadowRange
    readonly property int hyprShadowAlpha: Settings.hyprShadowAlpha
    readonly property bool hyprShadowUseAccent: Settings.hyprShadowUseAccent
    readonly property bool showWidgetBorders: Settings.showWidgetBorders
    readonly property int widgetBorderWidth: Settings.widgetBorderWidth
    readonly property real widgetOpacity: Settings.widgetOpacity
    readonly property string workspaceStyle: Settings.workspaceStyle

    // Shared "plop" bounce feel used by every clickable icon/button in the shell.
    // Hover/press feedback is a spring-driven scale rather than a background rect.
    // Bare glyph icons (bar/dock/tray/powermenu) get a big, dramatic pop...
    readonly property real iconHoverScale: 1.45
    readonly property real iconPressScale: 0.62
    // ...while labeled buttons/rows with their own background get a more
    // restrained bounce so they don't overlap neighbors in tight layouts.
    readonly property real bounceHoverScale: 1.08
    readonly property real bouncePressScale: 0.9
    readonly property real bounceSpring: 3.0
    readonly property real bounceDamping: 0.28
    readonly property real bounceMass: 0.65

    function applyJson(data) {
        if (!data)
            return
        themeId = data.id || themeId
        themeName = data.name || themeName
        custom = !!data.custom
        wallpaperDir = data.wallpaperDir || wallpaperDir
        const keys = [
            "accentRose", "accentCoral", "accentPink", "accentPurple", "accentRed",
            "accentMaroon", "accentOrange", "accentYellow", "accentGreen", "accentTeal",
            "accentCyan", "accentSapphire", "accentBlue", "accentLavender",
            "fgPrimary", "fgSecondary", "fgTertiary",
            "border2", "border1", "border0", "surface2", "surface1", "surface0",
            "bgBase", "bgMantle", "bgCrust", "glassAccent"
        ]
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            if (data[k])
                root[k] = data[k]
        }
    }

    FileView {
        id: themeFile
        path: `${Quickshell.env("HOME")}/.config/yahr/current.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.applyJson(JSON.parse(themeFile.text()))
            } catch (e) {
                console.log("ThemeManager: failed to parse current.json", e)
            }
        }
    }
}

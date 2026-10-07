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
    // Palette wordmarks live in assets/logos/; custom / unknown palettes
    // fall back to the generic YAHR mark. Light variants share the parent
    // palette's logo (there isn't a separate mark per light/dark pair).
    readonly property url aboutLogoSource: {
        const stem = logoStemForTheme(themeId, custom)
        return `file://${Quickshell.shellDir}/assets/logos/${stem}_logo.png`
    }

    function logoStemForTheme(id, isCustom) {
        if (isCustom)
            return "yahr"
        const t = (id || "").toLowerCase()
        if (t.indexOf("catppuccin") === 0)
            return "catppuccin"
        if (t.indexOf("dracula") === 0)
            return "dracula"
        if (t.indexOf("eldritch") === 0)
            return "eldritch"
        if (t.indexOf("everforest") === 0)
            return "everforest"
        if (t.indexOf("gruvbox") === 0)
            return "gruvbox"
        if (t.indexOf("kanagawa") === 0)
            return "kanagawa"
        if (t.indexOf("monochrome") === 0)
            return "monochrome"
        if (t === "dayfox" || t.indexOf("nightfox") === 0)
            return "nightfox"
        if (t.indexOf("nord") === 0)
            return "nord"
        if (t.indexOf("rose") === 0)
            return "rosepine"
        if (t.indexOf("solarized") === 0)
            return "solarized"
        if (t.indexOf("tokyo") === 0)
            return "tokyonight"
        return "yahr"
    }

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
    readonly property bool widgetGlass: !Settings.followHyprlandRules && Settings.widgetTransparent
    readonly property real glassOpacity: Settings.widgetOpacity
    readonly property color panelColor: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, widgetGlass ? glassOpacity : 1.0)
    // Placeholder copy in text fields: light on dark palettes, dark on light.
    readonly property bool isLightTheme: (0.2126 * bgBase.r + 0.7152 * bgBase.g + 0.0722 * bgBase.b) > 0.5
    // Dark-mode cards/pills/hovers used a white wash. On a light bgBase that
    // wash disappears, so lift with black on light palettes and white on dark.
    function overlay(alpha) {
        return isLightTheme ? Qt.rgba(0, 0, 0, alpha) : Qt.rgba(1, 1, 1, alpha)
    }
    readonly property color chromeColor: isLightTheme
        ? Qt.rgba(0, 0, 0, widgetGlass ? Math.min(0.18, Math.max(0.10, glassOpacity * 0.22)) : 0.10)
        : Qt.rgba(surface0.r, surface0.g, surface0.b, widgetGlass ? Math.min(1.0, glassOpacity + 0.22) : 1.0)
    readonly property color cardColor: isLightTheme
        ? Qt.rgba(0, 0, 0, widgetGlass ? Math.min(0.14, Math.max(0.08, glassOpacity * 0.18)) : 0.08)
        : Qt.rgba(surface0.r, surface0.g, surface0.b, widgetGlass ? Math.min(1.0, glassOpacity + 0.12) : 1.0)
    // Glassy chip/input outline. Widget/bar/dock frames use chromeBorderColor
    // so they track Hyprland's solid/gradient + opacity settings.
    readonly property color accentBorder: Qt.rgba(accentBlue.r, accentBlue.g, accentBlue.b, 0.35)
    readonly property real hyprBorderOpacity: Settings.hyprBorderTransparent
        ? Math.max(0, Math.min(1, (100 - Settings.hyprBorderTransparency) / 100))
        : 1.0
    // Rectangle.border can't paint Hyprland's 3-stop gradient, so gradient
    // mode uses the accent stop's alpha (35% of the overall opacity scale).
    readonly property real chromeBorderOpacity: Settings.hyprBorderFill === "gradient"
        ? 0.35 * hyprBorderOpacity
        : hyprBorderOpacity
    readonly property color chromeBorderColor: Qt.rgba(accentBlue.r, accentBlue.g, accentBlue.b, chromeBorderOpacity)
    // Icon-group and clock pills on the bar match Settings section cards
    // so they sit on the bar fill without disappearing on light palettes.
    readonly property color barPillColor: cardColor
    readonly property color placeholderColor: Qt.rgba(fgPrimary.r, fgPrimary.g, fgPrimary.b, isLightTheme ? 0.48 : 0.58)
    readonly property string terminal: "ghostty"

    readonly property int fontSizeSmall: Settings.barSize === "large" ? 14 : 13
    readonly property int fontSizeNormal: Settings.barSize === "large" ? 16 : 15
    readonly property int fontSizeLarge: Settings.barSize === "large" ? 18 : 17
    readonly property int fontSizeIcon: Settings.barSize === "large" ? 22 : 18
    // Font Awesome glyphs (nf-fa, used by the quicklaunch icons and the
    // updater's refresh icon) fill more of their em box than the Material
    // Design Icon glyphs (nf-md, used by the other system-status icons) at
    // the same pixel size, so they're scaled down to read as visually equal.
    readonly property int fontSizeIconFA: Math.round(fontSizeIcon * 0.75)
    readonly property bool barLarge: Settings.barSize === "large"
    readonly property var uiFontCatalog: [
        { key: "Inter", label: "Inter", families: ["Inter", "Inter Variable"] },
        { key: "Source Sans", label: "Source Sans", families: ["Source Sans 3", "Source Sans Variable", "Source Sans 3 VF", "Source Sans Pro"] },
        { key: "Roboto", label: "Roboto / Roboto Flex", families: ["Roboto Flex", "Roboto"] },
        { key: "Manrope", label: "Manrope", families: ["Manrope"] },
        { key: "Overpass", label: "Overpass", families: ["Overpass", "Overpass Nerd Font"] },
        { key: "Space Grotesk", label: "Space Grotesk", families: ["Space Grotesk"] },
        { key: "IBM Plex Sans", label: "IBM Plex Sans", families: ["IBM Plex Sans Var", "IBM Plex Sans"] }
    ]
    property string uiFont: "Inter"
    readonly property int hyprRounding: Settings.hyprRounding
    readonly property bool hyprShadowEnabled: Settings.hyprShadowPreset !== "off"
    readonly property int hyprShadowRange: Settings.hyprShadowRange
    readonly property int hyprShadowAlpha: Settings.hyprShadowAlpha
    readonly property bool hyprShadowUseAccent: Settings.hyprShadowUseAccent
    readonly property bool followHyprlandRules: Settings.followHyprlandRules
    readonly property int cardRadius: followHyprlandRules ? Math.max(6, hyprRounding - 4) : 12

    // The bar's own visual/reserved height. Kept separate from the bar
    // window's actual surface height (barWindowHeight).
    readonly property int barHeight: Settings.barSize === "large" ? 58 : 48
    // Same size whether the bar is floating or joined to the frame.
    readonly property int archIconSize: Math.max(22, barHeight - 10)
    // Extra window height only if the icon is ever larger than the pill.
    readonly property real barPillOffset: Math.max(0, (archIconSize - barHeight) / 2)
    readonly property real barPillTopMargin: Settings.barFloating ? barPillOffset : 0
    readonly property int barWindowHeight: useFrameEmerge ? barHeight : Math.max(barHeight, archIconSize + 8)
    // Inset used when the bar is floating. Shared with the layer-shell
    // window margins so the reserved exclusive zone matches the visual gap.
    readonly property int barFloatingEdgeGap: 6
    readonly property int barFloatingSideGap: 8
    // Solid + docked bar: draw a screen bezel and clip-reveal widgets out of
    // it. Islands (any float/dock) and a floating solid bar keep the elastic pop.
    property bool hideScreenFrame: false
    readonly property bool useFrameEmerge: Settings.barStyle === "single" && !Settings.barFloating
    readonly property bool emergeFromBottom: useFrameEmerge && Settings.barPosition === "bottom"
    readonly property int frameThickness: Math.max(10, Settings.hyprGapsOut)
    // Breathing room between the inner hole and tiled windows.
    readonly property int frameContentGap: 8
    readonly property int frameEdgeInset: useFrameEmerge ? frameThickness : 0
    readonly property int frameInnerRadius: Settings.hyprRounding
    readonly property bool useFrameDock: useFrameEmerge && Settings.dockEnabled && !Settings.dockFloating
    readonly property bool frameDockSpansEdge: useFrameDock && Settings.dockSpanFullWidth
    readonly property int dockChromeSize: Settings.dockIconSize + 20
    readonly property int effectiveWindowRounding: useFrameEmerge ? frameInnerRadius : Settings.hyprRounding
    readonly property color frameFillColor: {
        const a = (barFollowHyprland || Settings.barBackgroundStyle === "opaque")
            ? 1
            : Math.max(0.92, Settings.barOpacity)
        return Qt.rgba(bgBase.r, bgBase.g, bgBase.b, a)
    }
    // How much screen space Hyprland should keep clear for the bar.
    // Windows sit just `gaps_out` below the visible pill — floating or
    // docked. Floating adds the edge gap so the reservation tracks the
    // pill's true bottom edge.
    readonly property int barExclusiveZone: Math.round(barHeight + barPillTopMargin + (Settings.barFloating ? barFloatingEdgeGap : 0))
    readonly property int panelTopMargin: useFrameEmerge
        ? Math.max(0, barExclusiveZone - 2)
        : Math.round((Settings.barFloating ? 6 : 0) + barPillTopMargin + barHeight + 8)
    readonly property int panelLeftMargin: useFrameEmerge ? Math.max(0, frameThickness - 2) : (Settings.barFloating ? 14 : 10)
    readonly property int panelRightMargin: useFrameEmerge ? Math.max(0, frameThickness - 2) : 16
    readonly property int panelBottomMargin: useFrameEmerge
        ? (emergeFromBottom ? Math.max(0, barExclusiveZone - 2) : Math.max(0, frameThickness - 2))
        : 24

    function overlayAttachedY(hostHeight, panelHeight) {
        if (emergeFromBottom)
            return hostHeight - panelHeight - barExclusiveZone
        return panelTopMargin
    }

    function overlayBottomY(hostHeight, panelHeight) {
        return hostHeight - panelHeight - panelBottomMargin
    }

    function overlayMidY(hostHeight, panelHeight) {
        if (useFrameEmerge) {
            const top = emergeFromBottom ? frameThickness : barExclusiveZone
            const bot = emergeFromBottom ? barExclusiveZone : frameThickness
            return top + (hostHeight - top - bot - panelHeight) / 2
        }
        return (hostHeight - panelHeight) / 2
    }

    function overlayCenteredY(hostHeight, panelHeight) {
        if (useFrameEmerge)
            return overlayAttachedY(hostHeight, panelHeight)
        return (hostHeight - panelHeight) / 2
    }
    // Arch mark sits flush in the bar corner, so its hover pop stays milder
    // than tray/power glyphs — just enough to read as interactive.
    readonly property real archIconHoverScale: 1.22
    readonly property real archIconPressScale: 0.94
    readonly property bool showWidgetBorders: Settings.followHyprlandRules
        ? Settings.hyprShowBorder
        : Settings.showWidgetBorders
    // Widget chrome uses the same thickness as Hyprland window borders so
    // the two stay visually in lockstep when either side's picker is used.
    readonly property int widgetBorderWidth: Settings.hyprBorderSize
    readonly property real widgetOpacity: Settings.widgetOpacity
    readonly property string workspaceStyle: Settings.workspaceStyle
    readonly property bool barFollowHyprland: Settings.barFollowHyprland
    readonly property bool effectiveBarShowBorder: barFollowHyprland
        ? Settings.hyprShowBorder
        : Settings.barShowBorder
    readonly property int effectiveBarBorderWidth: Settings.hyprBorderSize
    // Docked frame-emerge bars stay square against the screen edge. Floating
    // single/island bars use an independent radius, or Hyprland's rounding.
    readonly property int barRadius: {
        if (useFrameEmerge)
            return 0
        const requested = Settings.barRoundingFollowHyprland
            ? Settings.hyprRounding
            : Settings.barRounding
        return Math.max(0, Math.min(requested, Math.floor(barHeight / 2)))
    }
    readonly property color barFillColor: {
        if (barFollowHyprland || Settings.barBackgroundStyle === "opaque")
            return bgBase
        if (Settings.barBackgroundStyle === "transparent")
            return Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0)
        return Qt.rgba(bgBase.r, bgBase.g, bgBase.b, Settings.barOpacity)
    }
    readonly property bool dockFollowHyprland: Settings.dockFollowHyprland
    readonly property bool effectiveDockShowBorder: dockFollowHyprland
        ? Settings.hyprShowBorder
        : Settings.dockShowBorder
    readonly property int effectiveDockBorderWidth: Settings.hyprBorderSize
    readonly property color dockFillColor: {
        if (dockFollowHyprland || Settings.dockBackgroundStyle === "opaque")
            return bgBase
        if (Settings.dockBackgroundStyle === "transparent")
            return Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0)
        return Qt.rgba(bgBase.r, bgBase.g, bgBase.b, Settings.dockOpacity)
    }
    readonly property int dockRadius: Settings.dockShape === "rounded" ? Settings.dockRounding : 0

    // Shared "plop" bounce feel used by every clickable icon/button in the shell.
    // Hover/press feedback is a spring-driven scale rather than a background rect.
    // Bare glyph icons (bar/dock/tray/powermenu) get a big, dramatic pop...
    readonly property real iconHoverScale: 1.45
    readonly property real iconPressScale: 0.62
    // ...labeled bar pills (TOOLS, clock) grow as one unit with a soft pop —
    // wide chrome reads exaggerated if it uses the glyph-sized scale.
    readonly property real barLabelHoverScale: 1.12
    readonly property real barLabelPressScale: 0.94
    // ...while panel buttons/rows with their own background get a more
    // restrained bounce so they don't overlap neighbors in tight layouts.
    readonly property real bounceHoverScale: 1.08
    readonly property real bouncePressScale: 0.9
    readonly property real bounceSpring: 3.0
    readonly property real bounceDamping: 0.28
    readonly property real bounceMass: 0.65

    function listHas(list, name) {
        if (!list)
            return false
        for (let i = 0; i < list.length; i++) {
            if (list[i] === name)
                return true
        }
        return false
    }

    function matchFamily(installed, name) {
        if (listHas(installed, name))
            return name
        if (!installed)
            return ""
        let best = ""
        for (let i = 0; i < installed.length; i++) {
            const fam = installed[i]
            if (fam === name)
                return fam
            if (fam.indexOf(name + " ") === 0 && (!best || fam.length < best.length))
                best = fam
        }
        return best
    }

    function resolveUiFont(stored) {
        const wanted = stored || "Inter"
        const catalog = uiFontCatalog
        let families = [wanted]
        for (let i = 0; i < catalog.length; i++) {
            const item = catalog[i]
            if (item.key === wanted || listHas(item.families, wanted)) {
                families = item.families
                break
            }
        }
        const installed = Qt.fontFamilies()
        for (let j = 0; j < families.length; j++) {
            const found = matchFamily(installed, families[j])
            if (found)
                return found
        }
        return families[0]
    }

    function syncUiFont() {
        uiFont = resolveUiFont(Settings.uiFont)
        syncMako()
    }

    function syncMako() {
        Quickshell.execDetached(["python3", `${Quickshell.shellDir}/scripts/sync-mako.py`])
    }

    Connections {
        target: Settings
        function onUiFontChanged() { root.syncUiFont() }
        function onHyprGapsOutChanged() { root.applyHyprWorkspaceLayout() }
        function onHyprRoundingChanged() { root.applyHyprWorkspaceLayout(); root.syncMako() }
        function onHyprShowBorderChanged() { root.syncMako() }
        function onHyprBorderSizeChanged() { root.syncMako() }
        function onHyprBorderTransparentChanged() { root.syncMako() }
        function onHyprBorderTransparencyChanged() { root.syncMako() }
        function onHyprBorderFillChanged() { root.syncMako() }
        function onHyprBlurEnabledChanged() { root.syncMako() }
        function onLoaded() {
            root.syncUiFont()
            root.applyHyprWorkspaceLayout()
            root.syncMako()
        }
        function onBarStyleChanged() { root.applyHyprWorkspaceLayout() }
        function onBarFloatingChanged() { root.applyHyprWorkspaceLayout() }
        function onBarPositionChanged() { root.applyHyprWorkspaceLayout() }
        function onDockEnabledChanged() { root.applyHyprWorkspaceLayout() }
        function onDockFloatingChanged() { root.applyHyprWorkspaceLayout() }
        function onDockPositionChanged() { root.applyHyprWorkspaceLayout() }
        function onDockSpanFullWidthChanged() { root.applyHyprWorkspaceLayout() }
        function onDockIconSizeChanged() { root.applyHyprWorkspaceLayout() }
    }

    Component.onCompleted: {
        syncUiFont()
        if (Settings.ready)
            applyHyprWorkspaceLayout()
    }

    // Keep tiled windows inside the picture-frame hole: outer gaps are the
    // bezel plus a small inner pad, and window rounding matches the inner
    // corners. The bar's exclusive zone is the hole's top edge, so that
    // side only needs the inner pad.
    function applyHyprWorkspaceLayout() {
        const t = frameThickness
        const g = frameContentGap
        const r = effectiveWindowRounding
        let gaps
        if (useFrameEmerge) {
            let top = emergeFromBottom ? t + g : g
            let right = t + g
            let bottom = emergeFromBottom ? g : t + g
            let left = t + g
            if (frameDockSpansEdge) {
                if (Settings.dockPosition === "bottom")
                    bottom = g
                else if (Settings.dockPosition === "left")
                    left = g
                else if (Settings.dockPosition === "right")
                    right = g
                else if (Settings.dockPosition === "top")
                    top = g
            }
            gaps = `{top=${top},right=${right},bottom=${bottom},left=${left}}`
        } else {
            gaps = `${Settings.hyprGapsOut}`
        }
        Quickshell.execDetached([
            "hyprctl", "eval",
            `hl.config({general={gaps_out=${gaps}},decoration={rounding=${r}}})`
        ])
    }

    function mixBlack(src, amount) {
        const a = Math.max(0, Math.min(1, amount))
        return Qt.rgba(src.r * (1 - a), src.g * (1 - a), src.b * (1 - a), 1)
    }

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
        // Bundled light palettes keep Catppuccin's "elevate by lightening"
        // surfaces, which sit on top of an already-light bgBase and vanish.
        // Darken them against the background so chips, rows, and sliders
        // keep the same contrast they have in dark mode.
        if (isLightTheme) {
            surface0 = mixBlack(bgBase, 0.07)
            surface1 = mixBlack(bgBase, 0.12)
            surface2 = mixBlack(bgBase, 0.18)
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

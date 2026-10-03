import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../components"
import "../.."

// =============================================================================
// WallpaperPicker — Morphing Island swatch grid
//
// Two fluid states share one chrome "island":
//   swatches  → palette cards with accent capsules
//   carousel  → horizontal wallpaper thumbs for the chosen palette
//
// A live Hyprland desktop mock (~28% of the island) mirrors colBg / colFg /
// colAccent as the pointer moves, so the user sees the theme before applying.
// Wallpaper entries are a mocked JSON-cache model (no directory scans in QML).
// =============================================================================
Panel {
    id: root
    width: 980
    height: 640
    floatCenter: true
    slideOffsetY: 0
    entranceScale: 0.92

    // ── State logic ──────────────────────────────────────────────────────────
    property int selectedPaletteIndex: -1
    property string selectedWallpaperPath: ""
    property string hoveredWallpaperPath: ""

    // Live preview hexes driven by hover / selection (not ThemeManager)
    property color colBg: "#1e1e2e"
    property color colFg: "#cdd6f4"
    property color colAccent: "#cba6f7"
    property color colSurface: "#313244"
    property color colMantle: "#181825"
    property color colBorder: "#45475a"

    readonly property bool inCarousel: selectedPaletteIndex >= 0
    readonly property var activePalette: inCarousel ? palettes[selectedPaletteIndex] : null

    signal requestClose()
    signal wallpaperApplied(string path)

    focus: true
    Keys.onEscapePressed: {
        if (root.inCarousel)
            root.backToThemes()
        else
            root.requestClose()
    }

    onIsVisibleChanged: {
        if (isVisible) {
            root.selectedPaletteIndex = -1
            root.hoveredWallpaperPath = ""
            root.selectedWallpaperPath = Settings.currentWallpaper || ""
            root.applyPreviewFromPalette(root.palettes[0])
        }
    }

    // Simulated parse of a wallpaper-cache JSON (palette → accent + paths).
    // Paths resolve under ~/Pictures/Wallpapers/<folder>/; Image fails soft
    // if a file is absent so the UI never blocks on I/O.
    readonly property var palettes: [
        {
            id: "catppuccin",
            name: "Catppuccin Mocha",
            folder: "Catppuccin",
            accent: "#cba6f7",
            accents: ["#cba6f7", "#89b4fa", "#f5c2e7", "#a6e3a1", "#fab387", "#f38ba8"],
            colBg: "#1e1e2e", colMantle: "#181825", colSurface: "#313244",
            colFg: "#cdd6f4", colBorder: "#45475a",
            wallpapers: ["abstract.png", "astronaut-2.png", "buildings.png", "car-2.png", "delorean.png", "quasar.png"]
        },
        {
            id: "dracula",
            name: "Dracula",
            folder: "Dracula",
            accent: "#bd93f9",
            accents: ["#bd93f9", "#ff79c6", "#8be9fd", "#50fa7b", "#ffb86c", "#ff5555"],
            colBg: "#282a36", colMantle: "#21222c", colSurface: "#44475a",
            colFg: "#f8f8f2", colBorder: "#6272a4",
            wallpapers: ["arch.png", "Dracula.png", "dracula-galaxy-bd93f9.png", "dracula-leaves-44475a.png", "dracula-mnt-bd93f9.png", "dracula-soft-waves-6272a4.png"]
        },
        {
            id: "everforest",
            name: "Everforest",
            folder: "Everforest",
            accent: "#a7c080",
            accents: ["#a7c080", "#7fbbb3", "#d3869b", "#e67e80", "#dbbc7f", "#e69875"],
            colBg: "#2b3339", colMantle: "#272e33", colSurface: "#374247",
            colFg: "#d3c6aa", colBorder: "#3d484d",
            wallpapers: ["1-everforest.jpg", "car_rain.png", "forest_stairs.jpg", "japanese_pedestrian_street.png", "08. Greenify.jpg", "10. Greenify.jpg"]
        },
        {
            id: "nord",
            name: "Nord",
            folder: "Nord",
            accent: "#81a1c1",
            accents: ["#81a1c1", "#88c0d0", "#b48ead", "#a3be8c", "#ebcb8b", "#bf616a"],
            colBg: "#2e3440", colMantle: "#3b4252", colSurface: "#434c5e",
            colFg: "#eceff4", colBorder: "#4c566a",
            wallpapers: ["archlinux.png", "BirdNord.png", "container_ship.png", "cpu_city.png", "ign_city.png", "4s62fcy37st61.jpg"]
        },
        {
            id: "gruvbox",
            name: "Gruvbox",
            folder: "Gruvbox",
            accent: "#fe8019",
            accents: ["#fe8019", "#b8bb26", "#83a598", "#d3869b", "#fabd2f", "#fb4934"],
            colBg: "#282828", colMantle: "#1d2021", colSurface: "#3c3836",
            colFg: "#ebdbb2", colBorder: "#504945",
            wallpapers: ["brown_city_planet_w.jpg", "bulbs.jpg", "cabin.png", "Mandalorian.jpg", "sushi.jpg", "wallhaven-3lmz2d.jpg"]
        },
        {
            id: "tokyo-night",
            name: "Tokyo Night",
            folder: "TokyoNight",
            accent: "#7aa2f7",
            accents: ["#7aa2f7", "#bb9af7", "#7dcfff", "#9ece6a", "#e0af68", "#f7768e"],
            colBg: "#1a1b26", colMantle: "#16161e", colSurface: "#24283b",
            colFg: "#c0caf5", colBorder: "#414868",
            wallpapers: ["tokyo-night-pictures-37v7l5txrsfmsp8e.jpg", "wallhaven-2e8m5x.jpg", "wallhaven-43pvkd.jpg", "wallhaven-je8xk5.jpg", "wallhaven-8x72lk.jpg", "wallhaven-jxjm1m.png"]
        },
        {
            id: "rose-pine",
            name: "Rosé Pine",
            folder: "RosePine",
            accent: "#c4a7e7",
            accents: ["#c4a7e7", "#ebbcba", "#9ccfd8", "#31748f", "#f6c177", "#eb6f92"],
            colBg: "#191724", colMantle: "#1f1d2e", colSurface: "#26233a",
            colFg: "#e0def4", colBorder: "#403d52",
            wallpapers: ["07. Rosé Pine.png", "Arch_moon.png", "river.jpg", "through_the_branches.jpg", "blockwavemoon.png", "19. Rosé Pine.jpeg"]
        },
        {
            id: "kanagawa",
            name: "Kanagawa",
            folder: "Kanagawa",
            accent: "#7e9cd8",
            accents: ["#7e9cd8", "#957fb8", "#7aa89f", "#98bb6c", "#e6c384", "#ff5d62"],
            colBg: "#1f1f28", colMantle: "#16161d", colSurface: "#2a2a37",
            colFg: "#dcd7ba", colBorder: "#363646",
            wallpapers: ["1-kanagawa.jpg", "wallhaven-01orpv.jpg", "wallhaven-0poygm.jpg", "wallhaven-4lqvly.jpg", "256195-1920x1080-desktop-full-hd-great-wave-off-kanagawa-wallpaper-photo.jpg"]
        }
    ]

    function wallpaperRoot() {
        const home = Quickshell.env("HOME") || ""
        return `${home}/Pictures/Wallpapers`
    }

    function wallpaperPath(folder, fileName) {
        return `${root.wallpaperRoot()}/${folder}/${fileName}`
    }

    function wallpaperUrl(folder, fileName) {
        const p = root.wallpaperPath(folder, fileName)
        return "file://" + p.split("/").map(encodeURIComponent).join("/")
    }

    function applyPreviewFromPalette(p) {
        if (!p)
            return
        root.colBg = p.colBg
        root.colMantle = p.colMantle
        root.colSurface = p.colSurface
        root.colFg = p.colFg
        root.colAccent = p.accent
        root.colBorder = p.colBorder
    }

    function openPalette(index) {
        if (index < 0 || index >= root.palettes.length)
            return
        root.selectedPaletteIndex = index
        root.applyPreviewFromPalette(root.palettes[index])
        root.hoveredWallpaperPath = ""
    }

    function backToThemes() {
        root.selectedPaletteIndex = -1
        root.hoveredWallpaperPath = ""
        root.applyPreviewFromPalette(root.palettes[0])
    }

    function applyWallpaper(path) {
        if (!path)
            return
        root.selectedWallpaperPath = path
        Settings.currentWallpaper = path
        Settings.save()
        Quickshell.execDetached([
            "python3",
            `${Quickshell.shellDir}/scripts/set-wallpaper.py`,
            path,
            Settings.wallpaperTransition
        ])
        root.wallpaperApplied(path)
    }

    // ── Visual layout ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Wallpaper"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            // Back control — only meaningful in carousel state
            Rectangle {
                id: backBtn
                visible: root.inCarousel
                opacity: root.inCarousel ? 1 : 0
                implicitWidth: backRow.implicitWidth + 24
                implicitHeight: 32
                radius: 8
                color: backHover.hovered ? ThemeManager.surface1 : ThemeManager.surface0
                border.width: 1
                border.color: ThemeManager.overlay(0.12)

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: backRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "\uf060"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: ThemeManager.fgSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Back to Themes"
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: ThemeManager.fgPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler {
                    id: backHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.backToThemes()
                }
            }

            Rectangle {
                id: closeBtn
                implicitWidth: 32
                implicitHeight: 32
                radius: 8
                color: closeHover.hovered ? ThemeManager.surface1 : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: ThemeManager.fgSecondary
                }

                HoverHandler {
                    id: closeHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.requestClose()
                }
            }
        }

        // Body: live mock (left) + morphing island (right)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // ── Live Hyprland desktop mock-up (~28%) ─────────────────────────
            DesktopMock {
                id: desktopMock
                Layout.preferredWidth: Math.round(root.width * 0.28)
                Layout.fillHeight: true
                Layout.minimumWidth: 240
            }

            // ── Morphing Island ──────────────────────────────────────────────
            Item {
                id: island
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                state: root.inCarousel ? "carousel" : "swatches"

                // State 1 — palette swatch grid
                SwatchGrid {
                    id: swatchGrid
                    anchors.fill: parent
                    opacity: 1
                    scale: 1
                    transformOrigin: Item.Center
                }

                // State 2 — wallpaper carousel for the selected palette
                CarouselView {
                    id: carouselView
                    anchors.fill: parent
                    opacity: 0
                    scale: 0.92
                    transformOrigin: Item.Center
                    enabled: root.inCarousel
                }

                states: [
                    State {
                        name: "swatches"
                        PropertyChanges { target: swatchGrid; opacity: 1; scale: 1 }
                        PropertyChanges { target: carouselView; opacity: 0; scale: 0.92 }
                    },
                    State {
                        name: "carousel"
                        PropertyChanges { target: swatchGrid; opacity: 0; scale: 0.9 }
                        PropertyChanges { target: carouselView; opacity: 1; scale: 1 }
                    }
                ]

                transitions: [
                    Transition {
                        from: "swatches"; to: "carousel"
                        ParallelAnimation {
                            NumberAnimation {
                                targets: [swatchGrid, carouselView]
                                properties: "opacity,scale"
                                duration: 320
                                easing.type: Easing.InOutQuad
                            }
                        }
                    },
                    Transition {
                        from: "carousel"; to: "swatches"
                        ParallelAnimation {
                            NumberAnimation {
                                targets: [swatchGrid, carouselView]
                                properties: "opacity,scale"
                                duration: 280
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                ]
            }
        }
    }

    // =========================================================================
    // Nested visual components (presentation only — state lives on `root`)
    // =========================================================================

    component DesktopMock: Rectangle {
        id: mock
        radius: 14
        color: root.colMantle
        border.width: 1
        border.color: ThemeManager.overlay(0.10)
        clip: true

        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutQuad } }

        // Wallpaper plane
        Image {
            id: mockWall
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            source: {
                const p = root.hoveredWallpaperPath || root.selectedWallpaperPath
                if (!p)
                    return ""
                return "file://" + p.split("/").map(encodeURIComponent).join("/")
            }
            opacity: status === Image.Ready ? 0.55 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        // Soft tint over wallpaper so chrome stays readable
        Rectangle {
            anchors.fill: parent
            color: root.colBg
            opacity: mockWall.status === Image.Ready ? 0.35 : 0.92
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                text: "Preview"
                color: root.colFg
                opacity: 0.7
                font.family: ThemeManager.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            // Mini status bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                radius: 6
                color: root.colSurface
                border.width: 1
                border.color: root.colBorder
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Repeater {
                        model: 3
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: index === 0 ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.35)
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 28
                        height: 8
                        radius: 3
                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.35)
                    }
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 3
                        color: root.colAccent
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }
            }

            // Floating "window" with accent border
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: root.colBg
                border.width: 2
                border.color: root.colAccent
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                // Title bar strip
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 18
                    radius: 10
                    color: root.colSurface
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 10
                        color: parent.color
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        spacing: 4
                        Repeater {
                            model: [root.colAccent, "#f38ba8", "#a6e3a1"]
                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: modelData
                                opacity: index === 0 ? 1 : 0.55
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 8
                    spacing: 6
                    width: parent.width - 28

                    Rectangle {
                        width: parent.width * 0.7
                        height: 8
                        radius: 3
                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.55)
                    }
                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.28)
                    }
                    Rectangle {
                        width: parent.width * 0.85
                        height: 6
                        radius: 3
                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.22)
                    }
                    Rectangle {
                        width: 64
                        height: 18
                        radius: 5
                        color: root.colAccent
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Accent"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: root.colBg
                        }
                    }
                }
            }

            // Hex readout
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: [
                        { label: "bg", value: root.colBg },
                        { label: "fg", value: root.colFg },
                        { label: "accent", value: root.colAccent }
                    ]
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 3
                            color: modelData.value
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        Text {
                            text: modelData.label
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 10
                            Layout.preferredWidth: 42
                        }
                        Text {
                            text: String(modelData.value)
                            color: ThemeManager.fgSecondary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 10
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    component SwatchGrid: Flickable {
        id: gridFlick
        contentWidth: width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: opacity > 0.5

        GridLayout {
            id: grid
            width: gridFlick.width
            columns: 2
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: root.palettes

                Rectangle {
                    id: card
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 118
                    radius: 14
                    color: ThemeManager.surface0
                    border.width: cardHover.hovered ? 2 : 1
                    border.color: cardHover.hovered ? card.modelData.accent : ThemeManager.overlay(0.10)

                    scale: cardTap.pressed ? 0.97 : (cardHover.hovered ? 1.02 : 1.0)
                    Behavior on scale {
                        SpringAnimation {
                            spring: ThemeManager.bounceSpring
                            damping: ThemeManager.bounceDamping
                            mass: ThemeManager.bounceMass
                        }
                    }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    // Soft accent wash on hover
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: card.modelData.accent
                        opacity: cardHover.hovered ? 0.10 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: card.modelData.name
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Accent capsules
                        Row {
                            spacing: 6
                            Repeater {
                                model: card.modelData.accents
                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: modelData
                                    border.width: 1
                                    border.color: ThemeManager.overlay(0.18)
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            text: `${card.modelData.wallpapers.length} wallpapers`
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                        }
                    }

                    HoverHandler {
                        id: cardHover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered && !root.inCarousel)
                                root.applyPreviewFromPalette(card.modelData)
                        }
                    }
                    TapHandler {
                        id: cardTap
                        onTapped: root.openPalette(card.index)
                    }
                }
            }
        }
    }

    component CarouselView: ColumnLayout {
        id: carousel
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.activePalette ? root.activePalette.name : ""
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: root.activePalette ? root.activePalette.accent : "transparent"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.activePalette
                    ? `${root.activePalette.wallpapers.length} in palette`
                    : ""
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 11
            }
        }

        ListView {
            id: strip
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 14
            clip: true
            boundsBehavior: Flickable.DragOverBounds
            snapMode: ListView.SnapToItem
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width * 0.08
            preferredHighlightEnd: width * 0.92
            cacheBuffer: 512
            model: root.activePalette ? root.activePalette.wallpapers : []

            delegate: WallpaperThumb {
                required property string modelData
                required property int index
                folder: root.activePalette ? root.activePalette.folder : ""
                fileName: modelData
                accent: root.activePalette ? root.activePalette.accent : "#cba6f7"
                absolutePath: root.wallpaperPath(folder, fileName)
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Hover to preview · tap to apply"
            color: ThemeManager.fgTertiary
            font.family: ThemeManager.uiFont
            font.pixelSize: 11
            opacity: 0.85
        }
    }

    component WallpaperThumb: Item {
        id: thumb
        property string folder: ""
        property string fileName: ""
        property color accent: "#cba6f7"
        property string absolutePath: ""

        readonly property bool isSelected: root.selectedWallpaperPath === absolutePath
        readonly property bool isHot: thumbHover.hovered || isSelected

        width: 220
        height: ListView.view ? ListView.view.height - 8 : 280

        scale: thumbTap.pressed ? 0.97 : (thumbHover.hovered ? 1.03 : 1.0)
        Behavior on scale {
            SpringAnimation {
                spring: ThemeManager.bounceSpring
                damping: ThemeManager.bounceDamping
                mass: ThemeManager.bounceMass
            }
        }

        // Glow plate — MultiEffect tinted to palette accent
        Rectangle {
            id: glowPlate
            anchors.fill: frame
            anchors.margins: -2
            radius: 14
            color: "transparent"
            opacity: thumb.isHot ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            layer.enabled: thumb.isHot
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(thumb.accent.r, thumb.accent.g, thumb.accent.b, thumb.isSelected ? 0.85 : 0.55)
                shadowBlur: thumb.isSelected ? 0.85 : 0.55
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        Rectangle {
            id: frame
            anchors.fill: parent
            anchors.margins: 4
            radius: 12
            color: ThemeManager.surface0
            border.width: thumb.isHot ? 2 : 1
            border.color: thumb.isHot ? thumb.accent : ThemeManager.overlay(0.10)
            clip: true

            Behavior on border.color { ColorAnimation { duration: 140 } }

            // Pulsing ring for the active (applied) wallpaper
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: thumb.accent
                visible: thumb.isSelected
                opacity: 0.35

                SequentialAnimation on opacity {
                    running: thumb.isSelected
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.35; to: 0.95; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.95; to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                }
            }

            Image {
                anchors.fill: parent
                anchors.margins: 3
                source: root.wallpaperUrl(thumb.folder, thumb.fileName)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 440
                sourceSize.height: 280
            }

            // Filename caption
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 28
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    text: thumb.fileName
                    color: "#ffffff"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                }
            }
        }

        HoverHandler {
            id: thumbHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered) {
                    root.hoveredWallpaperPath = thumb.absolutePath
                    if (root.activePalette)
                        root.applyPreviewFromPalette(root.activePalette)
                } else if (root.hoveredWallpaperPath === thumb.absolutePath) {
                    root.hoveredWallpaperPath = ""
                }
            }
        }
        TapHandler {
            id: thumbTap
            onTapped: root.applyWallpaper(thumb.absolutePath)
        }
    }
}

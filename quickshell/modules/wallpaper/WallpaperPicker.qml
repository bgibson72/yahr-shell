import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import "../.."

// =============================================================================
// WallpaperPicker — full-screen Morphing Island overlay
//
// Not a confined dialog: a dimmed scrim + near-fullscreen content plane.
//   swatches  → palette cards with accent capsules
//   carousel  → horizontal wallpaper strip with arrow / wheel paging
//
// Preview is wallpaper-first; a slim bar + corner chrome sample theme colors
// without burying the image. Wallpaper data is a mocked JSON-cache model.
// =============================================================================
Item {
    id: root

    // Host fills the PanelWindow; content uses most of the screen with margins.
    anchors.fill: parent

    property bool isVisible: false
    property real entrance: isVisible ? 1 : 0
    readonly property bool onScreen: isVisible || entrance > 0.02
    readonly property int chromeRadius: 0
    readonly property int contentMargin: Math.max(28, Math.round(Math.min(width, height) * 0.035))

    Behavior on entrance {
        NumberAnimation {
            duration: root.isVisible ? 360 : 220
            easing.type: root.isVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    // ── State logic ──────────────────────────────────────────────────────────
    property int selectedPaletteIndex: -1
    property string selectedWallpaperPath: ""
    property string hoveredWallpaperPath: ""

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
    Keys.onLeftPressed: {
        if (root.inCarousel)
            carouselView.scrollStep(-1)
    }
    Keys.onRightPressed: {
        if (root.inCarousel)
            carouselView.scrollStep(1)
    }

    onIsVisibleChanged: {
        if (isVisible) {
            root.selectedPaletteIndex = -1
            root.hoveredWallpaperPath = ""
            root.selectedWallpaperPath = Settings.currentWallpaper || ""
            root.applyPreviewFromPalette(root.palettes[0])
            forceActiveFocus()
        }
    }

    // Simulated parse of a wallpaper-cache JSON (palette → accent + paths).
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

    function fileUrl(path) {
        if (!path)
            return ""
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
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

    // ── Scrim + content plane ────────────────────────────────────────────────
    opacity: Math.max(0, Math.min(1, root.entrance))
    visible: root.onScreen
    scale: 0.985 + 0.015 * Math.max(0, root.entrance)
    transformOrigin: Item.Center

    // Dimmed click-catcher — feels like an overlay, not a modal card
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        TapHandler {
            onTapped: root.requestClose()
        }
    }

    // Near-fullscreen content; absorb empty clicks so the scrim doesn't close
    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.contentMargin

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Wallpaper"
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    visible: root.inCarousel
                    text: root.activePalette ? `· ${root.activePalette.name}` : ""
                    color: ThemeManager.fgSecondary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 16
                }

                Rectangle {
                    visible: root.inCarousel
                    width: 10
                    height: 10
                    radius: 5
                    color: root.activePalette ? root.activePalette.accent : "transparent"
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: backBtn
                    visible: root.inCarousel
                    opacity: root.inCarousel ? 1 : 0
                    implicitWidth: backRow.implicitWidth + 28
                    implicitHeight: 36
                    radius: 10
                    color: backHover.hovered ? ThemeManager.surface1 : Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.88)
                    border.width: 1
                    border.color: ThemeManager.overlay(0.14)

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: backRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "\uf060"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 13
                            color: ThemeManager.fgSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Back to Themes"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 13
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
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 10
                    color: closeHover.hovered
                        ? ThemeManager.surface1
                        : Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.72)

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 15
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

            // Wallpaper-first live preview (full width, ~38% of content height)
            DesktopMock {
                id: desktopMock
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(content.height * 0.38)
                Layout.minimumHeight: 200
            }

            // Morphing island — remaining vertical space for swatches / carousel
            Item {
                id: island
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                state: root.inCarousel ? "carousel" : "swatches"

                SwatchGrid {
                    id: swatchGrid
                    anchors.fill: parent
                    opacity: 1
                    scale: 1
                    transformOrigin: Item.Center
                }

                CarouselView {
                    id: carouselView
                    anchors.fill: parent
                    opacity: 0
                    scale: 0.96
                    transformOrigin: Item.Center
                    enabled: root.inCarousel
                }

                states: [
                    State {
                        name: "swatches"
                        PropertyChanges { target: swatchGrid; opacity: 1; scale: 1 }
                        PropertyChanges { target: carouselView; opacity: 0; scale: 0.96 }
                    },
                    State {
                        name: "carousel"
                        PropertyChanges { target: swatchGrid; opacity: 0; scale: 0.94 }
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
    // Nested visual components
    // =========================================================================

    // Wallpaper-dominant preview: image fills the plane; chrome is a slim bar
    // plus a small corner window so theme accents stay readable.
    component DesktopMock: Rectangle {
        id: mock
        radius: 18
        color: root.colMantle
        border.width: 1
        border.color: ThemeManager.overlay(0.12)
        clip: true

        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutQuad } }

        Image {
            id: mockWall
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            source: root.fileUrl(root.hoveredWallpaperPath || root.selectedWallpaperPath)
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        // Gentle vignette — keeps labels readable without hiding the wallpaper
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.42) }
                GradientStop { position: 0.35; color: Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.08) }
                GradientStop { position: 0.75; color: Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.05) }
                GradientStop { position: 1.0; color: Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.40) }
            }
        }

        // Fallback fill when no wallpaper is ready
        Rectangle {
            anchors.fill: parent
            color: root.colBg
            opacity: mockWall.status === Image.Ready ? 0 : 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        // Slim Hyprland-style status bar
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            height: 28
            radius: 8
            color: Qt.rgba(root.colSurface.r, root.colSurface.g, root.colSurface.b, 0.88)
            border.width: 1
            border.color: root.colBorder
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 7

                Repeater {
                    model: 3
                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        color: index === 0 ? root.colAccent : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.35)
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Preview"
                    color: root.colFg
                    opacity: 0.75
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                Rectangle {
                    width: 12
                    height: 12
                    radius: 4
                    color: root.colAccent
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }
        }

        // Small floating window sample — corner only, wallpaper stays visible
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            width: Math.min(210, parent.width * 0.28)
            height: Math.min(128, parent.height * 0.42)
            radius: 10
            color: Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.92)
            border.width: 2
            border.color: root.colAccent
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

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

            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
                width: 56
                height: 16
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

        // Hex chips over the wallpaper (bottom-left)
        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 16
            spacing: 8

            Repeater {
                model: [
                    { label: "bg", value: root.colBg },
                    { label: "fg", value: root.colFg },
                    { label: "accent", value: root.colAccent }
                ]

                Rectangle {
                    height: 26
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.45)
                    border.width: 1
                    border.color: ThemeManager.overlay(0.18)
                    implicitWidth: chipRow.implicitWidth + 16

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 3
                            color: modelData.value
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        Text {
                            text: `${modelData.label}  ${String(modelData.value)}`
                            color: "#ffffff"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
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
        ScrollBar.vertical: ScrollBar {
            policy: gridFlick.contentHeight > gridFlick.height
                ? ScrollBar.AsNeeded
                : ScrollBar.AlwaysOff
        }

        GridLayout {
            id: grid
            width: gridFlick.width
            columns: width >= 1100 ? 4 : (width >= 720 ? 3 : 2)
            rowSpacing: 14
            columnSpacing: 14

            Repeater {
                model: root.palettes

                Rectangle {
                    id: card
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    radius: 16
                    color: Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.88)
                    border.width: cardHover.hovered ? 2 : 1
                    border.color: cardHover.hovered ? card.modelData.accent : ThemeManager.overlay(0.12)

                    scale: cardTap.pressed ? 0.97 : (cardHover.hovered ? 1.015 : 1.0)
                    Behavior on scale {
                        SpringAnimation {
                            spring: ThemeManager.bounceSpring
                            damping: ThemeManager.bounceDamping
                            mass: ThemeManager.bounceMass
                        }
                    }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: card.modelData.accent
                        opacity: cardHover.hovered ? 0.10 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            text: card.modelData.name
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

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

        function scrollStep(dir) {
            const step = Math.max(280, strip.width * 0.65)
            const maxX = Math.max(0, strip.contentWidth - strip.width)
            const target = Math.max(0, Math.min(maxX, strip.contentX + dir * step))
            scrollAnim.stop()
            scrollAnim.from = strip.contentX
            scrollAnim.to = target
            scrollAnim.start()
        }

        readonly property bool canScrollLeft: strip.contentX > 4
        readonly property bool canScrollRight: strip.contentX < strip.contentWidth - strip.width - 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.activePalette
                    ? `${root.activePalette.wallpapers.length} wallpapers in palette`
                    : ""
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Hover to preview · tap to apply · scroll or use arrows"
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 11
                opacity: 0.9
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: strip
                anchors.fill: parent
                anchors.leftMargin: 52
                anchors.rightMargin: 52
                orientation: ListView.Horizontal
                spacing: 16
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 800
                model: root.activePalette ? root.activePalette.wallpapers : []
                // Prefer wheel / buttons; drag still works but isn't required
                interactive: true

                NumberAnimation {
                    id: scrollAnim
                    target: strip
                    property: "contentX"
                    duration: 300
                    easing.type: Easing.OutCubic
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        // Vertical wheel pages sideways; trackpads may send X delta
                        const dx = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                            ? event.angleDelta.x
                            : event.angleDelta.y
                        const maxX = Math.max(0, strip.contentWidth - strip.width)
                        strip.contentX = Math.max(0, Math.min(maxX, strip.contentX - dx))
                        event.accepted = true
                    }
                }

                ScrollBar.horizontal: ScrollBar {
                    policy: strip.contentWidth > strip.width
                        ? ScrollBar.AsNeeded
                        : ScrollBar.AlwaysOff
                }

                delegate: WallpaperThumb {
                    required property string modelData
                    required property int index
                    folder: root.activePalette ? root.activePalette.folder : ""
                    fileName: modelData
                    accent: root.activePalette ? root.activePalette.accent : "#cba6f7"
                    absolutePath: root.wallpaperPath(folder, fileName)
                    // Landscape cards so more fit across the wide overlay
                    width: Math.max(260, Math.min(340, strip.height * 1.55))
                    height: strip.height - 10
                }
            }

            // Side page controls
            Rectangle {
                id: prevBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                visible: strip.contentWidth > strip.width
                opacity: carousel.canScrollLeft ? 1 : 0.35
                color: prevHover.hovered
                    ? ThemeManager.surface1
                    : Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.92)
                border.width: 1
                border.color: ThemeManager.overlay(0.16)
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf053"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 16
                    color: ThemeManager.fgPrimary
                }

                HoverHandler {
                    id: prevHover
                    enabled: carousel.canScrollLeft
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    enabled: carousel.canScrollLeft
                    onTapped: carousel.scrollStep(-1)
                }
            }

            Rectangle {
                id: nextBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                visible: strip.contentWidth > strip.width
                opacity: carousel.canScrollRight ? 1 : 0.35
                color: nextHover.hovered
                    ? ThemeManager.surface1
                    : Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.92)
                border.width: 1
                border.color: ThemeManager.overlay(0.16)
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf054"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 16
                    color: ThemeManager.fgPrimary
                }

                HoverHandler {
                    id: nextHover
                    enabled: carousel.canScrollRight
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    enabled: carousel.canScrollRight
                    onTapped: carousel.scrollStep(1)
                }
            }
        }
    }

    component WallpaperThumb: Item {
        id: thumb
        property string folder: ""
        property string fileName: ""
        property color accent: "#cba6f7"
        property string absolutePath: ""
        readonly property int imageRadius: 12

        readonly property bool isSelected: root.selectedWallpaperPath === absolutePath
        readonly property bool isHot: thumbHover.hovered || isSelected

        scale: thumbTap.pressed ? 0.97 : (thumbHover.hovered ? 1.02 : 1.0)
        Behavior on scale {
            SpringAnimation {
                spring: ThemeManager.bounceSpring
                damping: ThemeManager.bounceDamping
                mass: ThemeManager.bounceMass
            }
        }

        // Accent glow behind the rounded plate
        Rectangle {
            id: glowPlate
            anchors.fill: plate
            anchors.margins: -3
            radius: thumb.imageRadius + 4
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

        // Outer border ring (rounded) — sits outside the masked image
        Rectangle {
            id: plate
            anchors.fill: parent
            anchors.margins: 6
            radius: thumb.imageRadius
            color: ThemeManager.surface0
            border.width: thumb.isHot ? 2 : 1
            border.color: thumb.isHot ? thumb.accent : ThemeManager.overlay(0.12)
            Behavior on border.color { ColorAnimation { duration: 140 } }

            // Image + caption masked to the plate radius so corners never clip
            Item {
                id: imgHost
                anchors.fill: parent
                anchors.margins: plate.border.width

                Item {
                    id: thumbSource
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Image {
                        anchors.fill: parent
                        source: root.wallpaperUrl(thumb.folder, thumb.fileName)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 640
                        sourceSize.height: 400
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 32
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            text: thumb.fileName
                            color: "#ffffff"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                        }
                    }
                }

                Rectangle {
                    id: thumbMask
                    anchors.fill: parent
                    radius: Math.max(0, thumb.imageRadius - plate.border.width)
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: thumbSource
                    maskSource: thumbMask
                }
            }

            // Pulsing selection ring
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

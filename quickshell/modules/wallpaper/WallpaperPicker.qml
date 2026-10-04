import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../.."

// =============================================================================
// WallpaperPicker — Cover Flow overlay
//
// Full-screen dimmed scrim with a vertically centered Cover Flow of wallpaper
// thumbnails. The image list follows Settings.wallpaperSource (theme folder or
// the entire wallpaper tree). Tap the center cover (or press Return) to apply.
// =============================================================================
Item {
    id: root

    anchors.fill: parent

    property bool isVisible: false
    property real entrance: isVisible ? 1 : 0
    readonly property bool onScreen: isVisible || entrance > 0.02

    property var images: []
    property int currentIndex: 0

    signal requestClose()
    signal wallpaperApplied(string path)

    Behavior on entrance {
        NumberAnimation {
            duration: root.isVisible ? 320 : 200
            easing.type: root.isVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    focus: true
    Keys.onEscapePressed: root.requestClose()
    Keys.onLeftPressed: coverFlow.decrementCurrentIndex()
    Keys.onRightPressed: coverFlow.incrementCurrentIndex()
    Keys.onReturnPressed: root.applyCurrent()
    Keys.onEnterPressed: root.applyCurrent()

    onIsVisibleChanged: {
        if (isVisible) {
            root.refresh()
            forceActiveFocus()
        }
    }

    function expandHome(path) {
        if (!path)
            return ""
        const text = String(path)
        if (text.startsWith("~"))
            return Quickshell.env("HOME") + text.slice(1)
        return text
    }

    function scanRoot() {
        const base = root.expandHome(Settings.wallpaperDir || "~/Pictures/Wallpapers")
        if (Settings.wallpaperSource === "theme" && ThemeManager.wallpaperDir)
            return `${base}/${ThemeManager.wallpaperDir}`
        return base
    }

    function fileUrl(path) {
        if (!path)
            return ""
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
    }

    function fileName(path) {
        if (!path)
            return ""
        const parts = String(path).split("/")
        return parts[parts.length - 1] || path
    }

    function relativeLabel(path) {
        const rootDir = root.expandHome(Settings.wallpaperDir || "~/Pictures/Wallpapers")
        const p = String(path)
        if (p.startsWith(rootDir + "/"))
            return p.slice(rootDir.length + 1)
        return root.fileName(p)
    }

    function refresh() {
        loader.command = [
            "python3",
            `${Quickshell.shellDir}/scripts/list-wallpapers.py`,
            root.scanRoot()
        ]
        loader.running = false
        loader.running = true
    }

    function applyCurrent() {
        if (root.images.length === 0)
            return
        const path = root.images[coverFlow.currentIndex]
        if (!path)
            return
        Settings.currentWallpaper = path
        // Picking a wallpaper switches out of slideshow so the choice sticks
        if (Settings.wallpaperMode === "slideshow")
            Settings.wallpaperMode = "static"
        Settings.save()
        Quickshell.execDetached([
            "python3",
            `${Quickshell.shellDir}/scripts/set-wallpaper.py`,
            path,
            Settings.wallpaperTransition
        ])
        root.wallpaperApplied(path)
    }

    function syncIndexToCurrent() {
        const cur = root.expandHome(Settings.currentWallpaper || "")
        if (!cur || root.images.length === 0) {
            coverFlow.currentIndex = 0
            return
        }
        const i = root.images.indexOf(cur)
        coverFlow.currentIndex = i >= 0 ? i : 0
    }

    opacity: Math.max(0, Math.min(1, root.entrance))
    visible: root.onScreen

    Process {
        id: loader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                root.images = lines
                root.syncIndexToCurrent()
            }
        }
    }

    // Scrim
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.62)
        TapHandler {
            onTapped: root.requestClose()
        }
    }

    // Vertically centered Cover Flow stage
    Item {
        id: stage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.min(parent.height * 0.72, 560)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 40
            anchors.rightMargin: 40
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Wallpapers"
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Settings.wallpaperSource === "theme"
                        ? ThemeManager.wallpaperDir
                        : "All folders"
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 13
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.images.length > 0
                        ? `${coverFlow.currentIndex + 1} / ${root.images.length}`
                        : "No images"
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                }

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 10
                    color: closeHover.hovered
                        ? ThemeManager.surface1
                        : Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.75)

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

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Side chevrons
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    z: 20
                    width: 44
                    height: 44
                    radius: 22
                    visible: root.images.length > 1
                    opacity: coverFlow.currentIndex > 0 ? 1 : 0.35
                    color: Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.9)
                    border.width: 1
                    border.color: ThemeManager.overlay(0.14)

                    Text {
                        anchors.centerIn: parent
                        text: "\uf053"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: ThemeManager.fgPrimary
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: coverFlow.currentIndex > 0
                        onTapped: coverFlow.decrementCurrentIndex()
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    z: 20
                    width: 44
                    height: 44
                    radius: 22
                    visible: root.images.length > 1
                    opacity: coverFlow.currentIndex < root.images.length - 1 ? 1 : 0.35
                    color: Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.9)
                    border.width: 1
                    border.color: ThemeManager.overlay(0.14)

                    Text {
                        anchors.centerIn: parent
                        text: "\uf054"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: ThemeManager.fgPrimary
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: coverFlow.currentIndex < root.images.length - 1
                        onTapped: coverFlow.incrementCurrentIndex()
                    }
                }

                PathView {
                    id: coverFlow
                    anchors.fill: parent
                    anchors.leftMargin: 56
                    anchors.rightMargin: 56
                    model: root.images
                    pathItemCount: Math.min(9, Math.max(3, root.images.length))
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    flickDeceleration: 120
                    movementDirection: PathView.Positive
                    focus: true
                    clip: false

                    path: Path {
                        startX: 0
                        startY: coverFlow.height * 0.48

                        PathAttribute { name: "coverZ"; value: 0 }
                        PathAttribute { name: "coverAngle"; value: 65 }
                        PathAttribute { name: "coverScale"; value: 0.55 }
                        PathAttribute { name: "coverOpacity"; value: 0.35 }

                        PathLine {
                            x: coverFlow.width * 0.5
                            y: coverFlow.height * 0.48
                        }
                        PathAttribute { name: "coverZ"; value: 100 }
                        PathAttribute { name: "coverAngle"; value: 0 }
                        PathAttribute { name: "coverScale"; value: 1.0 }
                        PathAttribute { name: "coverOpacity"; value: 1.0 }

                        PathLine {
                            x: coverFlow.width
                            y: coverFlow.height * 0.48
                        }
                        PathAttribute { name: "coverZ"; value: 0 }
                        PathAttribute { name: "coverAngle"; value: -65 }
                        PathAttribute { name: "coverScale"; value: 0.55 }
                        PathAttribute { name: "coverOpacity"; value: 0.35 }
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const dx = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                                ? event.angleDelta.x
                                : event.angleDelta.y
                            if (dx > 0)
                                coverFlow.decrementCurrentIndex()
                            else if (dx < 0)
                                coverFlow.incrementCurrentIndex()
                            event.accepted = true
                        }
                    }

                    delegate: Item {
                        id: cover
                        required property string modelData
                        required property int index

                        width: Math.min(420, coverFlow.width * 0.38)
                        height: Math.min(260, coverFlow.height * 0.72)
                        z: PathView.coverZ
                        scale: PathView.coverScale
                        opacity: PathView.coverOpacity
                        property bool isCenter: PathView.isCurrentItem

                        transform: Rotation {
                            origin.x: cover.width / 2
                            origin.y: cover.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: PathView.coverAngle
                        }

                        Rectangle {
                            id: plate
                            anchors.fill: parent
                            radius: 14
                            color: ThemeManager.surface0
                            border.width: cover.isCenter ? 2 : 1
                            border.color: cover.isCenter ? ThemeManager.accentBlue : ThemeManager.overlay(0.16)

                            layer.enabled: cover.isCenter
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Qt.rgba(
                                    ThemeManager.accentBlue.r,
                                    ThemeManager.accentBlue.g,
                                    ThemeManager.accentBlue.b,
                                    0.55
                                )
                                shadowBlur: 0.7
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 8
                            }

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
                                        source: root.fileUrl(cover.modelData)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 720
                                        sourceSize.height: 450
                                    }
                                }

                                Rectangle {
                                    id: thumbMask
                                    anchors.fill: parent
                                    radius: Math.max(0, 14 - plate.border.width)
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: thumbSource
                                    maskSource: thumbMask
                                }
                            }
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: {
                                if (cover.isCenter)
                                    root.applyCurrent()
                                else
                                    coverFlow.currentIndex = cover.index
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.images.length === 0
                    text: "No wallpapers found in this source"
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 14
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.images.length > 0
                        ? root.relativeLabel(root.images[coverFlow.currentIndex])
                        : ""
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: stage.width - 120
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Scroll or use arrows · tap center cover or press Enter to apply · Esc to close"
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                    opacity: 0.9
                }
            }
        }
    }
}

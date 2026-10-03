import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Background slideshow engine. Respects Settings.wallpaperSource /
// wallpaperMode / wallpaperSlideshowInterval and applies images with the
// same set-wallpaper.py + transition path as the picker.
Item {
    id: root

    property var images: []
    property int index: 0
    property bool loading: false

    readonly property bool active: Settings.wallpaperMode === "slideshow" && images.length > 1

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

    function refresh() {
        loader.command = [
            "python3",
            `${Quickshell.shellDir}/scripts/list-wallpapers.py`,
            root.scanRoot()
        ]
        loader.running = false
        loader.running = true
    }

    function applyPath(path) {
        if (!path)
            return
        Settings.currentWallpaper = path
        Settings.save()
        Quickshell.execDetached([
            "python3",
            `${Quickshell.shellDir}/scripts/set-wallpaper.py`,
            path,
            Settings.wallpaperTransition
        ])
    }

    function advance() {
        if (!root.active)
            return
        root.index = (root.index + 1) % root.images.length
        root.applyPath(root.images[root.index])
    }

    function syncIndexToCurrent() {
        const cur = root.expandHome(Settings.currentWallpaper || "")
        if (!cur || root.images.length === 0) {
            root.index = 0
            return
        }
        const i = root.images.indexOf(cur)
        root.index = i >= 0 ? i : 0
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Settings
        function onWallpaperSourceChanged() { root.refresh() }
        function onWallpaperDirChanged() { root.refresh() }
        function onWallpaperModeChanged() {
            if (Settings.wallpaperMode === "slideshow")
                root.refresh()
        }
        function onCurrentWallpaperChanged() { root.syncIndexToCurrent() }
    }

    Connections {
        target: ThemeManager
        function onWallpaperDirChanged() {
            if (Settings.wallpaperSource === "theme")
                root.refresh()
        }
    }

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

    Timer {
        id: slideTimer
        interval: Math.max(10, Settings.wallpaperSlideshowInterval) * 1000
        running: root.active
        repeat: true
        onTriggered: root.advance()
    }
}

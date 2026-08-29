import QtQuick
import ".."

// Picture frame for solid + docked bar.
//
// The fullscreen host is a true screen-sized overlay (it ignores the bar's
// exclusive zone). Inner-hole top is the bar's bottom edge, so the top
// inverse corners sit on that join instead of being shifted down by the
// reserved bar height a second time.
//
// `topSectionOnly` only paints the bar strip inside the bar window. Sides
// and all four inner corners come from the fullscreen host.
Item {
    id: root
    visible: ThemeManager.useFrameEmerge && !ThemeManager.hideScreenFrame
    anchors.fill: parent

    property bool topSectionOnly: false

    readonly property int t: ThemeManager.frameThickness
    readonly property int r: ThemeManager.frameInnerRadius
    readonly property int barH: ThemeManager.barHeight + ThemeManager.barPillTopMargin
    readonly property bool barBottom: ThemeManager.emergeFromBottom
    readonly property color fill: ThemeManager.frameFillColor
    readonly property int dockBezel: {
        if (!ThemeManager.frameDockSpansEdge)
            return 0
        if (Settings.dockPosition === "bottom" || Settings.dockPosition === "top")
            return ThemeManager.dockChromeSize
        return 0
    }
    readonly property int dockSideBezel: {
        if (!ThemeManager.frameDockSpansEdge)
            return 0
        if (Settings.dockPosition === "left" || Settings.dockPosition === "right")
            return ThemeManager.dockChromeSize
        return 0
    }

    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onTChanged: canvas.requestPaint()
    onRChanged: canvas.requestPaint()
    onBarHChanged: canvas.requestPaint()
    onBarBottomChanged: canvas.requestPaint()
    onFillChanged: canvas.requestPaint()
    onTopSectionOnlyChanged: canvas.requestPaint()
    onDockBezelChanged: canvas.requestPaint()
    onDockSideBezelChanged: canvas.requestPaint()

    Component.onCompleted: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: false

        onPaint: {
            const ctx = getContext("2d")
            const w = root.width
            const h = root.height
            const t = root.t
            const overlap = 2
            const barH = root.barH
            const barBottom = root.barBottom
            const topOnly = root.topSectionOnly
            const joinTop = barBottom ? t : Math.max(0, barH)
            const farBezel = Math.max(t, root.dockBezel)
            const joinBot = barBottom
                ? Math.max(t, h - barH)
                : Math.max(joinTop + 2, h - farBezel)
            const leftW = (root.dockSideBezel > 0 && Settings.dockPosition === "left") ? root.dockSideBezel : t
            const rightW = (root.dockSideBezel > 0 && Settings.dockPosition === "right") ? root.dockSideBezel : t
            const innerW = w - leftW - rightW
            const innerH = joinBot - joinTop
            let rr = root.r
            if (rr * 2 > innerW)
                rr = innerW / 2
            if (!topOnly && rr * 2 > innerH)
                rr = innerH / 2
            if (w < 2 || h < 2 || t < 1)
                return

            function invCorner(x0, y0, kind) {
                ctx.beginPath()
                if (kind === "tl") {
                    ctx.moveTo(x0, y0)
                    ctx.lineTo(x0 + rr, y0)
                    ctx.arc(x0 + rr, y0 + rr, rr, -Math.PI / 2, Math.PI, true)
                } else if (kind === "tr") {
                    ctx.moveTo(x0, y0)
                    ctx.lineTo(x0, y0 + rr)
                    ctx.arc(x0 - rr, y0 + rr, rr, 0, -Math.PI / 2, true)
                } else if (kind === "bl") {
                    ctx.moveTo(x0, y0)
                    ctx.lineTo(x0, y0 - rr)
                    ctx.arc(x0 + rr, y0 - rr, rr, Math.PI, Math.PI / 2, true)
                } else {
                    ctx.moveTo(x0, y0)
                    ctx.lineTo(x0 - rr, y0)
                    ctx.arc(x0 - rr, y0 - rr, rr, Math.PI / 2, 0, true)
                }
                ctx.closePath()
                ctx.fill()
            }

            ctx.clearRect(0, 0, w, h)
            ctx.fillStyle = root.fill

            if (topOnly) {
                if (barBottom)
                    ctx.fillRect(0, Math.max(0, h - barH), w, Math.min(h, barH))
                else
                    ctx.fillRect(0, 0, w, joinTop)
                return
            }

            const sideTop = barBottom ? 0 : Math.max(0, joinTop - overlap)
            ctx.fillRect(0, sideTop, leftW, h - sideTop)
            ctx.fillRect(w - rightW, sideTop, rightW, h - sideTop)
            // Keep the hole-facing edge of the far bezel flush with `t` so
            // the wallpaper gap matches the left/right sides. Overlap is
            // only used where the sides tuck under the bar. A full-span
            // framed dock owns that strip, so skip it to avoid a double edge.
            if (barBottom)
                ctx.fillRect(t, 0, w - 2 * t, joinTop)
            else if (root.dockBezel < 1)
                ctx.fillRect(t, joinBot, w - 2 * t, h - joinBot)

            invCorner(leftW, joinTop, "tl")
            invCorner(w - rightW, joinTop, "tr")
            invCorner(leftW, joinBot, "bl")
            invCorner(w - rightW, joinBot, "br")
        }
    }
}

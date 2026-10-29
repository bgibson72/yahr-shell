import QtQuick 2.15

// Picture-frame bezel with equal thickness on all four sides.
// Inverse corners open the wallpaper hole the login plate joins into.
Item {
    id: root
    anchors.fill: parent

    property int frameThickness: 10
    property int frameInnerRadius: 12
    property color fill: "#181625"

    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onFrameThicknessChanged: canvas.requestPaint()
    onFrameInnerRadiusChanged: canvas.requestPaint()
    onFillChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: false

        onPaint: {
            const ctx = getContext("2d")
            const w = root.width
            const h = root.height
            const t = Math.max(1, root.frameThickness)
            const joinTop = t
            const joinBot = Math.max(joinTop + 2, h - t)
            const innerW = w - 2 * t
            const innerH = joinBot - joinTop
            let rr = root.frameInnerRadius
            if (rr * 2 > innerW)
                rr = Math.max(0, innerW / 2)
            if (rr * 2 > innerH)
                rr = Math.max(0, innerH / 2)
            if (w < 2 || h < 2)
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

            ctx.fillRect(0, 0, t, h)
            ctx.fillRect(w - t, 0, t, h)
            ctx.fillRect(t, 0, w - 2 * t, joinTop)
            ctx.fillRect(t, joinBot, w - 2 * t, h - joinBot)

            if (rr >= 1) {
                invCorner(t, joinTop, "tl")
                invCorner(w - t, joinTop, "tr")
                invCorner(t, joinBot, "bl")
                invCorner(w - t, joinBot, "br")
            }
        }
    }
}

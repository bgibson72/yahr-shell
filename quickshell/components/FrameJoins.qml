import QtQuick
import ".."

// Inverse-corner "ears" where a widget or dock meets the screen frame.
// Parent the canvas so (0, 0) is `joinR` above/left of the chrome; size is
// content plus pad on every side — the same space ScreenFrame.invCorner uses.
Canvas {
    id: root
    antialiasing: false

    property int joinR: 0
    property int contentW: 0
    property int contentH: 0
    property bool joinTop: false
    property bool joinBottom: false
    property bool joinLeft: false
    property bool joinRight: false
    property bool joinLeftEdge: false
    property bool joinRightEdge: false
    property bool joinFullSpan: false
    readonly property color fill: ThemeManager.frameFillColor

    width: Math.max(0, contentW + joinR * 2)
    height: Math.max(0, contentH + joinR * 2)
    visible: joinR > 1 && contentW > 1 && contentH > 1
        && (joinTop || joinBottom || joinLeftEdge || joinRightEdge)

    onJoinRChanged: requestPaint()
    onContentWChanged: requestPaint()
    onContentHChanged: requestPaint()
    onJoinTopChanged: requestPaint()
    onJoinBottomChanged: requestPaint()
    onJoinLeftChanged: requestPaint()
    onJoinRightChanged: requestPaint()
    onJoinLeftEdgeChanged: requestPaint()
    onJoinRightEdgeChanged: requestPaint()
    onJoinFullSpanChanged: requestPaint()
    onFillChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        const rr = root.joinR
        const w = root.contentW
        const h = root.contentH
        if (rr < 1 || w < 2 || h < 2)
            return
        ctx.clearRect(0, 0, root.width, root.height)
        ctx.fillStyle = root.fill

        function inv(x0, y0, kind) {
            const x = x0 + rr
            const y = y0 + rr
            ctx.beginPath()
            if (kind === "tl") {
                ctx.moveTo(x, y)
                ctx.lineTo(x + rr, y)
                ctx.arc(x + rr, y + rr, rr, -Math.PI / 2, Math.PI, true)
            } else if (kind === "tr") {
                ctx.moveTo(x, y)
                ctx.lineTo(x, y + rr)
                ctx.arc(x - rr, y + rr, rr, 0, -Math.PI / 2, true)
            } else if (kind === "bl") {
                ctx.moveTo(x, y)
                ctx.lineTo(x, y - rr)
                ctx.arc(x + rr, y - rr, rr, Math.PI, Math.PI / 2, true)
            } else {
                ctx.moveTo(x, y)
                ctx.lineTo(x - rr, y)
                ctx.arc(x - rr, y - rr, rr, Math.PI / 2, 0, true)
            }
            ctx.closePath()
            ctx.fill()
        }

        if (root.joinFullSpan && root.joinBottom) {
            inv(0, 0, "bl")
            inv(w, 0, "br")
        } else if (root.joinFullSpan && root.joinTop) {
            inv(0, h, "tl")
            inv(w, h, "tr")
        } else if (root.joinFullSpan && root.joinLeftEdge) {
            inv(w, 0, "tl")
            inv(w, h, "bl")
        } else if (root.joinFullSpan && root.joinRightEdge) {
            inv(0, 0, "tr")
            inv(0, h, "br")
        } else if (root.joinTop && root.joinLeft) {
            inv(w, 0, "tl")
            inv(0, h, "tl")
        } else if (root.joinTop && root.joinRight) {
            inv(0, 0, "tr")
            inv(w, h, "tr")
        } else if (root.joinTop) {
            inv(0, 0, "tr")
            inv(w, 0, "tl")
        } else if (root.joinBottom && root.joinLeft) {
            inv(w, h, "bl")
            inv(0, 0, "bl")
        } else if (root.joinBottom && root.joinRight) {
            inv(0, h, "br")
            inv(w, 0, "br")
        } else if (root.joinBottom) {
            inv(0, h, "br")
            inv(w, h, "bl")
        } else if (root.joinRightEdge) {
            inv(w, 0, "br")
            inv(w, h, "tr")
        } else if (root.joinLeftEdge) {
            inv(0, 0, "bl")
            inv(0, h, "tl")
        }
    }
}

import QtQuick

Canvas {
    id: root

    property var values: []
    property real maxValue: 100
    property color color: "#89b4fa"
    property color fillColor: Qt.rgba(0.5, 0.7, 0.98, 0.2)
    property real lineWidth: 2

    onValuesChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (values.length === 0)
            return

        const w = width
        const h = height
        const padding = 4
        const plotHeight = h - padding * 2
        const pointSpacing = w / Math.max(values.length - 1, 1)

        function pointAt(i) {
            const normalized = Math.min(values[i] / maxValue, 1.0)
            return [i * pointSpacing, h - padding - (normalized * plotHeight)]
        }

        const gradient = ctx.createLinearGradient(0, padding, 0, h - padding)
        gradient.addColorStop(0, fillColor)
        gradient.addColorStop(1, Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0))

        ctx.beginPath()
        ctx.moveTo(0, h - padding)
        for (let i = 0; i < values.length; i++) {
            const [x, y] = pointAt(i)
            ctx.lineTo(x, y)
        }
        ctx.lineTo(w, h - padding)
        ctx.closePath()
        ctx.fillStyle = gradient
        ctx.fill()

        ctx.beginPath()
        for (let i = 0; i < values.length; i++) {
            const [x, y] = pointAt(i)
            if (i === 0)
                ctx.moveTo(x, y)
            else
                ctx.lineTo(x, y)
        }
        ctx.strokeStyle = color
        ctx.lineWidth = lineWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.stroke()

        if (values.length > 0) {
            const [lastX, lastY] = pointAt(values.length - 1)
            ctx.beginPath()
            ctx.arc(lastX, lastY, 3, 0, 2 * Math.PI)
            ctx.fillStyle = color
            ctx.fill()
        }
    }
}

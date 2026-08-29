import QtQuick
import "../.."

// Full-screen busy overlay shown while `yahr-theme apply` is running, so the
// user gets feedback instead of a UI that looks frozen for the brief moment
// themes/wallpapers/configs are being rewritten on disk.
Item {
    id: root

    property bool isVisible: false
    property string themeName: ""

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Item {
                width: 56
                height: 56
                anchors.horizontalCenter: parent.horizontalCenter

                // Quiet track so the gap in the spinner reads as motion.
                Rectangle {
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    radius: 24
                    color: "transparent"
                    border.width: 4
                    border.color: ThemeManager.accentBlue
                    opacity: 0.18
                }

                Canvas {
                    id: spinner
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    antialiasing: true
                    renderTarget: Canvas.FramebufferObject
                    property color accent: ThemeManager.accentBlue

                    onAccentChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const cx = width / 2
                        const cy = height / 2
                        const line = 4
                        const radius = (Math.min(width, height) - line) / 2
                        const segments = 64
                        const sweep = Math.PI * 1.65
                        const start = -Math.PI / 2
                        ctx.lineWidth = line
                        ctx.lineCap = "round"
                        for (let i = 0; i < segments; i++) {
                            const t = (i + 1) / segments
                            const a0 = start + (i / segments) * sweep
                            const a1 = start + ((i + 1.2) / segments) * sweep
                            ctx.beginPath()
                            ctx.strokeStyle = Qt.rgba(spinner.accent.r, spinner.accent.g, spinner.accent.b, t * t)
                            ctx.arc(cx, cy, radius, a0, Math.min(a1, start + sweep))
                            ctx.stroke()
                        }
                    }

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1100
                        running: root.isVisible
                        easing.type: Easing.Linear
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Applying Theme"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: ThemeManager.fgPrimary
                }

                Text {
                    visible: root.themeName !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.themeName
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeNormal
                    color: ThemeManager.accentBlue
                }
            }
        }

        // Safety net: never leave the shell stuck behind an overlay if the
        // apply process hangs or its exit signal is missed for some reason.
        Timer {
            interval: 5000
            running: root.isVisible
            repeat: false
            onTriggered: root.isVisible = false
        }
    }
}

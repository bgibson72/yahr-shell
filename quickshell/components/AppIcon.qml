import QtQuick
import Quickshell
import ".."

// Resolves a desktop Icon= value to a real pixmap and hides Qt's
// checkerboard if the lookup still fails.
Item {
    id: root
    property string iconName: ""
    property int pixelSize: 32
    property color fallbackColor: ThemeManager.fgTertiary

    width: pixelSize
    height: pixelSize

    readonly property url resolved: {
        const n = (root.iconName || "").trim()
        if (!n)
            return ""
        if (n.startsWith("file:"))
            return n
        if (n.startsWith("/"))
            return "file://" + n
        const checked = Quickshell.iconPath(n, true)
        if (checked) {
            if (checked.startsWith("file:") || checked.startsWith("image:"))
                return checked
            return checked.startsWith("/") ? "file://" + checked : checked
        }
        return "image://icon/" + n
    }

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize.width: root.pixelSize
        sourceSize.height: root.pixelSize
        source: root.resolved
        visible: status === Image.Ready
    }

    Text {
        visible: img.status !== Image.Ready
        anchors.centerIn: parent
        text: "󰣆"
        font.family: "Symbols Nerd Font"
        font.pixelSize: Math.round(root.pixelSize * 0.72)
        color: root.fallbackColor
    }
}

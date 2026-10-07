import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.."

Item {
    id: workspaceBar
    property int minWorkspaces: 4

    readonly property int itemWidth: Settings.workspaceStyle === "dots" ? 22 : 38
    readonly property int itemSpacing: 4
    readonly property int itemHeight: 34

    property int displayCount: {
        let max = workspaceBar.minWorkspaces
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
            const activeId = Hyprland.focusedMonitor.activeWorkspace.id
            if (activeId > max)
                max = activeId
        }
        for (let i = 0; i < Hyprland.workspaces.length; i++) {
            const ws = Hyprland.workspaces[i]
            if (ws.id > max && ws.toplevels && ws.toplevels.length > 0)
                max = ws.id
        }
        return max
    }

    readonly property int currentWorkspaceId: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
        ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    readonly property int currentIndex: Math.max(0, Math.min(displayCount - 1, currentWorkspaceId - 1))
    onCurrentIndexChanged: plop.restart()

    implicitWidth: displayCount * itemWidth + Math.max(0, displayCount - 1) * itemSpacing
    implicitHeight: itemHeight

    // The active workspace is shown by this single pill sliding between
    // slots (rather than each dot re-coloring independently), then it
    // "plops" with a scale burst once it arrives at its new slot.
    Rectangle {
        id: indicator
        property bool primed: false

        width: Settings.workspaceStyle === "dots" ? 13 : workspaceBar.itemWidth - 4
        height: Settings.workspaceStyle === "dots" ? 13 : workspaceBar.itemHeight - 8
        radius: Settings.workspaceStyle === "dots" ? width / 2 : 8
        color: Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.85)

        y: (workspaceBar.itemHeight - height) / 2
        x: workspaceBar.currentIndex * (workspaceBar.itemWidth + workspaceBar.itemSpacing) + workspaceBar.itemWidth / 2 - width / 2

        Behavior on x {
            enabled: indicator.primed
            NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        Component.onCompleted: Qt.callLater(() => primed = true)

        SequentialAnimation {
            id: plop
            PauseAnimation { duration: 290 }
            NumberAnimation { target: indicator; property: "scale"; to: 1.6; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { target: indicator; property: "scale"; to: 1.0; duration: 440; easing.type: Easing.OutBack; easing.overshoot: 5 }
        }
    }

    Repeater {
        model: workspaceBar.displayCount

        MouseArea {
            id: btn
            required property int index
            property int workspaceId: index + 1
            property var hyprWorkspace: {
                for (let i = 0; i < Hyprland.workspaces.length; i++) {
                    if (Hyprland.workspaces[i].id === workspaceId)
                        return Hyprland.workspaces[i]
                }
                return null
            }
            property bool isCurrent: workspaceBar.currentWorkspaceId === workspaceId

            x: index * (workspaceBar.itemWidth + workspaceBar.itemSpacing)
            y: 0
            width: workspaceBar.itemWidth
            height: workspaceBar.itemHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            scale: btn.pressed ? ThemeManager.iconPressScale : (btn.containsMouse ? ThemeManager.iconHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: Settings.workspaceStyle === "dots" ? 13 : parent.width - 4
                height: Settings.workspaceStyle === "dots" ? 13 : parent.height - 8
                radius: Settings.workspaceStyle === "dots" ? width / 2 : 8
                color: {
                    if (btn.isCurrent)
                        return "transparent"
                    if (btn.containsMouse)
                        return ThemeManager.overlay(0.12)
                    if (btn.hyprWorkspace && btn.hyprWorkspace.toplevels && btn.hyprWorkspace.toplevels.length > 0)
                        return Qt.rgba(ThemeManager.fgTertiary.r, ThemeManager.fgTertiary.g, ThemeManager.fgTertiary.b, 0.55)
                    return Qt.rgba(ThemeManager.fgTertiary.r, ThemeManager.fgTertiary.g, ThemeManager.fgTertiary.b, 0.22)
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                visible: Settings.workspaceStyle !== "dots"
                anchors.centerIn: parent
                text: btn.workspaceId.toString()
                font.family: ThemeManager.uiFont
                font.pixelSize: 13
                font.bold: btn.isCurrent
                color: btn.isCurrent ? ThemeManager.bgBase : ThemeManager.fgPrimary
            }

            // Hyprland 0.55+ moved to a Lua-based dispatch protocol: the IPC
            // socket evaluates the payload as `hl.dispatch(<payload>)`, so a
            // bare "workspace N" string is no longer valid — it must be a
            // real dispatcher call.
            onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${btn.workspaceId} })`)
        }
    }
}

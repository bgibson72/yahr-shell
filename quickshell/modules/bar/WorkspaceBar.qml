import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
    id: workspaceBar
    spacing: 4
    property int minWorkspaces: 4

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
            property bool isCurrent: {
                if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
                    return Hyprland.focusedMonitor.activeWorkspace.id === workspaceId
                return !!(hyprWorkspace && (hyprWorkspace.focused || hyprWorkspace.active))
            }

            Layout.preferredWidth: Settings.workspaceStyle === "dots" ? 18 : 32
            Layout.preferredHeight: 28
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            Rectangle {
                anchors.centerIn: parent
                width: Settings.workspaceStyle === "dots" ? 10 : parent.width - 4
                height: Settings.workspaceStyle === "dots" ? 10 : parent.height - 8
                radius: Settings.workspaceStyle === "dots" ? width / 2 : 6
                color: {
                    if (btn.isCurrent)
                        return Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.85)
                    if (btn.containsMouse)
                        return Qt.rgba(1, 1, 1, 0.12)
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
                font.pixelSize: 12
                font.bold: btn.isCurrent
                color: ThemeManager.fgPrimary
            }

            onClicked: Hyprland.dispatch("workspace " + workspaceId)
        }
    }
}

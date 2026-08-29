import QtQuick
import Quickshell
import "../../components"
import "../.."

// Pinned-app launcher that can sit on any screen edge. Chrome (background
// pill) either hugs the icons or spans the full edge; the parent window
// may itself span the edge (dodge / full-span) so Hyprland can reserve
// space. Alignment is applied here so we never switch PanelWindow anchor
// lines at runtime.
Item {
    id: dock

    signal settingsRequested()
    signal appPickerRequested()
    signal trashRequested()

    readonly property string position: Settings.dockPosition
    readonly property string alignment: Settings.dockAlignment
    readonly property bool isHorizontal: position === "top" || position === "bottom"
    readonly property int iconSize: Settings.dockIconSize
    readonly property int padding: 10
    readonly property int itemSpacing: 8
    property alias maskBackground: background

    readonly property bool frameJoin: ThemeManager.useFrameDock
    readonly property bool joinFullSpan: frameJoin && Settings.dockSpanFullWidth
    readonly property int joinR: frameJoin ? ThemeManager.frameInnerRadius : 0
    readonly property int joinPad: joinR
    readonly property bool joinBottom: frameJoin && !joinFullSpan && position === "bottom"
    readonly property bool joinTop: frameJoin && !joinFullSpan && position === "top"
    readonly property bool joinLeftEdge: frameJoin && !joinFullSpan && position === "left"
    readonly property bool joinRightEdge: frameJoin && !joinFullSpan && position === "right"
    readonly property bool joinLeft: frameJoin && !joinFullSpan && isHorizontal && alignment === "start"
    readonly property bool joinRight: frameJoin && !joinFullSpan && isHorizontal && alignment === "end"
    readonly property int freeR: frameJoin ? joinR : ThemeManager.dockRadius

    implicitWidth: chromeHost.implicitWidth + joinPad * 2
    implicitHeight: chromeHost.implicitHeight + joinPad * 2

    Item {
        id: chromeHost
        x: dock.joinPad
        y: dock.joinPad
        width: Math.max(0, dock.width - dock.joinPad * 2)
        height: Math.max(0, dock.height - dock.joinPad * 2)
        implicitWidth: dock.isHorizontal ? contentRow.implicitWidth + dock.padding * 2 : dock.iconSize + 20
        implicitHeight: dock.isHorizontal ? dock.iconSize + 20 : contentColumn.implicitHeight + dock.padding * 2

    Rectangle {
        id: background
        radius: dock.freeR
        topLeftRadius: {
            if (!dock.frameJoin)
                return dock.freeR
            if (dock.joinFullSpan)
                return 0
            if ((dock.joinTop && !dock.joinLeft) || dock.joinLeftEdge || (dock.joinBottom && dock.joinLeft))
                return 0
            return dock.freeR
        }
        topRightRadius: {
            if (!dock.frameJoin)
                return dock.freeR
            if (dock.joinFullSpan)
                return 0
            if ((dock.joinTop && !dock.joinRight) || dock.joinRightEdge || (dock.joinBottom && dock.joinRight))
                return 0
            return dock.freeR
        }
        bottomLeftRadius: {
            if (!dock.frameJoin)
                return dock.freeR
            if (dock.joinFullSpan)
                return 0
            if ((dock.joinBottom && !dock.joinLeft) || (dock.joinTop && dock.joinLeft) || dock.joinLeftEdge)
                return 0
            return dock.freeR
        }
        bottomRightRadius: {
            if (!dock.frameJoin)
                return dock.freeR
            if (dock.joinFullSpan)
                return 0
            if ((dock.joinBottom && !dock.joinRight) || (dock.joinTop && dock.joinRight) || dock.joinRightEdge)
                return 0
            return dock.freeR
        }
        color: dock.frameJoin ? ThemeManager.frameFillColor : ThemeManager.dockFillColor
        border.width: dock.frameJoin ? 0 : (ThemeManager.effectiveDockShowBorder ? ThemeManager.effectiveDockBorderWidth : 0)
        border.color: ThemeManager.chromeBorderColor
        anchors.left: parent.left
        anchors.top: parent.top
        width: Settings.dockSpanFullWidth ? parent.width : (dock.isHorizontal ? contentRow.implicitWidth + dock.padding * 2 : dock.iconSize + 20)
        height: Settings.dockSpanFullWidth ? parent.height : (dock.isHorizontal ? dock.iconSize + 20 : contentColumn.implicitHeight + dock.padding * 2)
        anchors.leftMargin: {
            if (Settings.dockSpanFullWidth || !dock.isHorizontal)
                return 0
            if (dock.alignment === "start")
                return 0
            if (dock.alignment === "end")
                return Math.max(0, parent.width - width)
            return Math.max(0, Math.round((parent.width - width) / 2))
        }
        anchors.topMargin: {
            if (Settings.dockSpanFullWidth || dock.isHorizontal)
                return 0
            if (dock.alignment === "start")
                return 0
            if (dock.alignment === "end")
                return Math.max(0, parent.height - height)
            return Math.max(0, Math.round((parent.height - height) / 2))
        }
    }

    FrameJoins {
        x: background.x - dock.joinR
        y: background.y - dock.joinR
        z: 1
        joinR: dock.joinR
        contentW: background.width
        contentH: background.height
        joinTop: dock.joinTop
        joinBottom: dock.joinBottom
        joinLeft: dock.joinLeft
        joinRight: dock.joinRight
        joinLeftEdge: dock.joinLeftEdge
        joinRightEdge: dock.joinRightEdge
        joinFullSpan: dock.joinFullSpan
    }
    }

    component PinnedApp: Item {
        id: dockIcon
        required property var modelData
        width: dock.iconSize
        height: dock.iconSize

        scale: mouseArea.pressed ? ThemeManager.iconPressScale : (mouseArea.containsMouse ? ThemeManager.iconHoverScale : 1.0)
        Behavior on scale {
            SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
        }

        AppIcon {
            anchors.centerIn: parent
            iconName: modelData.icon || ""
            pixelSize: dock.iconSize - 8
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    const next = Settings.dockPinnedApps.filter(a => a.desktopId !== modelData.desktopId)
                    Settings.dockPinnedApps = next
                    Settings.save()
                    return
                }
                const cmd = modelData.exec || modelData.command
                if (!cmd)
                    return
                if (modelData.terminal)
                    Quickshell.execDetached([ThemeManager.terminal, "-e", "sh", "-c", cmd])
                else
                    Quickshell.execDetached(["sh", "-c", cmd])
            }
        }
    }

    Row {
        id: contentRow
        parent: chromeHost
        visible: dock.isHorizontal
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: {
            if (dock.alignment === "start")
                return dock.padding
            if (dock.alignment === "end")
                return Math.max(dock.padding, parent.width - width - dock.padding)
            return Math.max(dock.padding, Math.round((parent.width - width) / 2))
        }
        spacing: dock.itemSpacing

        Repeater {
            model: Settings.dockPinnedApps
            PinnedApp {}
        }

        Rectangle {
            width: 1
            height: dock.iconSize * 0.55
            anchors.verticalCenter: parent.verticalCenter
            color: ThemeManager.overlay(0.15)
        }

        DockUtilityButton {
            iconSize: dock.iconSize * 0.7
            anchors.verticalCenter: parent.verticalCenter
            glyph: "󰐕"
            onClicked: dock.appPickerRequested()
        }

        DockUtilityButton {
            visible: Settings.dockShowSettingsIcon
            iconSize: dock.iconSize * 0.7
            anchors.verticalCenter: parent.verticalCenter
            glyph: "󰒓"
            onClicked: dock.settingsRequested()
        }

        DockUtilityButton {
            visible: Settings.dockShowTrashIcon
            iconSize: dock.iconSize * 0.7
            anchors.verticalCenter: parent.verticalCenter
            glyph: "\uf1f8"
            onClicked: dock.trashRequested()
        }
    }

    Column {
        id: contentColumn
        parent: chromeHost
        visible: !dock.isHorizontal
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: {
            if (dock.alignment === "start")
                return dock.padding
            if (dock.alignment === "end")
                return Math.max(dock.padding, parent.height - height - dock.padding)
            return Math.max(dock.padding, Math.round((parent.height - height) / 2))
        }
        spacing: dock.itemSpacing

        Repeater {
            model: Settings.dockPinnedApps
            PinnedApp {}
        }

        Rectangle {
            width: dock.iconSize * 0.55
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: ThemeManager.overlay(0.15)
        }

        DockUtilityButton {
            iconSize: dock.iconSize * 0.7
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: "󰐕"
            onClicked: dock.appPickerRequested()
        }

        DockUtilityButton {
            visible: Settings.dockShowSettingsIcon
            iconSize: dock.iconSize * 0.7
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: "󰒓"
            onClicked: dock.settingsRequested()
        }

        DockUtilityButton {
            visible: Settings.dockShowTrashIcon
            iconSize: dock.iconSize * 0.7
            anchors.horizontalCenter: parent.horizontalCenter
            glyph: "\uf1f8"
            onClicked: dock.trashRequested()
        }
    }
}

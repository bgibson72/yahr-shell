import QtQuick
import QtQuick.Layouts
import "../.."

// Visual option picker for Settings → Bar: each choice is a mini desktop
// mock with the bar styled for that option, and a label chip underneath.
ColumnLayout {
    id: root

    property string title: ""
    property string help: ""
    property var options: []
    property string current: ""
    property var disabledIds: []
    signal picked(string id)

    Layout.fillWidth: true
    spacing: 8

    Text {
        visible: root.title.length > 0
        text: root.title
        color: ThemeManager.fgPrimary
        font.family: ThemeManager.uiFont
        font.pixelSize: 13
    }

    Text {
        visible: root.help.length > 0
        Layout.fillWidth: true
        text: root.help
        color: ThemeManager.fgTertiary
        font.family: ThemeManager.uiFont
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    Flow {
        Layout.fillWidth: true
        spacing: 10

        Repeater {
            model: root.options

            Item {
                id: tile
                required property var modelData

                readonly property bool selected: root.current === modelData.id
                readonly property bool tileDisabled: root.disabledIds.indexOf(modelData.id) !== -1
                readonly property string preview: modelData.preview || modelData.id

                width: tileCol.implicitWidth
                height: tileCol.implicitHeight
                opacity: tile.tileDisabled ? 0.4 : 1
                scale: !tile.tileDisabled && tileMouse.pressed
                    ? ThemeManager.bouncePressScale
                    : (!tile.tileDisabled && tileMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                Behavior on scale {
                    SpringAnimation {
                        spring: ThemeManager.bounceSpring
                        damping: ThemeManager.bounceDamping
                        mass: ThemeManager.bounceMass
                    }
                }

                Column {
                    id: tileCol
                    spacing: 8

                // Mini desktop mock
                Rectangle {
                    id: desk
                    width: 150
                    height: 96
                    radius: 10
                    border.width: tile.selected ? 2 : 1
                    border.color: tile.selected ? ThemeManager.accentBlue : ThemeManager.overlay(0.14)
                    clip: true

                    // Soft wallpaper wash
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(
                                ThemeManager.accentBlue.r,
                                ThemeManager.accentBlue.g,
                                ThemeManager.accentBlue.b,
                                ThemeManager.isLightTheme ? 0.18 : 0.28
                            )
                        }
                        GradientStop {
                            position: 0.55
                            color: ThemeManager.surface0
                        }
                        GradientStop {
                            position: 1.0
                            color: ThemeManager.bgMantle
                        }
                    }

                    // Fake floating window
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: {
                            const p = tile.preview
                            if (p === "position-bottom")
                                return -6
                            if (p === "position-top")
                                return 6
                            return 4
                        }
                        width: 72
                        height: 44
                        radius: 6
                        color: Qt.rgba(
                            ThemeManager.surface1.r,
                            ThemeManager.surface1.g,
                            ThemeManager.surface1.b,
                            0.92
                        )
                        border.width: 1
                        border.color: ThemeManager.overlay(0.12)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 8
                            radius: 6
                            color: Qt.rgba(
                                ThemeManager.surface2.r,
                                ThemeManager.surface2.g,
                                ThemeManager.surface2.b,
                                0.95
                            )
                        }
                    }

                    // Bar host
                    Item {
                        id: barHost
                        anchors.left: parent.left
                        anchors.right: parent.right
                        readonly property bool barBottom: tile.preview === "position-bottom"
                        readonly property bool floating: {
                            const p = tile.preview
                            return p === "mode-floating"
                                || p === "style-islands"
                                || p === "size-normal"
                                || p === "size-large"
                                || p === "fill-solid"
                                || p === "fill-transparent"
                                || p === "workspace-dots"
                                || p === "workspace-numbers"
                                || p === "border-on"
                                || p === "border-off"
                                || p === "position-top"
                                || p === "position-bottom"
                        }
                        readonly property bool docked: tile.preview === "mode-docked"
                        readonly property bool islands: tile.preview === "style-islands"
                        readonly property bool large: tile.preview === "size-large"
                        readonly property bool transparent: tile.preview === "fill-transparent"
                        readonly property bool forceBorder: tile.preview === "border-on"
                        readonly property bool forceNoBorder: tile.preview === "border-off"
                        readonly property int barH: {
                            if (tile.preview === "size-large")
                                return 18
                            if (tile.preview === "size-normal")
                                return 11
                            return 13
                        }
                        readonly property int edgePad: {
                            if (barHost.docked)
                                return 0
                            if (tile.preview.indexOf("position-") === 0)
                                return 5
                            if (barHost.islands)
                                return 5
                            return 5
                        }

                        height: barHost.barH
                        anchors.leftMargin: barHost.docked ? 0 : barHost.edgePad
                        anchors.rightMargin: barHost.docked ? 0 : barHost.edgePad
                        anchors.top: barHost.barBottom ? undefined : parent.top
                        anchors.bottom: barHost.barBottom ? parent.bottom : undefined
                        anchors.topMargin: barHost.barBottom ? 0 : (barHost.docked ? 0 : barHost.edgePad)
                        anchors.bottomMargin: barHost.barBottom ? (barHost.docked ? 0 : barHost.edgePad) : 0

                        // Single bar
                        Rectangle {
                            id: singleBar
                            visible: !barHost.islands
                            anchors.fill: parent
                            radius: barHost.docked ? 0 : (barHost.large ? 5 : 4)
                            color: barHost.transparent
                                ? Qt.rgba(ThemeManager.surface1.r, ThemeManager.surface1.g, ThemeManager.surface1.b, 0.42)
                                : ThemeManager.surface1
                            border.width: barHost.forceBorder ? 1
                                : (barHost.forceNoBorder ? 0 : 0)
                            border.color: ThemeManager.accentBlue

                            // Left accent mark (arch)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(4, singleBar.height - 6)
                                height: width
                                radius: width / 2
                                color: ThemeManager.accentBlue
                            }

                            // Workspace indicators
                            Row {
                                id: wsRow
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: tile.preview === "workspace-numbers" ? 3 : 4
                                visible: tile.preview === "workspace-dots"
                                    || tile.preview === "workspace-numbers"
                                    || tile.preview.indexOf("position-") === 0
                                    || tile.preview.indexOf("size-") === 0
                                    || tile.preview.indexOf("mode-") === 0
                                    || tile.preview.indexOf("fill-") === 0
                                    || tile.preview.indexOf("border-") === 0
                                    || tile.preview === "style-single"

                                Repeater {
                                    model: 3
                                    Item {
                                        width: tile.preview === "workspace-numbers" ? 10 : 5
                                        height: tile.preview === "workspace-numbers" ? 10 : 5

                                        Rectangle {
                                            anchors.centerIn: parent
                                            visible: tile.preview !== "workspace-numbers"
                                            width: index === 0 ? 6 : 5
                                            height: width
                                            radius: width / 2
                                            color: index === 0
                                                ? ThemeManager.accentBlue
                                                : ThemeManager.fgTertiary
                                            opacity: index === 0 ? 1 : 0.55
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: tile.preview === "workspace-numbers"
                                            text: String(index + 1)
                                            color: index === 0
                                                ? ThemeManager.accentBlue
                                                : ThemeManager.fgTertiary
                                            font.family: ThemeManager.uiFont
                                            font.pixelSize: 8
                                            font.weight: index === 0 ? Font.DemiBold : Font.Normal
                                        }
                                    }
                                }
                            }

                            // Right tray dots
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: ThemeManager.fgTertiary
                                        opacity: 0.55
                                    }
                                }
                            }
                        }

                        // Island pills
                        Item {
                            visible: barHost.islands
                            anchors.fill: parent

                            Rectangle {
                                id: leftIsle
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: parent.height
                                radius: 4
                                color: ThemeManager.surface1
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: index === 0 ? ThemeManager.accentBlue : ThemeManager.fgTertiary
                                            opacity: index === 0 ? 1 : 0.55
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                height: parent.height
                                radius: 4
                                color: ThemeManager.surface1
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 4
                                    radius: 2
                                    color: ThemeManager.fgTertiary
                                    opacity: 0.7
                                }
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40
                                height: parent.height
                                radius: 4
                                color: ThemeManager.surface1
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: ThemeManager.fgTertiary
                                            opacity: 0.55
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Label chip / button under the mock
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(desk.width * 0.72, labelText.implicitWidth + 18)
                    height: 28
                    radius: 8
                    color: tile.selected ? ThemeManager.accentBlue : ThemeManager.surface1

                    Text {
                        id: labelText
                        anchors.centerIn: parent
                        text: tile.modelData.label
                        color: tile.selected ? ThemeManager.bgBase : ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                        font.weight: tile.selected ? Font.DemiBold : Font.Normal
                    }
                }
                } // tileCol

                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    enabled: !tile.tileDisabled
                    hoverEnabled: !tile.tileDisabled
                    cursorShape: tile.tileDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.picked(tile.modelData.id)
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import "../.."

// Visual option picker for Settings → Bar: each choice is a mini desktop
// mock with the bar styled for that option, and a label chip underneath.
// Tiles share the card width evenly so the row stays centered with no
// large empty band on the trailing edge.
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

    RowLayout {
        id: row
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        spacing: 12

        Repeater {
            model: root.options

            Item {
                id: tile
                required property var modelData

                readonly property bool selected: root.current === modelData.id
                readonly property bool tileDisabled: root.disabledIds.indexOf(modelData.id) !== -1
                readonly property string preview: modelData.preview || modelData.id
                readonly property real deskW: width
                readonly property real deskH: Math.max(88, Math.round(deskW * 0.62))
                readonly property real px: Math.max(0.75, deskW / 150)

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 110
                Layout.preferredHeight: tileCol.implicitHeight
                implicitHeight: tileCol.implicitHeight

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

                ColumnLayout {
                    id: tileCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 8

                    // Mini desktop mock — fills the tile width
                    Rectangle {
                        id: desk
                        Layout.fillWidth: true
                        Layout.preferredHeight: tile.deskH
                        radius: Math.max(8, Math.round(10 * tile.px))
                        border.width: tile.selected ? 2 : 1
                        border.color: tile.selected ? ThemeManager.accentBlue : ThemeManager.overlay(0.14)
                        clip: true

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
                                    return Math.round(-6 * tile.px)
                                if (p === "position-top")
                                    return Math.round(6 * tile.px)
                                return Math.round(4 * tile.px)
                            }
                            width: Math.round(desk.width * 0.48)
                            height: Math.round(desk.height * 0.46)
                            radius: Math.max(4, Math.round(6 * tile.px))
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
                                height: Math.max(6, Math.round(parent.height * 0.18))
                                radius: parent.radius
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
                            readonly property bool docked: tile.preview === "mode-docked"
                            readonly property bool islands: tile.preview === "style-islands"
                            readonly property bool large: tile.preview === "size-large"
                            readonly property bool transparent: tile.preview === "fill-transparent"
                            readonly property bool forceBorder: tile.preview === "border-on"
                            readonly property bool forceNoBorder: tile.preview === "border-off"
                            readonly property int barH: {
                                if (tile.preview === "size-large")
                                    return Math.max(14, Math.round(desk.height * 0.20))
                                if (tile.preview === "size-normal")
                                    return Math.max(10, Math.round(desk.height * 0.12))
                                return Math.max(11, Math.round(desk.height * 0.145))
                            }
                            readonly property int edgePad: barHost.docked ? 0 : Math.max(4, Math.round(5 * tile.px))

                            height: barHost.barH
                            anchors.leftMargin: barHost.edgePad
                            anchors.rightMargin: barHost.edgePad
                            anchors.top: barHost.barBottom ? undefined : parent.top
                            anchors.bottom: barHost.barBottom ? parent.bottom : undefined
                            anchors.topMargin: barHost.barBottom ? 0 : barHost.edgePad
                            anchors.bottomMargin: barHost.barBottom ? barHost.edgePad : 0

                            // Single bar
                            Rectangle {
                                id: singleBar
                                visible: !barHost.islands
                                anchors.fill: parent
                                radius: barHost.docked ? 0 : Math.max(3, Math.round((barHost.large ? 5 : 4) * tile.px))
                                color: barHost.transparent
                                    ? Qt.rgba(ThemeManager.surface1.r, ThemeManager.surface1.g, ThemeManager.surface1.b, 0.42)
                                    : ThemeManager.surface1
                                border.width: barHost.forceBorder ? Math.max(1, Math.round(tile.px)) : 0
                                border.color: ThemeManager.accentBlue

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Math.max(4, Math.round(5 * tile.px))
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(4, singleBar.height - Math.round(6 * tile.px))
                                    height: width
                                    radius: width / 2
                                    color: ThemeManager.accentBlue
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Math.max(14, Math.round(18 * tile.px))
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: tile.preview === "workspace-numbers"
                                        ? Math.max(2, Math.round(3 * tile.px))
                                        : Math.max(3, Math.round(4 * tile.px))
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
                                            width: tile.preview === "workspace-numbers"
                                                ? Math.max(8, Math.round(10 * tile.px))
                                                : Math.max(4, Math.round(5 * tile.px))
                                            height: width

                                            Rectangle {
                                                anchors.centerIn: parent
                                                visible: tile.preview !== "workspace-numbers"
                                                width: index === 0
                                                    ? Math.max(5, Math.round(6 * tile.px))
                                                    : Math.max(4, Math.round(5 * tile.px))
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
                                                font.pixelSize: Math.max(7, Math.round(8 * tile.px))
                                                font.weight: index === 0 ? Font.DemiBold : Font.Normal
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Math.max(4, Math.round(5 * tile.px))
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Math.max(2, Math.round(3 * tile.px))
                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            width: Math.max(3, Math.round(4 * tile.px))
                                            height: width
                                            radius: width / 2
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
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(parent.width * 0.30)
                                    height: parent.height
                                    radius: Math.max(3, Math.round(4 * tile.px))
                                    color: ThemeManager.surface1
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Math.max(2, Math.round(3 * tile.px))
                                        Repeater {
                                            model: 3
                                            Rectangle {
                                                width: Math.max(3, Math.round(4 * tile.px))
                                                height: width
                                                radius: width / 2
                                                color: index === 0 ? ThemeManager.accentBlue : ThemeManager.fgTertiary
                                                opacity: index === 0 ? 1 : 0.55
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(parent.width * 0.22)
                                    height: parent.height
                                    radius: Math.max(3, Math.round(4 * tile.px))
                                    color: ThemeManager.surface1
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.round(parent.width * 0.35)
                                        height: Math.max(3, Math.round(4 * tile.px))
                                        radius: height / 2
                                        color: ThemeManager.fgTertiary
                                        opacity: 0.7
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(parent.width * 0.27)
                                    height: parent.height
                                    radius: Math.max(3, Math.round(4 * tile.px))
                                    color: ThemeManager.surface1
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Math.max(2, Math.round(3 * tile.px))
                                        Repeater {
                                            model: 3
                                            Rectangle {
                                                width: Math.max(3, Math.round(4 * tile.px))
                                                height: width
                                                radius: width / 2
                                                color: ThemeManager.fgTertiary
                                                opacity: 0.55
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Label chip under the mock — full tile width
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 8
                        color: tile.selected ? ThemeManager.accentBlue : ThemeManager.surface1

                        Text {
                            anchors.centerIn: parent
                            text: tile.modelData.label
                            color: tile.selected ? ThemeManager.bgBase : ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            font.weight: tile.selected ? Font.DemiBold : Font.Normal
                        }
                    }
                }

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

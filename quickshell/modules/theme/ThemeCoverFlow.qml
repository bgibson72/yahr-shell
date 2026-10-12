import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../components"
import "../.."

// =============================================================================
// ThemeCoverFlow — Cover Flow theme browser for Settings → Theme
//
// Same Cover Flow interaction as WallpaperPicker, but sized to live inside the
// Settings panel (no full-screen scrim / overlay). Tap the center cover (or
// press Enter while focused) to apply; right-click a custom theme to delete.
// =============================================================================
Item {
    id: root

    property var themes: []
    property int currentIndex: 0

    signal applyRequested(var theme)
    signal deleteRequested(var theme)

    implicitHeight: 300
    Layout.fillWidth: true
    Layout.preferredHeight: 300

    readonly property var currentTheme: {
        if (!themes || themes.length === 0 || currentIndex < 0 || currentIndex >= themes.length)
            return null
        return themes[currentIndex]
    }

    onThemesChanged: root.syncIndexToActive()

    function syncIndexToActive() {
        if (!themes || themes.length === 0) {
            coverFlow.currentIndex = 0
            return
        }
        for (let i = 0; i < themes.length; i++) {
            if (themes[i].active) {
                coverFlow.currentIndex = i
                return
            }
        }
        if (coverFlow.currentIndex >= themes.length)
            coverFlow.currentIndex = 0
    }

    function applyCurrent() {
        const theme = root.currentTheme
        if (!theme)
            return
        root.applyRequested(theme)
    }

    focus: true
    Keys.onLeftPressed: coverFlow.decrementCurrentIndex()
    Keys.onRightPressed: coverFlow.incrementCurrentIndex()
    Keys.onReturnPressed: root.applyCurrent()
    Keys.onEnterPressed: root.applyCurrent()

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.themes.length > 0
                    ? `${coverFlow.currentIndex + 1} / ${root.themes.length}`
                    : "No themes"
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: !!root.currentTheme
                text: root.currentTheme
                    ? (root.currentTheme.custom ? "custom · right-click to delete" : (root.currentTheme.mode || "dark"))
                    : ""
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 11
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                z: 20
                width: 36
                height: 36
                radius: 18
                visible: root.themes.length > 1
                opacity: coverFlow.currentIndex > 0 ? 1 : 0.35
                color: Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.92)
                border.width: 1
                border.color: ThemeManager.overlay(0.14)

                Text {
                    anchors.centerIn: parent
                    text: "\uf053"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: ThemeManager.fgPrimary
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: coverFlow.currentIndex > 0
                    onTapped: coverFlow.decrementCurrentIndex()
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                z: 20
                width: 36
                height: 36
                radius: 18
                visible: root.themes.length > 1
                opacity: coverFlow.currentIndex < root.themes.length - 1 ? 1 : 0.35
                color: Qt.rgba(ThemeManager.surface0.r, ThemeManager.surface0.g, ThemeManager.surface0.b, 0.92)
                border.width: 1
                border.color: ThemeManager.overlay(0.14)

                Text {
                    anchors.centerIn: parent
                    text: "\uf054"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: ThemeManager.fgPrimary
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: coverFlow.currentIndex < root.themes.length - 1
                    onTapped: coverFlow.incrementCurrentIndex()
                }
            }

            PathView {
                id: coverFlow
                anchors.fill: parent
                anchors.leftMargin: 44
                anchors.rightMargin: 44
                model: root.themes
                pathItemCount: Math.min(7, Math.max(3, root.themes.length))
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                flickDeceleration: 120
                movementDirection: PathView.Positive
                clip: false

                onCurrentIndexChanged: root.currentIndex = currentIndex

                path: Path {
                    startX: 0
                    startY: coverFlow.height * 0.46

                    PathAttribute { name: "coverZ"; value: 0 }
                    PathAttribute { name: "coverAngle"; value: 58 }
                    PathAttribute { name: "coverScale"; value: 0.58 }
                    PathAttribute { name: "coverOpacity"; value: 0.38 }

                    PathLine {
                        x: coverFlow.width * 0.5
                        y: coverFlow.height * 0.46
                    }
                    PathAttribute { name: "coverZ"; value: 100 }
                    PathAttribute { name: "coverAngle"; value: 0 }
                    PathAttribute { name: "coverScale"; value: 1.0 }
                    PathAttribute { name: "coverOpacity"; value: 1.0 }

                    PathLine {
                        x: coverFlow.width
                        y: coverFlow.height * 0.46
                    }
                    PathAttribute { name: "coverZ"; value: 0 }
                    PathAttribute { name: "coverAngle"; value: -58 }
                    PathAttribute { name: "coverScale"; value: 0.58 }
                    PathAttribute { name: "coverOpacity"; value: 0.38 }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        // While the pointer is over the Cover Flow, consume the
                        // wheel so Settings' outer Flickable does not scroll away.
                        const dx = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                            ? event.angleDelta.x
                            : event.angleDelta.y
                        if (dx > 0)
                            coverFlow.decrementCurrentIndex()
                        else if (dx < 0)
                            coverFlow.incrementCurrentIndex()
                        event.accepted = true
                    }
                }

                delegate: Item {
                    id: cover
                    required property var modelData
                    required property int index

                    width: Math.min(280, coverFlow.width * 0.42)
                    height: Math.min(170, coverFlow.height * 0.72)
                    z: PathView.coverZ
                    scale: PathView.coverScale
                    opacity: PathView.coverOpacity
                    property bool isCenter: PathView.isCurrentItem

                    readonly property color chipBg: cover.modelData.bgBase || ThemeManager.surface1
                    readonly property color chipFg: cover.modelData.fgPrimary || ThemeManager.fgPrimary
                    readonly property color chipAccent: cover.modelData.accentBlue || ThemeManager.accentBlue
                    readonly property color chipBorder: cover.modelData.border0 || ThemeManager.border0
                    readonly property color chipTertiary: cover.modelData.fgTertiary || cover.chipFg

                    transform: Rotation {
                        origin.x: cover.width / 2
                        origin.y: cover.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: PathView.coverAngle
                    }

                    Rectangle {
                        id: plate
                        anchors.fill: parent
                        radius: 14
                        color: cover.chipBg
                        border.width: cover.isCenter ? 2 : 1
                        border.color: cover.isCenter
                            ? (cover.modelData.active ? cover.chipAccent : ThemeManager.accentBlue)
                            : ThemeManager.overlay(0.16)

                        layer.enabled: cover.isCenter
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(
                                ThemeManager.accentBlue.r,
                                ThemeManager.accentBlue.g,
                                ThemeManager.accentBlue.b,
                                0.45
                            )
                            shadowBlur: 0.65
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 6
                        }

                        // Wallpaper-like color composition
                        Item {
                            id: art
                            anchors.fill: parent
                            anchors.margins: plate.border.width
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.max(0, 14 - plate.border.width)
                                color: cover.chipBg
                            }

                            // Soft accent wash
                            Rectangle {
                                width: parent.width * 0.72
                                height: parent.height * 0.85
                                x: parent.width * 0.38
                                y: -parent.height * 0.12
                                radius: width * 0.45
                                rotation: -18
                                color: Qt.rgba(cover.chipAccent.r, cover.chipAccent.g, cover.chipAccent.b, 0.55)
                            }

                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height * 0.7
                                x: -parent.width * 0.08
                                y: parent.height * 0.45
                                radius: width * 0.4
                                rotation: 22
                                color: Qt.rgba(cover.chipBorder.r, cover.chipBorder.g, cover.chipBorder.b, 0.55)
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 12
                                spacing: 8

                                ThemePreview {
                                    width: Math.min(parent.width, 150)
                                    height: 16
                                    themeId: cover.modelData.id || ""
                                }

                                Text {
                                    width: parent.width
                                    text: cover.modelData.name || cover.modelData.id || "Theme"
                                    color: cover.chipFg
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: cover.isCenter ? 15 : 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: 6
                                    visible: cover.modelData.custom || cover.modelData.active

                                    Rectangle {
                                        visible: cover.modelData.custom
                                        width: customLabel.implicitWidth + 10
                                        height: 16
                                        radius: 4
                                        color: Qt.rgba(cover.chipFg.r, cover.chipFg.g, cover.chipFg.b, 0.14)
                                        Text {
                                            id: customLabel
                                            anchors.centerIn: parent
                                            text: "custom"
                                            color: cover.chipTertiary
                                            font.family: ThemeManager.uiFont
                                            font.pixelSize: 10
                                        }
                                    }

                                    Rectangle {
                                        visible: cover.modelData.active
                                        width: activeLabel.implicitWidth + 10
                                        height: 16
                                        radius: 4
                                        color: Qt.rgba(cover.chipAccent.r, cover.chipAccent.g, cover.chipAccent.b, 0.28)
                                        Text {
                                            id: activeLabel
                                            anchors.centerIn: parent
                                            text: "active"
                                            color: cover.chipAccent
                                            font.family: ThemeManager.uiFont
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            if (cover.isCenter)
                                root.applyCurrent()
                            else
                                coverFlow.currentIndex = cover.index
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            if (cover.modelData.custom)
                                root.deleteRequested(cover.modelData)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.themes.length === 0
                text: "No themes for this mode"
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 13
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.currentTheme ? (root.currentTheme.name || root.currentTheme.id) : ""
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
                Layout.maximumWidth: root.width - 40
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Scroll sideways or use arrows · tap center cover to apply"
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 11
                opacity: 0.9
            }
        }
    }
}

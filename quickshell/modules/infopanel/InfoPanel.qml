import QtQuick
import QtQuick.Layouts
import "../../components"
import "../.."

// Combined Calendar/Weather/System info panel, tabbed like the old app so
// only one popup needs to be summoned from the bar.
Panel {
    id: root
    width: 900
    height: 640
    property bool isVisible: false
    property int currentTab: 0

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    readonly property var tabs: [
        { label: "Calendar", glyph: "\uf073" },
        { label: "Weather", glyph: "\ue302" },
        { label: "System", glyph: "\uf108" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: Qt.rgba(1, 1, 1, 0.07)
            radius: 10
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

            Row {
                id: tabBarRow
                anchors.fill: parent
                anchors.margins: 5
                spacing: 5

                property real tabWidth: (width - spacing * 2) / 3

                Repeater {
                    model: root.tabs

                    Rectangle {
                        id: tabButton
                        required property var modelData
                        required property int index
                        width: tabBarRow.tabWidth
                        height: parent.height
                        radius: 8
                        color: root.currentTab === index ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.30) : "transparent"
                        border.width: root.currentTab === index ? 1 : 0
                        border.color: Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.55)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        scale: tabMouse.pressed ? ThemeManager.bouncePressScale : (tabMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
                        Behavior on scale {
                            SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = tabButton.index
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: tabButton.modelData.glyph
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: ThemeManager.accentBlue
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: tabButton.modelData.label
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: ThemeManager.fgPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            CalendarTab {
                anchors.fill: parent
                visible: root.currentTab === 0
                active: root.isVisible && root.currentTab === 0
            }
            WeatherTab {
                anchors.fill: parent
                visible: root.currentTab === 1
                active: root.isVisible && root.currentTab === 1
            }
            SystemTab {
                anchors.fill: parent
                visible: root.currentTab === 2
                active: root.isVisible && root.currentTab === 2
            }
        }
    }
}

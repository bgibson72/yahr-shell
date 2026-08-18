import QtQuick
import ".."

// Compact "icon + title + big value" card with a sparkline history and two
// footer stats, used for the System tab's CPU/memory/temperature readouts.
Rectangle {
    id: root

    property string glyph: ""
    property string title: ""
    property string valueText: "0%"
    property color valueColor: ThemeManager.accentBlue
    property var sparklineValues: []
    property real sparklineMax: 100
    property string footerLeft: ""
    property string footerRight: ""

    color: Qt.rgba(1, 1, 1, 0.07)
    radius: 12
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.10)

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Row {
            width: parent.width
            spacing: 8

            Text {
                text: root.glyph
                font.family: "Symbols Nerd Font"
                font.pixelSize: 18
                color: root.valueColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.title
                font.family: ThemeManager.uiFont
                font.pixelSize: ThemeManager.fontSizeNormal
                font.weight: Font.Bold
                color: ThemeManager.fgPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: Math.max(0, parent.width - 210); height: 1 }

            Text {
                text: root.valueText
                font.family: ThemeManager.uiFont
                font.pixelSize: 22
                font.weight: Font.Bold
                color: root.valueColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        SparklineChart {
            width: parent.width
            height: parent.height - 80
            values: root.sparklineValues
            maxValue: root.sparklineMax
            color: root.valueColor
            fillColor: Qt.rgba(root.valueColor.r, root.valueColor.g, root.valueColor.b, 0.2)
        }

        Row {
            width: parent.width
            spacing: 16

            Text {
                text: root.footerLeft
                font.family: ThemeManager.uiFont
                font.pixelSize: ThemeManager.fontSizeSmall
                color: ThemeManager.fgSecondary
            }

            Text {
                text: root.footerRight
                font.family: ThemeManager.uiFont
                font.pixelSize: ThemeManager.fontSizeSmall
                color: ThemeManager.fgSecondary
            }
        }
    }
}

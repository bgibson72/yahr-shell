import QtQuick
import ".."

// "Icon + title + big value" card. Full size includes a sparkline and two
// footer stats; compact mode is a short tile for the combined info panel.
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
    property bool compact: false

    color: ThemeManager.cardColor
    radius: 12

    Column {
        visible: !root.compact
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Row {
            width: parent.width
            spacing: 8

            Text {
                text: root.glyph
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
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
                font.pixelSize: 18
                font.weight: Font.Bold
                color: root.valueColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        SparklineChart {
            width: parent.width
            height: parent.height - 64
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

    Column {
        visible: root.compact
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        Row {
            spacing: 6

            Text {
                text: root.glyph
                font.family: "Symbols Nerd Font"
                font.pixelSize: 13
                color: root.valueColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.title
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: ThemeManager.fgSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            text: root.valueText
            font.family: ThemeManager.uiFont
            font.pixelSize: 22
            font.weight: Font.Bold
            color: root.valueColor
        }

        Text {
            text: [root.footerLeft, root.footerRight].filter(s => s).join("  ·  ")
            font.family: ThemeManager.uiFont
            font.pixelSize: 11
            color: ThemeManager.fgTertiary
            elide: Text.ElideRight
            width: parent.width
        }
    }
}

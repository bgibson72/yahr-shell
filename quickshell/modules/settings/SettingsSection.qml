import QtQuick
import QtQuick.Layouts
import "../.."

// Labeled group within a Settings tab. The small-caps title sits on the
// content background; each SettingsCard child is one section base card that
// holds SettingsSubcard option panels (card-on-card).
ColumnLayout {
    id: root
    default property alias content: cards.data
    property string title: ""

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop
    spacing: 8

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: root.title
        color: ThemeManager.fgTertiary
        font.family: ThemeManager.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.3
        visible: root.title.length > 0
    }

    ColumnLayout {
        id: cards
        Layout.fillWidth: true
        spacing: 10
    }
}

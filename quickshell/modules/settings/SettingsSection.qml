import QtQuick
import QtQuick.Layouts
import "../.."

// Labeled group of related settings within a Settings tab. The small-caps
// title sits directly on the content area's own background; the rounded
// card below it (a touch lighter than the panel) holds the option rows.
Item {
    id: root
    default property alias content: body.data
    property string title: ""

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop
    implicitHeight: titleLabel.implicitHeight + 8 + card.implicitHeight

    Text {
        id: titleLabel
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.top: parent.top
        text: root.title
        color: ThemeManager.fgTertiary
        font.family: ThemeManager.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.3
    }

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleLabel.bottom
        anchors.topMargin: 8
        // body is anchored (not managed by a Layout), so its own
        // implicitHeight reflects only its content -- add the 16px top +
        // 16px bottom margins back in here, or the card falls short and its
        // last row of content spills past the background.
        implicitHeight: body.implicitHeight + 32
        height: implicitHeight
        color: ThemeManager.cardColor
        radius: ThemeManager.cardRadius

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 10
        }
    }
}

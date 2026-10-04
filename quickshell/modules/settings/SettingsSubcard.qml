import QtQuick
import QtQuick.Layouts
import "../.."

// Inset panel for one subsetting group inside a SettingsCard (card-on-card).
Rectangle {
    id: root
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 24
    height: implicitHeight
    radius: Math.max(6, ThemeManager.cardRadius - 4)
    color: ThemeManager.isLightTheme
        ? Qt.rgba(0, 0, 0, 0.06)
        : Qt.rgba(0, 0, 0, 0.22)
    opacity: enabled ? 1.0 : 0.4

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
    }
}

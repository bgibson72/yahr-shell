import QtQuick
import QtQuick.Layouts
import "../.."

// Rounded card body for one group of related options inside a SettingsSection.
Rectangle {
    id: root
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 32
    height: implicitHeight
    color: ThemeManager.cardColor
    radius: ThemeManager.cardRadius
    opacity: enabled ? 1.0 : 0.4

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        // Room between nested SettingsSubcards (and flat rows in single-group cards).
        spacing: 10
    }
}

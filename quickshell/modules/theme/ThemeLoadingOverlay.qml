import QtQuick
import "../.."

// Full-screen busy overlay shown while `yahr-theme apply` is running, so the
// user gets feedback instead of a UI that looks frozen for the brief moment
// themes/wallpapers/configs are being rewritten on disk.
Item {
    id: root

    property bool isVisible: false
    property string themeName: ""

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Item {
                width: 56
                height: 56
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    radius: 24
                    color: "transparent"
                    border.width: 5
                    border.color: ThemeManager.accentBlue
                    opacity: 0.25
                }

                Rectangle {
                    id: spinnerArc
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    radius: 24
                    color: "transparent"
                    border.width: 5
                    border.color: ThemeManager.accentBlue
                    clip: true

                    Rectangle {
                        width: parent.width
                        height: parent.height / 2
                        color: "transparent"
                    }

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                        running: root.isVisible
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Applying Theme"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: ThemeManager.fgPrimary
                }

                Text {
                    visible: root.themeName !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.themeName
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeNormal
                    color: ThemeManager.accentBlue
                }
            }
        }

        // Safety net: never leave the shell stuck behind an overlay if the
        // apply process hangs or its exit signal is missed for some reason.
        Timer {
            interval: 5000
            running: root.isVisible
            repeat: false
            onTriggered: root.isVisible = false
        }
    }
}

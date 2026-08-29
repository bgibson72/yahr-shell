import QtQuick
import QtQuick.Layouts
import "../../components"
import "../.."

// Calendar, weather, and system stats in one popup from the bar clock.
Panel {
    id: root
    width: 720
    height: 500
    frameJoin: "center"

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            CalendarTab {
                Layout.fillHeight: true
                Layout.preferredWidth: (parent.width - 10) * 0.55
                active: root.isVisible
            }

            WeatherTab {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.isVisible
            }
        }

        SystemTab {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            active: root.isVisible
        }
    }
}

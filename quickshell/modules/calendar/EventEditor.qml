import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "../.."

Rectangle {
    id: editor
    color: ThemeManager.overlay(0.45)
    visible: open
    radius: 0

    property bool open: false
    property bool creating: true
    property bool writable: true
    property string uid: ""
    property string calendarId: "personal"
    property var calendars: []
    property string titleText: ""
    property string locationText: ""
    property string startDate: ""
    property string endDate: ""
    property string startTime: "09:00"
    property string endTime: "10:00"
    property bool allDay: false
    property var alerts: []

    readonly property var alertOptions: [
        { id: 0, label: "At time" },
        { id: 5, label: "5 min" },
        { id: 10, label: "10 min" },
        { id: 15, label: "15 min" },
        { id: 30, label: "30 min" },
        { id: 60, label: "1 hour" },
        { id: 1440, label: "Day before" }
    ]

    signal saveRequested()
    signal deleteRequested()
    signal cancelled()

    function pad(n) {
        return n.toString().padStart(2, "0")
    }

    function ymd(d) {
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
    }

    function hm(d) {
        return `${pad(d.getHours())}:${pad(d.getMinutes())}`
    }

    function parseYmd(s) {
        const p = (s || "").split("-")
        if (p.length !== 3)
            return new Date()
        return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
    }

    function openNew(day, hour, writableCals) {
        creating = true
        writable = true
        uid = ""
        calendars = writableCals || []
        calendarId = (calendars.length > 0) ? calendars[0].id : "personal"
        titleText = ""
        locationText = ""
        allDay = hour === undefined || hour === null
        const d = day instanceof Date ? day : parseYmd(day)
        startDate = ymd(d)
        endDate = ymd(d)
        const h = (hour === undefined || hour === null) ? 9 : hour
        startTime = `${pad(h)}:00`
        endTime = `${pad(Math.min(23, h + 1))}:00`
        alerts = [15]
        titleField.text = ""
        locField.text = ""
        startDateField.text = startDate
        endDateField.text = endDate
        startTimeField.text = startTime
        endTimeField.text = endTime
        open = true
        Qt.callLater(() => titleField.forceActiveFocus())
    }

    function openEdit(ev, writableCals) {
        creating = false
        writable = !!ev.writable
        uid = ev.id
        calendars = writableCals || []
        calendarId = ev.calendarId
        titleText = ev.title || ""
        locationText = ev.location || ""
        allDay = !!ev.allDay
        const s = new Date(ev.start)
        let e = new Date(ev.end)
        if (allDay)
            e = new Date(e.getTime() - 86400000)
        startDate = ymd(s)
        endDate = ymd(e)
        startTime = hm(s)
        endTime = hm(e)
        alerts = (ev.alerts || []).slice()
        titleField.text = titleText
        locField.text = locationText
        startDateField.text = startDate
        endDateField.text = endDate
        startTimeField.text = startTime
        endTimeField.text = endTime
        open = true
        Qt.callLater(() => titleField.forceActiveFocus())
    }

    function collect() {
        titleText = titleField.text
        locationText = locField.text
        startDate = startDateField.text
        endDate = endDateField.text
        startTime = startTimeField.text
        endTime = endTimeField.text
    }

    function hasAlert(mins) {
        return alerts.indexOf(mins) !== -1 || alerts.indexOf(Number(mins)) !== -1
    }

    function toggleAlert(mins) {
        const n = Number(mins)
        const next = []
        let found = false
        for (let i = 0; i < alerts.length; i++) {
            if (Number(alerts[i]) === n)
                found = true
            else
                next.push(Number(alerts[i]))
        }
        if (!found)
            next.push(n)
        alerts = next
    }

    MouseArea {
        anchors.fill: parent
        onClicked: editor.cancelled()
    }

    Rectangle {
        width: Math.min(520, parent.width - 48)
        height: Math.min(cardCol.implicitHeight + 36, parent.height - 48)
        anchors.centerIn: parent
        radius: 14
        color: ThemeManager.bgBase
        border.width: ThemeManager.showWidgetBorders ? ThemeManager.widgetBorderWidth : 0
        border.color: ThemeManager.chromeBorderColor
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 18
            contentWidth: width
            contentHeight: cardCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: cardCol
                width: parent.width
                spacing: 10

                Text {
                    text: editor.creating ? "New event" : (editor.writable ? "Edit event" : "Event")
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Title"
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.1
                }
                InputField {
                    id: titleField
                    Layout.fillWidth: true
                    height: 34
                    enabled: editor.writable
                    placeholderText: "Event title"
                    font.pixelSize: 13
                }

                Text {
                    text: "Calendar"
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.1
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: editor.calendars
                        Rectangle {
                            required property var modelData
                            width: calLab.implicitWidth + 28
                            height: 28
                            radius: 8
                            color: editor.calendarId === modelData.id
                                ? modelData.color
                                : ThemeManager.surface1
                            Text {
                                id: calLab
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 6
                                text: modelData.name
                                color: editor.calendarId === modelData.id
                                    ? ThemeManager.bgBase
                                    : ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                            }
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: editor.calendarId === modelData.id
                                    ? ThemeManager.bgBase
                                    : modelData.color
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: editor.writable && editor.creating
                                cursorShape: editor.creating && editor.writable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: editor.calendarId = modelData.id
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        color: editor.allDay ? ThemeManager.accentBlue : ThemeManager.surface1
                        border.width: 1
                        border.color: ThemeManager.accentBorder
                        Text {
                            anchors.centerIn: parent
                            visible: editor.allDay
                            text: "\u2713"
                            color: ThemeManager.bgBase
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: editor.writable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editor.allDay = !editor.allDay
                        }
                    }
                    Text {
                        text: "All day"
                        color: ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 13
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: editor.allDay ? "Start date" : "Date"
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                            font.capitalization: Font.AllUppercase
                        }
                        InputField {
                            id: startDateField
                            Layout.fillWidth: true
                            height: 32
                            enabled: editor.writable
                            placeholderText: "YYYY-MM-DD"
                            font.pixelSize: 13
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "End date"
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                            font.capitalization: Font.AllUppercase
                        }
                        InputField {
                            id: endDateField
                            Layout.fillWidth: true
                            height: 32
                            enabled: editor.writable
                            placeholderText: "YYYY-MM-DD"
                            font.pixelSize: 13
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !editor.allDay
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "Start time"
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                            font.capitalization: Font.AllUppercase
                        }
                        InputField {
                            id: startTimeField
                            Layout.fillWidth: true
                            height: 32
                            enabled: editor.writable
                            placeholderText: "HH:MM"
                            font.pixelSize: 13
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "End time"
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                            font.capitalization: Font.AllUppercase
                        }
                        InputField {
                            id: endTimeField
                            Layout.fillWidth: true
                            height: 32
                            enabled: editor.writable
                            placeholderText: "HH:MM"
                            font.pixelSize: 13
                        }
                    }
                }

                Text {
                    text: "Location"
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.1
                }
                InputField {
                    id: locField
                    Layout.fillWidth: true
                    height: 34
                    enabled: editor.writable
                    placeholderText: "Optional"
                    font.pixelSize: 13
                }

                Text {
                    text: "Alert"
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.1
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: editor.alertOptions
                        Rectangle {
                            required property var modelData
                            readonly property bool on: editor.hasAlert(modelData.id)
                            width: al.implicitWidth + 16
                            height: 26
                            radius: 8
                            color: on ? ThemeManager.accentBlue : ThemeManager.surface1
                            Text {
                                id: al
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.on ? ThemeManager.bgBase : ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: editor.writable
                                cursorShape: Qt.PointingHandCursor
                                onClicked: editor.toggleAlert(modelData.id)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 8

                    Rectangle {
                        visible: !editor.creating && editor.writable
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 32
                        radius: 8
                        color: Qt.rgba(ThemeManager.accentRed.r, ThemeManager.accentRed.g, ThemeManager.accentRed.b, 0.18)
                        Text {
                            anchors.centerIn: parent
                            text: "Delete"
                            color: ThemeManager.accentRed
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editor.deleteRequested()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 32
                        radius: 8
                        color: ThemeManager.surface1
                        Text {
                            anchors.centerIn: parent
                            text: editor.writable ? "Cancel" : "Close"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editor.cancelled()
                        }
                    }

                    Rectangle {
                        visible: editor.writable
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 32
                        radius: 8
                        color: ThemeManager.accentBlue
                        Text {
                            anchors.centerIn: parent
                            text: "Save"
                            color: ThemeManager.bgBase
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                editor.collect()
                                editor.saveRequested()
                            }
                        }
                    }
                }
            }
        }
    }
}

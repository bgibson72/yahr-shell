import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 1120
    height: 700
    floatCenter: true
    slideOffsetY: 0
    entranceScale: 0.92

    property bool filePickerOpen: false
    property string viewMode: "month"
    property var anchorDate: new Date()
    property var calendars: []
    property var events: []
    property var palette: ["#89b4fa", "#f5c2e7", "#a6e3a1", "#f9e2af", "#fab387", "#cba6f7", "#94e2d5", "#f38ba8", "#b4befe", "#89dceb"]
    readonly property int weekStartOffset: Settings.calendarWeekStart === "monday" ? 1 : 0
    readonly property var weekdayHeaders: weekStartOffset === 1
        ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]
    readonly property var writableCalendars: {
        const out = []
        for (let i = 0; i < calendars.length; i++) {
            if (calendars[i].writable)
                out.push(calendars[i])
        }
        return out
    }

    signal requestClose()
    focus: true
    Keys.onEscapePressed: {
        if (eventEditor.open)
            eventEditor.open = false
    }

    onIsVisibleChanged: {
        if (isVisible)
            root.reload()
    }

    function pad(n) {
        return n.toString().padStart(2, "0")
    }

    function ymd(d) {
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
    }

    function startOfDay(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate())
    }

    function addDays(d, n) {
        const x = new Date(d.getTime())
        x.setDate(x.getDate() + n)
        return x
    }

    function weekStart(d) {
        const x = startOfDay(d)
        const dow = x.getDay()
        const back = (dow - weekStartOffset + 7) % 7
        return addDays(x, -back)
    }

    function headerTitle() {
        const d = anchorDate
        if (viewMode === "month")
            return `${monthNames[d.getMonth()]} ${d.getFullYear()}`
        if (viewMode === "week") {
            const a = weekStart(d)
            const b = addDays(a, 6)
            if (a.getMonth() === b.getMonth())
                return `${monthNames[a.getMonth()]} ${a.getDate()}–${b.getDate()}, ${a.getFullYear()}`
            return `${monthNames[a.getMonth()]} ${a.getDate()} – ${monthNames[b.getMonth()]} ${b.getDate()}, ${b.getFullYear()}`
        }
        return d.toLocaleDateString(Qt.locale(), Locale.LongFormat)
    }

    function showsOn(ev, day) {
        const s = new Date(ev.start)
        const e = new Date(ev.end)
        const a = startOfDay(day)
        const b = addDays(a, 1)
        return e > a && s < b
    }

    function eventsOn(day) {
        const out = []
        for (let i = 0; i < events.length; i++) {
            if (showsOn(events[i], day))
                out.push(events[i])
        }
        return out
    }

    function allDayOn(day) {
        return eventsOn(day).filter(e => e.allDay)
    }

    function timedOn(day) {
        return eventsOn(day).filter(e => !e.allDay)
    }

    function formatTime(iso) {
        const d = new Date(iso)
        if (Settings.clockFormat24hr)
            return `${pad(d.getHours())}:${pad(d.getMinutes())}`
        let h = d.getHours()
        const ap = h >= 12 ? "PM" : "AM"
        h = h % 12
        if (h === 0)
            h = 12
        return `${h}:${pad(d.getMinutes())} ${ap}`
    }

    function shiftAnchor(dir) {
        const d = new Date(anchorDate.getTime())
        if (viewMode === "month")
            d.setMonth(d.getMonth() + dir)
        else if (viewMode === "week")
            d.setDate(d.getDate() + dir * 7)
        else
            d.setDate(d.getDate() + dir)
        anchorDate = d
        root.reload()
    }

    function goToday() {
        anchorDate = new Date()
        root.reload()
    }

    function dumpRange() {
        const d = startOfDay(anchorDate)
        return {
            start: ymd(addDays(d, -40)),
            end: ymd(addDays(d, 50))
        }
    }

    function reload() {
        const r = dumpRange()
        dumpProc.command = [
            "python3",
            `${Quickshell.shellDir}/scripts/calendar-store.py`,
            "dump",
            "--start", r.start,
            "--end", r.end
        ]
        dumpProc.running = false
        dumpProc.running = true
    }

    function startPicker() {
        filePickerOpen = true
        pickerKick.restart()
    }

    function cycleColor(cal) {
        let idx = root.palette.indexOf(cal.color)
        idx = (idx + 1) % root.palette.length
        setCalProc.command = [
            "python3",
            `${Quickshell.shellDir}/scripts/calendar-store.py`,
            "set-calendar",
            cal.id,
            "--color", root.palette[idx]
        ]
        setCalProc.running = false
        setCalProc.running = true
    }

    function toggleCal(cal) {
        setCalProc.command = [
            "python3",
            `${Quickshell.shellDir}/scripts/calendar-store.py`,
            "set-calendar",
            cal.id,
            "--enabled", cal.enabled ? "false" : "true"
        ]
        setCalProc.running = false
        setCalProc.running = true
    }

    function openNew(day, hour) {
        eventEditor.openNew(day, hour, root.writableCalendars)
    }

    function openEdit(ev) {
        eventEditor.openEdit(ev, root.writableCalendars)
    }

    function isoJoin(dateStr, timeStr) {
        const t = (timeStr || "00:00").trim()
        const m = t.match(/^(\d{1,2}):(\d{2})/)
        const hh = m ? pad(Math.min(23, parseInt(m[1]))) : "00"
        const mm = m ? pad(Math.min(59, parseInt(m[2]))) : "00"
        return `${dateStr}T${hh}:${mm}:00`
    }

    function saveEditor() {
        const ed = eventEditor
        const args = [
            "python3",
            `${Quickshell.shellDir}/scripts/calendar-store.py`,
            ed.creating ? "add" : "update",
            "--calendar", ed.calendarId,
            "--title", ed.titleText || "New event",
            "--start", ed.allDay ? `${ed.startDate}T00:00:00` : isoJoin(ed.startDate, ed.startTime),
            "--end", ed.allDay ? `${ed.endDate}T00:00:00` : isoJoin(ed.endDate, ed.endTime),
            "--location", ed.locationText || "",
            "--alerts", (ed.alerts || []).join(",")
        ]
        if (ed.allDay)
            args.push("--all-day")
        if (!ed.creating)
            args.push("--uid", ed.uid)
        mutateProc.command = args
        mutateProc.running = false
        mutateProc.running = true
        eventEditor.open = false
    }

    function deleteEditor() {
        mutateProc.command = [
            "python3",
            `${Quickshell.shellDir}/scripts/calendar-store.py`,
            "delete",
            "--calendar", eventEditor.calendarId,
            "--uid", eventEditor.uid
        ]
        mutateProc.running = false
        mutateProc.running = true
        eventEditor.open = false
    }

    function monthCells() {
        const first = new Date(anchorDate.getFullYear(), anchorDate.getMonth(), 1)
        const start = weekStart(first)
        const cells = []
        for (let i = 0; i < 42; i++)
            cells.push(addDays(start, i))
        return cells
    }

    function weekDays() {
        const start = weekStart(anchorDate)
        const days = []
        for (let i = 0; i < 7; i++)
            days.push(addDays(start, i))
        return days
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            radius: 12
            color: ThemeManager.cardColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "Yahr Calendar"
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: calCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: calCol
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: root.calendars
                            Rectangle {
                                required property var modelData
                                width: calCol.width
                                height: 36
                                radius: 8
                                color: modelData.enabled ? ThemeManager.overlay(0.06) : "transparent"
                                opacity: modelData.enabled ? 1 : 0.45

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8
                                    Rectangle {
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        radius: 6
                                        color: modelData.color
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.cycleColor(modelData)
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        color: ThemeManager.fgPrimary
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 13
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleCal(modelData)
                                        }
                                    }
                                    Text {
                                        visible: modelData.id !== "personal"
                                        text: "\uf00d"
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 11
                                        color: ThemeManager.fgTertiary
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                removeProc.command = [
                                                    "python3",
                                                    `${Quickshell.shellDir}/scripts/calendar-store.py`,
                                                    "remove",
                                                    modelData.id
                                                ]
                                                removeProc.running = false
                                                removeProc.running = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: ThemeManager.surface1
                    Text {
                        anchors.centerIn: parent
                        text: "Import ICS"
                        color: ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startPicker()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 32
                    radius: 8
                    color: ThemeManager.surface1
                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        color: ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToday()
                    }
                }

                IconButton {
                    compact: true
                    glyph: "\uf053"
                    pixelSize: 12
                    onClicked: root.shiftAnchor(-1)
                }
                IconButton {
                    compact: true
                    glyph: "\uf054"
                    pixelSize: 12
                    onClicked: root.shiftAnchor(1)
                }

                Text {
                    Layout.fillWidth: true
                    text: root.headerTitle()
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Repeater {
                    model: [
                        { id: "month", label: "Month" },
                        { id: "week", label: "Week" },
                        { id: "day", label: "Day" }
                    ]
                    Rectangle {
                        required property var modelData
                        width: 64
                        height: 32
                        radius: 8
                        color: root.viewMode === modelData.id ? ThemeManager.accentBlue : ThemeManager.surface1
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.viewMode === modelData.id ? ThemeManager.bgBase : ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.viewMode = modelData.id
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 32
                    radius: 8
                    color: ThemeManager.accentBlue
                    Text {
                        anchors.centerIn: parent
                        text: "Add event"
                        color: ThemeManager.bgBase
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openNew(root.anchorDate, 9)
                    }
                }

                IconButton {
                    compact: true
                    glyph: "\uf00d"
                    pixelSize: 14
                    onClicked: root.requestClose()
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: root.viewMode === "month" ? monthComp
                    : (root.viewMode === "week" ? weekComp : dayComp)
            }
        }
    }

    Component {
        id: monthComp
        Item {
            id: monthView
            readonly property var cells: root.monthCells()

            Column {
                anchors.fill: parent
                spacing: 4

                Row {
                    width: parent.width
                    height: 22
                    Repeater {
                        model: root.weekdayHeaders
                        Text {
                            width: parent.width / 7
                            height: 22
                            text: modelData
                            color: ThemeManager.accentBlue
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Grid {
                    id: monthGrid
                    width: parent.width
                    height: parent.height - 26
                    columns: 7
                    rows: 6
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: 42
                        Rectangle {
                            id: cell
                            required property int index
                            readonly property var day: monthView.cells[index]
                            readonly property bool inMonth: day && day.getMonth() === root.anchorDate.getMonth()
                            readonly property bool isToday: day && root.ymd(day) === root.ymd(new Date())
                            readonly property var dayEvents: day ? root.eventsOn(day) : []
                            width: (monthGrid.width - 24) / 7
                            height: (monthGrid.height - 20) / 6
                            radius: 10
                            color: {
                                if (isToday)
                                    return Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.16)
                                return ThemeManager.overlay(inMonth ? 0.05 : 0.02)
                            }
                            border.width: isToday ? 1 : 0
                            border.color: Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.5)
                            opacity: inMonth ? 1 : 0.55

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.anchorDate = cell.day
                                    root.openNew(cell.day, null)
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 3
                                Text {
                                    text: cell.day ? cell.day.getDate() : ""
                                    color: cell.isToday ? ThemeManager.accentBlue : ThemeManager.fgPrimary
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 12
                                    font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                                }
                                Repeater {
                                    model: cell.dayEvents.slice(0, 3)
                                    Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 16
                                        radius: 4
                                        color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.28)
                                        readonly property color chipColor: modelData.color
                                        Rectangle {
                                            width: 3
                                            height: parent.height
                                            radius: 1
                                            color: modelData.color
                                        }
                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 6
                                            anchors.right: parent.right
                                            anchors.rightMargin: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.allDay ? modelData.title : `${root.formatTime(modelData.start)} ${modelData.title}`
                                            elide: Text.ElideRight
                                            color: ThemeManager.fgPrimary
                                            font.family: ThemeManager.uiFont
                                            font.pixelSize: 10
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openEdit(modelData)
                                        }
                                    }
                                }
                                Text {
                                    visible: cell.dayEvents.length > 3
                                    text: `+${cell.dayEvents.length - 3} more`
                                    color: ThemeManager.fgTertiary
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: weekComp
        Item {
            id: weekView
            readonly property var days: root.weekDays()
            readonly property int gutter: 52
            readonly property int hourH: 44
            readonly property int hours: 24

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    Item { width: weekView.gutter; height: 36 }
                    Repeater {
                        model: 7
                        Item {
                            required property int index
                            readonly property var day: weekView.days[index]
                            readonly property bool isToday: day && root.ymd(day) === root.ymd(new Date())
                            width: (parent.width - weekView.gutter) / 7
                            height: 36
                            Column {
                                anchors.centerIn: parent
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.weekdayHeaders[index]
                                    color: ThemeManager.fgTertiary
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 11
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: day ? day.getDate() : ""
                                    color: isToday ? ThemeManager.accentBlue : ThemeManager.fgPrimary
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Item { width: weekView.gutter; height: 52 }
                    Repeater {
                        model: 7
                        Rectangle {
                            required property int index
                            readonly property var day: weekView.days[index]
                            readonly property var band: day ? root.allDayOn(day) : []
                            width: (parent.width - weekView.gutter) / 7
                            height: 52
                            color: ThemeManager.overlay(0.04)
                            Column {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 2
                                Repeater {
                                    model: band.slice(0, 2)
                                    Rectangle {
                                        required property var modelData
                                        readonly property color chipColor: modelData.color
                                        width: parent.width
                                        height: 18
                                        radius: 4
                                        color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.3)
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            text: modelData.title
                                            elide: Text.ElideRight
                                            color: ThemeManager.fgPrimary
                                            font.pixelSize: 10
                                            font.family: ThemeManager.uiFont
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.openEdit(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Flickable {
                    id: weekFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: weekView.hours * weekView.hourH
                    boundsBehavior: Flickable.StopAtBounds
                    Component.onCompleted: contentY = 7 * weekView.hourH

                    Row {
                        width: weekFlick.width
                        height: weekView.hours * weekView.hourH

                        Column {
                            width: weekView.gutter
                            Repeater {
                                model: weekView.hours
                                Text {
                                    required property int index
                                    width: weekView.gutter
                                    height: weekView.hourH
                                    text: Settings.clockFormat24hr
                                        ? `${root.pad(index)}:00`
                                        : ((index % 12) === 0 ? 12 : (index % 12)) + (index < 12 ? " AM" : " PM")
                                    color: ThemeManager.fgTertiary
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignRight
                                    rightPadding: 6
                                }
                            }
                        }

                        Repeater {
                            model: 7
                            Item {
                                required property int index
                                readonly property var day: weekView.days[index]
                                width: (weekFlick.width - weekView.gutter) / 7
                                height: weekView.hours * weekView.hourH

                                Repeater {
                                    model: weekView.hours
                                    Rectangle {
                                        required property int index
                                        y: index * weekView.hourH
                                        width: parent.width
                                        height: 1
                                        color: ThemeManager.overlay(0.08)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        const hour = Math.floor(mouse.y / weekView.hourH)
                                        root.anchorDate = day
                                        root.openNew(day, hour)
                                    }
                                }

                                Repeater {
                                    model: day ? root.timedOn(day) : []
                                    Rectangle {
                                        required property var modelData
                                        readonly property var s: new Date(modelData.start)
                                        readonly property var e: new Date(modelData.end)
                                        readonly property real startM: s.getHours() * 60 + s.getMinutes()
                                        readonly property real durM: Math.max(25, (e.getTime() - s.getTime()) / 60000)
                                        x: 3
                                        width: parent.width - 6
                                        y: (startM / 60) * weekView.hourH
                                        height: (durM / 60) * weekView.hourH
                                        radius: 6
                                        readonly property color chipColor: modelData.color
                                        color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.35)
                                        border.width: 1
                                        border.color: modelData.color
                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            Text {
                                                width: parent.width
                                                text: modelData.title
                                                elide: Text.ElideRight
                                                color: ThemeManager.fgPrimary
                                                font.family: ThemeManager.uiFont
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }
                                            Text {
                                                width: parent.width
                                                text: root.formatTime(modelData.start)
                                                color: ThemeManager.fgSecondary
                                                font.family: ThemeManager.uiFont
                                                font.pixelSize: 10
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.openEdit(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: dayComp
        Item {
            id: dayView
            readonly property var day: root.startOfDay(root.anchorDate)
            readonly property int hourH: 48
            readonly property var allDay: root.allDayOn(day)
            readonly property var timed: root.timedOn(day)

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: allDay.length > 0
                    Repeater {
                        model: allDay
                        Rectangle {
                            required property var modelData
                            readonly property color chipColor: modelData.color
                            width: Math.min(220, alTitle.implicitWidth + 20)
                            height: 26
                            radius: 8
                            color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.3)
                            Text {
                                id: alTitle
                                anchors.centerIn: parent
                                text: modelData.title
                                color: ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.openEdit(modelData)
                            }
                        }
                    }
                }

                Flickable {
                    id: dayFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: 24 * dayView.hourH
                    boundsBehavior: Flickable.StopAtBounds
                    Component.onCompleted: contentY = 7 * dayView.hourH

                    Item {
                        width: dayFlick.width
                        height: 24 * dayView.hourH

                        Repeater {
                            model: 24
                            Rectangle {
                                required property int index
                                y: index * dayView.hourH
                                width: parent.width
                                height: dayView.hourH
                                color: "transparent"
                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: ThemeManager.overlay(0.08)
                                }
                                Text {
                                    width: 56
                                    height: parent.height
                                    text: Settings.clockFormat24hr
                                        ? `${root.pad(index)}:00`
                                        : ((index % 12) === 0 ? 12 : (index % 12)) + (index < 12 ? " AM" : " PM")
                                    color: ThemeManager.fgTertiary
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignRight
                                    rightPadding: 8
                                    verticalAlignment: Text.AlignTop
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.openNew(dayView.day, index)
                                }
                            }
                        }

                        Repeater {
                            model: timed
                            Rectangle {
                                required property var modelData
                                readonly property var s: new Date(modelData.start)
                                readonly property var e: new Date(modelData.end)
                                readonly property real startM: s.getHours() * 60 + s.getMinutes()
                                readonly property real durM: Math.max(28, (e.getTime() - s.getTime()) / 60000)
                                x: 64
                                width: parent.width - 80
                                y: (startM / 60) * dayView.hourH
                                height: (durM / 60) * dayView.hourH
                                radius: 8
                                readonly property color chipColor: modelData.color
                                color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.32)
                                border.width: 1
                                border.color: modelData.color
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 2
                                    Text {
                                        text: modelData.title
                                        color: ThemeManager.fgPrimary
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: `${root.formatTime(modelData.start)} – ${root.formatTime(modelData.end)}`
                                        color: ThemeManager.fgSecondary
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        visible: modelData.location.length > 0
                                        text: modelData.location
                                        color: ThemeManager.fgTertiary
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 12
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.openEdit(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    EventEditor {
        id: eventEditor
        anchors.fill: parent
        z: 20
        onCancelled: open = false
        onSaveRequested: root.saveEditor()
        onDeleteRequested: root.deleteEditor()
    }

    Process {
        id: dumpProc
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/calendar-store.py`, "dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    root.calendars = data.calendars || []
                    root.events = data.events || []
                } catch (e) {}
            }
        }
    }

    Process {
        id: mutateProc
        running: false
        command: ["true"]
        onExited: root.reload()
    }

    Process {
        id: setCalProc
        running: false
        command: ["true"]
        onExited: root.reload()
    }

    Process {
        id: removeProc
        running: false
        command: ["true"]
        onExited: root.reload()
    }

    Process {
        id: importProc
        running: false
        property string icsPath: ""
        command: ["python3", `${Quickshell.shellDir}/scripts/calendar-store.py`, "import", icsPath]
        onExited: root.reload()
    }

    Process {
        id: icsPicker
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/pick-ics.py`, Quickshell.env("HOME")]
        onRunningChanged: if (!running) root.filePickerOpen = false
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length > 0) {
                    importProc.icsPath = path
                    importProc.running = false
                    importProc.running = true
                }
            }
        }
    }

    Timer {
        id: pickerKick
        interval: 120
        repeat: false
        onTriggered: icsPicker.running = true
    }
}

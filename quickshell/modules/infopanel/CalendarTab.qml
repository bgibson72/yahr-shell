import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Item {
    id: root
    property bool active: false
    property bool hasLoadedEvents: false

    onActiveChanged: {
        if (active && !hasLoadedEvents) {
            hasLoadedEvents = true
            calendarModel.triggerCalendarLoad()
        }
    }

    Connections {
        target: Settings
        function onCalendarFilePathChanged() {
            if (root.active)
                calendarModel.triggerCalendarLoad()
        }
    }

    Timer {
        id: calendarRefreshTimer
        interval: Settings.calendarRefreshInterval * 60000
        running: root.active && Settings.calendarRefreshInterval > 0
        repeat: true
        triggeredOnStart: false
        onTriggered: calendarModel.triggerCalendarLoad()
    }

    Rectangle {
        anchors.fill: parent
        color: ThemeManager.cardColor
        radius: 12

        Item {
            anchors.fill: parent
            anchors.margins: 16

            Row {
                id: calHeader
                width: parent.width
                height: 40
                anchors.top: parent.top

                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: "transparent"
                    scale: prevMouse.pressed ? ThemeManager.iconPressScale : (prevMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
                    Behavior on scale {
                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\u25c0"
                        font.pixelSize: 14
                        color: ThemeManager.fgPrimary
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarModel.changeMonth(-1)
                    }
                }

                Text {
                    width: parent.width - 80
                    height: parent.height
                    text: calendarModel.monthYearText
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    color: ThemeManager.fgPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: "transparent"
                    scale: nextMouse.pressed ? ThemeManager.iconPressScale : (nextMouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
                    Behavior on scale {
                        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\u25b6"
                        font.pixelSize: 14
                        color: ThemeManager.fgPrimary
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarModel.changeMonth(1)
                    }
                }
            }

            Grid {
                id: calGrid
                width: parent.width
                anchors.top: calHeader.bottom
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                columns: 7
                columnSpacing: 4
                rowSpacing: 4

                property int dayHeaderH: 24
                property int dayH: Math.max(28, Math.floor((height - dayHeaderH - 6 * rowSpacing) / 6))

                Repeater {
                    model: calendarModel.weekdayHeaders
                    Text {
                        text: modelData
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: ThemeManager.accentBlue
                        width: (calGrid.width - 24) / 7
                        height: calGrid.dayHeaderH
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Repeater {
                    model: 42

                    Rectangle {
                        id: dayCell
                        width: (calGrid.width - 24) / 7
                        height: calGrid.dayH
                        radius: 8

                        required property int index
                        readonly property int dayNumber: {
                            calendarModel.eventsRevision
                            calendarModel.currentMonth
                            calendarModel.currentYear
                            calendarModel.weekStartOffset
                            return calendarModel.getDayNumber(index)
                        }
                        readonly property bool isCurrentDay: {
                            calendarModel.weekStartOffset
                            return calendarModel.isToday(index)
                        }
                        readonly property bool isSelectedDay: {
                            calendarModel.weekStartOffset
                            calendarModel.selectedDay
                            return calendarModel.isSelected(index)
                        }
                        readonly property bool isValidDay: dayNumber > 0
                        readonly property string dateKey: isValidDay
                            ? `${calendarModel.currentYear}-${(calendarModel.currentMonth + 1).toString().padStart(2, '0')}-${dayNumber.toString().padStart(2, '0')}`
                            : ""
                        readonly property bool hasEvents: isValidDay && calendarModel.eventDatesCache[dateKey] === true
                        readonly property int _revision: calendarModel.eventsRevision

                        color: {
                            if (isValidDay && isCurrentDay) return Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.30)
                            if (isValidDay && isSelectedDay) return ThemeManager.overlay(0.16)
                            if (dayMouse.containsMouse && isValidDay) return ThemeManager.overlay(0.08)
                            return "transparent"
                        }
                        border.width: isValidDay && isCurrentDay ? 1 : 0
                        border.color: Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.55)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: dayCell.isValidDay ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (dayCell.isValidDay) calendarModel.selectDay(dayCell.dayNumber)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dayCell.isValidDay ? dayCell.dayNumber : ""
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 14
                                font.weight: dayCell.isValidDay && dayCell.isCurrentDay ? Font.Bold : Font.Normal
                                color: {
                                    if (dayCell.isValidDay && dayCell.isCurrentDay) return ThemeManager.accentBlue
                                    if (!dayCell.isValidDay) return ThemeManager.border0
                                    return ThemeManager.fgPrimary
                                }
                            }

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: ThemeManager.accentCyan
                                visible: dayCell.hasEvents
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: calendarModel

        property int currentMonth: new Date().getMonth()
        property int currentYear: new Date().getFullYear()
        property int selectedDay: new Date().getDate()
        property string monthYearText: getMonthYearText()
        property var eventDatesCache: ({})
        property var allEventsCache: []
        property int eventsRevision: 0
        property int weekStartOffset: Settings.calendarWeekStart === "monday" ? 1 : 0
        property var weekdayHeaders: weekStartOffset === 1
            ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        onWeekStartOffsetChanged: eventsRevision++

        function getMonthYearText() {
            const months = ["January", "February", "March", "April", "May", "June",
                             "July", "August", "September", "October", "November", "December"]
            return `${months[currentMonth]} ${currentYear}`
        }

        function changeMonth(delta) {
            currentMonth += delta
            if (currentMonth > 11) { currentMonth = 0; currentYear++ }
            else if (currentMonth < 0) { currentMonth = 11; currentYear-- }
            monthYearText = getMonthYearText()

            eventDatesCache = {}
            if (allEventsCache.length > 0)
                buildEventCacheForMonth(currentYear, currentMonth)
            eventsRevision++
        }

        function getDayNumber(index) {
            const firstDay = new Date(currentYear, currentMonth, 1)
            const startOffset = (firstDay.getDay() - weekStartOffset + 7) % 7
            const dayNumber = index - startOffset + 1
            const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate()
            return (dayNumber >= 1 && dayNumber <= daysInMonth) ? dayNumber : 0
        }

        function isToday(index) {
            const now = new Date()
            const dayNumber = getDayNumber(index)
            return dayNumber > 0 && dayNumber === now.getDate() &&
                   currentMonth === now.getMonth() && currentYear === now.getFullYear()
        }

        function isSelected(index) {
            const dayNumber = getDayNumber(index)
            return dayNumber > 0 && dayNumber === selectedDay
        }

        function selectDay(day) {
            selectedDay = day
        }

        function buildEventCacheForMonth(year, month) {
            const lastDay = new Date(year, month + 1, 0)
            const currentDate = new Date(year, month, 1)

            while (currentDate <= lastDay) {
                const dateKey = `${currentDate.getFullYear()}-${(currentDate.getMonth() + 1).toString().padStart(2, '0')}-${currentDate.getDate().toString().padStart(2, '0')}`
                const hasEvent = allEventsCache.some(evt =>
                    evt.rrule ? icalLoader.checkRecurringEvent(evt, currentDate)
                              : evt.date && new Date(evt.date).toDateString() === currentDate.toDateString()
                )
                if (hasEvent)
                    eventDatesCache[dateKey] = true
                currentDate.setDate(currentDate.getDate() + 1)
            }
            eventDatesCache = eventDatesCache
        }

        function triggerCalendarLoad() {
            const expanded = Settings.calendarFilePath.replace(/~/g, Quickshell.env("HOME"))
            const paths = expanded.split(/[,;\s]+/).filter(p => p.trim() !== "")
            if (paths.length === 0)
                paths.push(Quickshell.env("HOME") + "/.config/yahr/calendar.ics")

            const isUrl = paths.some(p => p.startsWith("http://") || p.startsWith("https://"))
            const commands = paths.map(p =>
                (p.startsWith("http://") || p.startsWith("https://"))
                    ? `curl -s -L "${p}"`
                    : `(test -f "${p}" && cat "${p}" && echo "")`
            )
            icalLoader.command = ["sh", "-c", commands.join(isUrl ? " ; echo ''; " : " ; ")]
            icalLoader.running = true
        }
    }

    Process {
        id: icalLoader
        running: false
        command: ["sh", "-c", "echo ''"]

        stdout: StdioCollector {
            onStreamFinished: icalLoader.parseICalData(this.text)
        }

        function parseICalData(icalContent) {
            const allEvents = []

            if (!icalContent || icalContent.trim() === "") {
                calendarModel.allEventsCache = allEvents
                calendarModel.eventDatesCache = {}
                return
            }

            if (icalContent.indexOf('\n') === -1 && icalContent.indexOf('\r') === -1) {
                icalContent = icalContent.replace(
                    /(BEGIN:|END:|DTSTART|DTEND|SUMMARY:|DESCRIPTION:|LOCATION:|UID:|DTSTAMP:|CREATED:|LAST-MODIFIED:|SEQUENCE:|STATUS:|TRANSP:|VERSION:|PRODID:|CALSCALE:|METHOD:)/g,
                    '\n$1'
                ).trim()
            }

            const unfolded = icalContent.replace(/\r\n /g, '').replace(/\n /g, '').replace(/\r /g, '')
            const lines = unfolded.split(/\r\n|\r|\n/)
            let currentEvent = null

            for (const rawLine of lines) {
                const line = rawLine.trim()

                if (line === "BEGIN:VEVENT") {
                    currentEvent = { title: "", time: "", date: null, rrule: null, color: ThemeManager.accentBlue }
                } else if (line === "END:VEVENT" && currentEvent) {
                    if (currentEvent.date)
                        allEvents.push(currentEvent)
                    currentEvent = null
                } else if (currentEvent) {
                    if (line.startsWith("SUMMARY:")) {
                        currentEvent.title = line.substring(8)
                    } else if (line.startsWith("RRULE:")) {
                        currentEvent.rrule = line.substring(6)
                    } else if (line.startsWith("DTSTART")) {
                        const m = line.match(/(\d{8})(T(\d{6})Z?)?/)
                        if (m) {
                            const year = parseInt(m[1].substring(0, 4))
                            const month = parseInt(m[1].substring(4, 6)) - 1
                            const day = parseInt(m[1].substring(6, 8))

                            if (m[3]) {
                                const hour = parseInt(m[3].substring(0, 2))
                                const minute = parseInt(m[3].substring(2, 4))
                                currentEvent.date = line.includes('Z')
                                    ? new Date(Date.UTC(year, month, day, hour, minute))
                                    : new Date(year, month, day, hour, minute)
                                currentEvent.time = `${currentEvent.date.getHours().toString().padStart(2, '0')}:${currentEvent.date.getMinutes().toString().padStart(2, '0')}`
                            } else {
                                currentEvent.date = new Date(year, month, day)
                                currentEvent.time = "All day"
                            }
                        }
                    }
                }
            }

            calendarModel.allEventsCache = allEvents
            calendarModel.eventDatesCache = {}
            calendarModel.buildEventCacheForMonth(calendarModel.currentYear, calendarModel.currentMonth)
            calendarModel.eventsRevision++
        }

        function checkRecurringEvent(event, targetDate) {
            if (!event.rrule || !event.date)
                return false

            const startDate = new Date(event.date)
            let freq = null, until = null, byday = [], interval = 1, count = null

            for (const part of event.rrule.split(';')) {
                const [key, value] = part.split('=')
                if (key === 'FREQ') freq = value
                else if (key === 'UNTIL') {
                    const m = value.match(/(\d{4})(\d{2})(\d{2})/)
                    if (m) until = new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]))
                } else if (key === 'BYDAY') byday = value.split(',')
                else if (key === 'INTERVAL') interval = parseInt(value)
                else if (key === 'COUNT') count = parseInt(value)
            }

            if (targetDate < startDate) return false
            if (until && targetDate > until) return false

            if (freq === 'WEEKLY' && byday.length > 0) {
                const dayMap = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 }
                const targetDay = targetDate.getDay()
                if (!byday.some(d => dayMap[d] === targetDay))
                    return false

                const daysDiff = Math.floor((targetDate - startDate) / 86400000)
                const weeksDiff = Math.floor(daysDiff / 7)
                if (weeksDiff % interval !== 0)
                    return weeksDiff === 0 && targetDay >= startDate.getDay()
                if (count !== null && Math.floor(weeksDiff / interval) + 1 > count)
                    return false
                return true
            }

            if (freq === 'DAILY') {
                const daysDiff = Math.floor((targetDate - startDate) / 86400000)
                if (daysDiff % interval !== 0) return false
                if (count !== null && Math.floor(daysDiff / interval) + 1 > count) return false
                return true
            }

            if (freq === 'MONTHLY') {
                if (targetDate.getDate() !== startDate.getDate()) return false
                const monthsDiff = (targetDate.getFullYear() - startDate.getFullYear()) * 12 + (targetDate.getMonth() - startDate.getMonth())
                if (monthsDiff % interval !== 0) return false
                if (count !== null && monthsDiff / interval >= count) return false
                return true
            }

            if (freq === 'YEARLY') {
                if (targetDate.getDate() !== startDate.getDate() || targetDate.getMonth() !== startDate.getMonth()) return false
                const yearsDiff = targetDate.getFullYear() - startDate.getFullYear()
                if (yearsDiff % interval !== 0) return false
                if (count !== null && yearsDiff / interval >= count) return false
                return true
            }

            return false
        }
    }
}

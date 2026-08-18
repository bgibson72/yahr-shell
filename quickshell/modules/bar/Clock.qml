import QtQuick
import "../.."

Item {
    id: clockArea
    implicitWidth: clockText.implicitWidth + 16
    implicitHeight: parent ? parent.height : 28

    Text {
        id: clockText
        anchors.centerIn: parent
        font.family: ThemeManager.uiFont
        font.pixelSize: ThemeManager.fontSizeNormal
        color: ThemeManager.fgPrimary
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            const month = (now.getMonth() + 1).toString().padStart(2, "0")
            const day = now.getDate().toString().padStart(2, "0")
            const year = now.getFullYear()
            let hours = now.getHours()
            const minutes = now.getMinutes().toString().padStart(2, "0")
            const seconds = now.getSeconds().toString().padStart(2, "0")
            let dateStr
            if (Settings.dateLong) {
                const monthNames = ["January", "February", "March", "April", "May", "June",
                                    "July", "August", "September", "October", "November", "December"]
                const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                dateStr = Settings.dateFormat === "DMY"
                    ? `${now.getDate()} ${monthNames[now.getMonth()]} ${year}`
                    : `${monthNames[now.getMonth()]} ${now.getDate()}, ${year}`
                if (Settings.showDayOfWeek)
                    dateStr = `${dayNames[now.getDay()]}, ${dateStr}`
            } else {
                dateStr = Settings.dateFormat === "DMY" ? `${day}/${month}/${year}` : `${month}/${day}/${year}`
            }
            let timeStr
            if (Settings.clockFormat24hr) {
                timeStr = `${hours.toString().padStart(2, "0")}:${minutes}`
                if (Settings.showSeconds)
                    timeStr += `:${seconds}`
            } else {
                const ampm = hours >= 12 ? "PM" : "AM"
                hours = hours % 12
                hours = hours ? hours : 12
                timeStr = `${hours.toString().padStart(2, "0")}:${minutes}`
                if (Settings.showSeconds)
                    timeStr += `:${seconds}`
                timeStr += ` ${ampm}`
            }
            clockText.text = `${dateStr}  ${timeStr}`
        }
    }
}

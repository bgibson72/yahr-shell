import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Item {
    id: clockArea
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight
    width: implicitWidth
    height: implicitHeight

    signal clicked()

    property string weatherIcon: "\ue302"
    property string weatherTemp: "--"

    function nfIconFor(code) {
        const thunder = ["200", "386", "389", "392"]
        const snow = ["227", "230", "320", "323", "326", "329", "332", "335", "338", "350", "368", "371", "374", "377", "395"]
        const fog = ["143", "248", "260"]
        const cloud = ["116", "119", "122"]
        if (code === "113")
            return "\ue30d"
        if (thunder.indexOf(code) !== -1)
            return "\ue30f"
        if (snow.indexOf(code) !== -1)
            return "\ue31a"
        if (fog.indexOf(code) !== -1)
            return "\ue313"
        if (cloud.indexOf(code) !== -1)
            return "\ue302"
        return "\ue308"
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: Settings.barStyle === "islands" ? "transparent" : ThemeManager.barPillColor
        radius: height / 2
        implicitWidth: clockRow.implicitWidth + 28
        implicitHeight: clockRow.implicitHeight + 12
        scale: clockMouse.pressed ? ThemeManager.bouncePressScale : (clockMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
        Behavior on scale {
            SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
        }
    }

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            id: dateText
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: ThemeManager.fgPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: Settings.showWeatherInBar
            text: "|"
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: ThemeManager.fgPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: Settings.showWeatherInBar
            text: clockArea.weatherIcon
            font.family: "Symbols Nerd Font"
            font.pixelSize: ThemeManager.fontSizeNormal
            color: ThemeManager.fgPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: Settings.showWeatherInBar
            text: clockArea.weatherTemp
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: ThemeManager.fgPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "|"
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: ThemeManager.fgPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: timeText
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeNormal
            color: ThemeManager.fgPrimary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: clockArea.clicked()
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
            const shortDays = ["Sun", "Mon", "Tues", "Wed", "Thurs", "Fri", "Sat"]
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
                if (Settings.showDayOfWeek)
                    dateStr = `${shortDays[now.getDay()]} ${dateStr}`
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
            dateText.text = dateStr
            timeText.text = timeStr
        }
    }

    Timer {
        interval: 300000
        running: Settings.showWeatherInBar
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Process {
        id: weatherProc
        running: false
        command: ["python3", `${Quickshell.env("HOME")}/.config/yahr/lock-info.py`, "fetch-weather"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data
                try {
                    data = JSON.parse(this.text)
                } catch (e) {
                    return
                }
                const cur = data.current_condition && data.current_condition[0]
                if (!cur)
                    return
                const unit = Settings.weatherUseFahrenheit ? "F" : "C"
                const temp = Settings.weatherUseFahrenheit ? cur.temp_F : cur.temp_C
                clockArea.weatherTemp = `${temp} ${unit}`
                clockArea.weatherIcon = clockArea.nfIconFor(cur.weatherCode)
            }
        }
    }
}

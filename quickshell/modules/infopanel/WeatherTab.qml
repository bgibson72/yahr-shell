import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// wttr.in-backed weather: a single `j1` request returns current conditions,
// location, and the forecast together, so unlike the old dual-API version
// this only ever needs one HTTP call per refresh.
Item {
    id: root
    property bool active: false

    property string icon: "\u26c5"
    property string temp: "..."
    property string condition: "Loading..."
    property string location: ""
    property string feelsLike: "--"
    property string humidity: "--"
    property string windSpeed: "--"
    property string pressure: "--"
    property var forecast: []

    readonly property var weatherIcons: ({
        "113": "\u2600\ufe0f", "116": "\u26c5", "119": "\u2601\ufe0f", "122": "\u2601\ufe0f", "143": "\ud83c\udf2b\ufe0f",
        "176": "\ud83c\udf26\ufe0f", "179": "\ud83c\udf28\ufe0f", "182": "\ud83c\udf28\ufe0f", "185": "\ud83c\udf28\ufe0f", "200": "\u26c8\ufe0f",
        "227": "\ud83c\udf28\ufe0f", "230": "\u2744\ufe0f", "248": "\ud83c\udf2b\ufe0f", "260": "\ud83c\udf2b\ufe0f", "263": "\ud83c\udf26\ufe0f",
        "266": "\ud83c\udf27\ufe0f", "281": "\ud83c\udf27\ufe0f", "284": "\ud83c\udf27\ufe0f", "293": "\ud83c\udf26\ufe0f", "296": "\ud83c\udf27\ufe0f",
        "299": "\ud83c\udf27\ufe0f", "302": "\ud83c\udf27\ufe0f", "305": "\ud83c\udf27\ufe0f", "308": "\ud83c\udf27\ufe0f", "311": "\ud83c\udf27\ufe0f",
        "314": "\ud83c\udf27\ufe0f", "317": "\ud83c\udf27\ufe0f", "320": "\ud83c\udf28\ufe0f", "323": "\ud83c\udf28\ufe0f", "326": "\ud83c\udf28\ufe0f",
        "329": "\u2744\ufe0f", "332": "\u2744\ufe0f", "335": "\u2744\ufe0f", "338": "\u2744\ufe0f", "350": "\ud83c\udf28\ufe0f",
        "353": "\ud83c\udf26\ufe0f", "356": "\ud83c\udf27\ufe0f", "359": "\ud83c\udf27\ufe0f", "362": "\ud83c\udf28\ufe0f", "365": "\ud83c\udf28\ufe0f",
        "368": "\ud83c\udf28\ufe0f", "371": "\u2744\ufe0f", "374": "\ud83c\udf28\ufe0f", "377": "\ud83c\udf28\ufe0f", "386": "\u26c8\ufe0f",
        "389": "\u26c8\ufe0f", "392": "\u26c8\ufe0f", "395": "\u2744\ufe0f"
    })

    function iconFor(code) { return weatherIcons[code] || "\u26c5" }

    function dayLabel(index) {
        if (index === 0) return "Today"
        if (index === 1) return "Tomorrow"
        const date = new Date()
        date.setDate(date.getDate() + index)
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.getDay()]
    }

    Timer {
        interval: 300000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    Process {
        id: proc
        running: false
        command: {
            const unit = Settings.weatherUseFahrenheit ? "u" : "m"
            const loc = Settings.weatherLocation.trim()
            return ["sh", "-c", `curl -s --max-time 8 'wttr.in/${loc}?${unit}&format=j1'`]
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let data
                try {
                    data = JSON.parse(this.text)
                } catch (e) {
                    return
                }

                const tempSymbol = Settings.weatherUseFahrenheit ? "\u00b0F" : "\u00b0C"
                const speedUnit = Settings.weatherUseFahrenheit ? " mph" : " km/h"

                const cur = data.current_condition && data.current_condition[0]
                if (cur) {
                    root.icon = root.iconFor(cur.weatherCode)
                    root.temp = (Settings.weatherUseFahrenheit ? cur.temp_F : cur.temp_C) + tempSymbol
                    root.condition = (cur.weatherDesc && cur.weatherDesc[0] && cur.weatherDesc[0].value.trim()) || "Unknown"
                    root.feelsLike = (Settings.weatherUseFahrenheit ? cur.FeelsLikeF : cur.FeelsLikeC) + tempSymbol
                    root.humidity = cur.humidity + "%"
                    root.windSpeed = (Settings.weatherUseFahrenheit ? cur.windspeedMiles : cur.windspeedKmph) + speedUnit
                    root.pressure = cur.pressure + " hPa"
                }

                const area = data.nearest_area && data.nearest_area[0]
                if (area) {
                    const city = area.areaName && area.areaName[0] && area.areaName[0].value
                    const region = area.region && area.region[0] && area.region[0].value
                    root.location = [city, region].filter(s => s).join(", ")
                }

                if (Array.isArray(data.weather)) {
                    const days = []
                    for (let i = 0; i < Math.min(3, data.weather.length); i++) {
                        const day = data.weather[i]
                        const hourly = day.hourly && day.hourly[Math.floor(day.hourly.length / 2)]
                        days.push({
                            high: (Settings.weatherUseFahrenheit ? day.maxtempF : day.maxtempC) + tempSymbol,
                            low: (Settings.weatherUseFahrenheit ? day.mintempF : day.mintempC) + tempSymbol,
                            condition: (hourly && hourly.weatherDesc[0].value.trim()) || "Unknown",
                            icon: root.iconFor(hourly ? hourly.weatherCode : "")
                        })
                    }
                    root.forecast = days
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 16

        Rectangle {
            width: parent.width
            height: (parent.height - 16) * 0.45
            color: Qt.rgba(1, 1, 1, 0.07)
            radius: 12

            Item {
                anchors.fill: parent
                anchors.margins: 24

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -parent.width * 0.25
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.icon
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 72
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.temp
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 44
                        font.weight: Font.Bold
                        color: ThemeManager.fgPrimary
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.condition
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 16
                        color: ThemeManager.fgSecondary
                    }
                }

                Column {
                    width: parent.width * 0.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: parent.width * 0.25
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Text {
                        visible: root.location !== ""
                        text: "\ud83d\udccd " + root.location
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: ThemeManager.accentBlue
                        width: parent.width
                        elide: Text.ElideRight
                    }

                    Grid {
                        columns: 2
                        columnSpacing: 32
                        rowSpacing: 14

                        Repeater {
                            model: [
                                { label: "Feels Like", value: root.feelsLike, color: ThemeManager.fgPrimary },
                                { label: "Humidity", value: root.humidity, color: ThemeManager.accentCyan },
                                { label: "Wind Speed", value: root.windSpeed, color: ThemeManager.accentGreen },
                                { label: "Pressure", value: root.pressure, color: ThemeManager.fgPrimary }
                            ]
                            Column {
                                required property var modelData
                                spacing: 4
                                Text {
                                    text: modelData.label
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 11
                                    color: ThemeManager.fgTertiary
                                }
                                Text {
                                    text: modelData.value
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: modelData.color
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: (parent.height - 16) * 0.55
            color: Qt.rgba(1, 1, 1, 0.07)
            radius: 12

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                Text {
                    text: "3-Day Forecast"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: ThemeManager.fontSizeLarge
                    font.weight: Font.Bold
                    color: ThemeManager.fgPrimary
                }

                Row {
                    width: parent.width
                    height: parent.height - 50
                    spacing: 8

                    Repeater {
                        model: root.forecast

                        Rectangle {
                            required property var modelData
                            required property int index
                            width: (parent.width - 16) / 3
                            height: parent.height
                            color: Qt.rgba(1, 1, 1, 0.07)
                            radius: 10

                            Column {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.dayLabel(index)
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: ThemeManager.fgPrimary
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icon
                                    font.family: "Noto Color Emoji"
                                    font.pixelSize: 34
                                }
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 6
                                    Text {
                                        text: modelData.high
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        color: ThemeManager.accentRed
                                    }
                                    Text {
                                        text: modelData.low
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 13
                                        color: ThemeManager.accentCyan
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.condition
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 10
                                    color: ThemeManager.fgSecondary
                                    width: parent.parent.width - 16
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

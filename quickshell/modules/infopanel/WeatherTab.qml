import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Current conditions plus today's high/low, moon, and sunrise/sunset.
Item {
    id: root
    property bool active: false

    property string icon: "\u26c5"
    property string temp: "..."
    property string location: ""
    property string highTemp: "--"
    property string lowTemp: "--"
    property string moonPhaseName: "New Moon"
    property string moonIllumination: "0%"
    property string sunriseTime: "--"
    property string sunsetTime: "--"

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

    readonly property var moonEmoji: ({
        "New Moon": "\ud83c\udf11", "Waxing Crescent": "\ud83c\udf12", "First Quarter": "\ud83c\udf13",
        "Waxing Gibbous": "\ud83c\udf14", "Full Moon": "\ud83c\udf15", "Waning Gibbous": "\ud83c\udf16",
        "Last Quarter": "\ud83c\udf17", "Waning Crescent": "\ud83c\udf18"
    })

    function iconFor(code) { return weatherIcons[code] || "\u26c5" }

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
        command: ["python3", `${Quickshell.env("HOME")}/.config/yahr/lock-info.py`, "fetch-weather"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data
                try {
                    data = JSON.parse(this.text)
                } catch (e) {
                    return
                }

                const tempSymbol = Settings.weatherUseFahrenheit ? "\u00b0F" : "\u00b0C"
                const cur = data.current_condition && data.current_condition[0]
                if (cur) {
                    root.icon = root.iconFor(cur.weatherCode)
                    root.temp = (Settings.weatherUseFahrenheit ? cur.temp_F : cur.temp_C) + tempSymbol
                }

                const area = data.nearest_area && data.nearest_area[0]
                if (area) {
                    const city = area.areaName && area.areaName[0] && area.areaName[0].value
                    const region = area.region && area.region[0] && area.region[0].value
                    root.location = [city, region].filter(s => s).join(", ")
                }

                const today = data.weather && data.weather[0]
                if (today) {
                    root.highTemp = (Settings.weatherUseFahrenheit ? today.maxtempF : today.maxtempC) + tempSymbol
                    root.lowTemp = (Settings.weatherUseFahrenheit ? today.mintempF : today.mintempC) + tempSymbol
                    const astro = today.astronomy && today.astronomy[0]
                    if (astro) {
                        root.moonPhaseName = astro.moon_phase || "New Moon"
                        root.moonIllumination = (astro.moon_illumination || "0") + "%"
                        root.sunriseTime = astro.sunrise || "--"
                        root.sunsetTime = astro.sunset || "--"
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ThemeManager.cardColor
        radius: 12

        Item {
            id: weatherBlock
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: astroBar.top
            anchors.margins: 16
            anchors.bottomMargin: 10

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 14

                Text {
                    width: parent.width
                    text: root.location !== "" ? root.location : "Weather"
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: ThemeManager.accentBlue
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Text {
                        text: root.icon
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 72
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.temp
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 56
                        font.weight: Font.Bold
                        color: ThemeManager.fgPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 22

                    Row {
                        spacing: 8
                        Text {
                            text: "H"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 14
                            color: ThemeManager.fgTertiary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.highTemp
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: ThemeManager.accentRed
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Row {
                        spacing: 8
                        Text {
                            text: "L"
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 14
                            color: ThemeManager.fgTertiary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.lowTemp
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: ThemeManager.accentCyan
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        Rectangle {
            id: astroBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            height: 76
            color: ThemeManager.overlay(0.08)
            radius: 10

            Row {
                id: moonRow
                anchors.left: parent.left
                anchors.right: sunCol.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: root.moonEmoji[root.moonPhaseName] || "\ud83c\udf11"
                    font.family: "Noto Color Emoji"
                    font.pixelSize: 30
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44

                    Text {
                        text: root.moonPhaseName
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: ThemeManager.fgPrimary
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: root.moonIllumination
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                        color: ThemeManager.fgSecondary
                    }
                }
            }

            Column {
                id: sunCol
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Row {
                    spacing: 8
                    Text {
                        text: "\ud83c\udf05"
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.sunriseTime
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 13
                        color: ThemeManager.accentYellow
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    spacing: 8
                    Text {
                        text: "\ud83c\udf07"
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.sunsetTime
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 13
                        color: ThemeManager.accentOrange
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}

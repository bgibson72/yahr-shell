import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

Item {
    id: updates
    visible: Settings.showUpdateChecker
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 40

    property int count: 0
    property var lastCheckTime: new Date()

    Component.onCompleted: initialDelay.start()

    Timer {
        id: initialDelay
        interval: 10000
        running: false
        repeat: false
        onTriggered: {
            checkProc.running = true
            updates.lastCheckTime = new Date()
            hourlyTimer.running = true
        }
    }

    Timer {
        id: hourlyTimer
        interval: 3600000
        running: false
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            updates.lastCheckTime = new Date()
            checkProc.running = true
        }
    }

    // Catches long-sleep/suspend gaps where the hourly timer never fired.
    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: {
            const minutesSince = (new Date() - updates.lastCheckTime) / 60000
            if (minutesSince > 10) {
                updates.lastCheckTime = new Date()
                checkProc.running = true
            }
        }
    }

    Timer {
        id: recheckTimer
        interval: 10000
        running: false
        repeat: true
        property int attempts: 0
        onTriggered: {
            attempts++
            updates.lastCheckTime = new Date()
            checkProc.running = true
            if (attempts >= 30 || updates.count === 0) {
                running = false
                attempts = 0
            }
        }
    }

    Process {
        id: checkProc
        running: false
        command: [`${Quickshell.shellDir}/scripts/check-updates.sh`]
        stdout: StdioCollector {
            onStreamFinished: updates.count = parseInt(this.text.trim()) || 0
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf021"
            font.family: "Symbols Nerd Font"
            font.pixelSize: ThemeManager.fontSizeIcon
            color: updates.count > 0 ? ThemeManager.accentYellow : ThemeManager.fgSecondary
            Behavior on color { ColorAnimation { duration: 250 } }
        }

        Text {
            visible: updates.count > 0
            anchors.verticalCenter: parent.verticalCenter
            text: updates.count.toString()
            font.family: ThemeManager.uiFont
            font.pixelSize: ThemeManager.fontSizeSmall
            color: ThemeManager.accentYellow
        }
    }

    property bool hovered: mouse.containsMouse
    scale: mouse.pressed ? ThemeManager.iconPressScale : (mouse.containsMouse ? ThemeManager.iconHoverScale : 1.0)
    Behavior on scale {
        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const script = 'if command -v paru >/dev/null 2>&1; then paru -Syu; ' +
                           'elif command -v yay >/dev/null 2>&1; then yay -Syu; ' +
                           'else sudo pacman -Syu; fi; ' +
                           'echo ""; echo "Done - press enter to exit"; read'
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", script])
            recheckTimer.attempts = 0
            recheckTimer.running = true
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 300
    height: 360
    frameJoin: "right"
    slideOffsetX: -36
    slideOffsetY: -24
    entranceScale: 0.9

    property bool wifiRadio: true
    property string connectingSsid: ""
    property string connectError: ""

    readonly property string connectionType: NetworkState.connectionType
    readonly property string connectionName: {
        if (NetworkState.connectionType === "none")
            return "Disconnected"
        return NetworkState.connectionName || NetworkState.device || "Connected"
    }
    property bool scanning: false

    ListModel { id: networkModel }

    signal requestClose()

    focus: true
    Keys.onEscapePressed: root.requestClose()

    onIsVisibleChanged: {
        if (isVisible) {
            root.connectError = ""
            root.refresh()
        } else {
            root.connectingSsid = ""
        }
    }

    function refresh() {
        NetworkState.refresh()
        statusProc.running = false
        statusProc.running = true
        wifiListProc.running = false
        wifiListProc.running = true
    }

    function connectTo(ssid) {
        if (!ssid || ssid === root.connectingSsid)
            return
        root.connectError = ""
        root.connectingSsid = ssid
        wifiConnect.running = false
        wifiConnect.command = [
            "bash",
            `${Quickshell.shellDir}/scripts/wifi-connect.sh`,
            ssid
        ]
        wifiConnect.running = true
    }

    function openNetworkSettings() {
        Quickshell.execDetached([
            "bash",
            `${Quickshell.shellDir}/scripts/launch-network-settings.sh`
        ])
        root.requestClose()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Process {
        id: statusProc
        running: false
        command: ["sh", "-c", "echo RADIO:$(nmcli -t radio wifi)"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiRadio = this.text.indexOf("enabled") !== -1
            }
        }
    }

    Process {
        id: wifiListProc
        running: false
        command: ["sh", "-c", "nmcli -t device wifi rescan >/dev/null 2>&1; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const seen = {}
                const rows = []
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (!line)
                        continue
                    let active = false
                    if (line.charAt(0) === "*") {
                        active = true
                        line = line.slice(1)
                    }
                    const parts = line.split(":")
                    let ssid = ""
                    let signal = 0
                    let security = ""
                    if (parts[0] === "" || parts[0] === "*") {
                        ssid = (parts[1] || "").trim()
                        signal = parseInt(parts[2]) || 0
                        security = parts.slice(3).join(":").trim()
                    } else {
                        ssid = parts[0].trim()
                        signal = parseInt(parts[1]) || 0
                        security = parts.slice(2).join(":").trim()
                    }
                    if (!ssid || ssid === "--" || seen[ssid])
                        continue
                    seen[ssid] = true
                    rows.push({
                        active: active,
                        ssid: ssid,
                        signal: signal,
                        security: security
                    })
                }
                rows.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                networkModel.clear()
                const max = Math.min(rows.length, 8)
                for (let j = 0; j < max; j++)
                    networkModel.append(rows[j])
                root.scanning = false
            }
        }
        onRunningChanged: {
            if (running)
                root.scanning = true
        }
    }

    Process {
        id: wifiToggle
        running: false
        command: ["nmcli", "radio", "wifi", "on"]
        onExited: root.refresh()
    }

    Process {
        id: wifiConnect
        running: false
        command: ["true"]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: wifiConnectErr
        }
        onExited: code => {
            const target = root.connectingSsid
            root.connectingSsid = ""
            if (code === 0) {
                root.connectError = ""
                root.refresh()
                return
            }
            const detail = (wifiConnectErr.text || "").trim().split("\n").pop() || "Connection failed"
            root.connectError = target ? `${target}: ${detail}` : detail
            root.refresh()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.connectionType === "wifi" ? "󰤨" : (root.connectionType === "ethernet" ? "󰈀" : "󰌙")
                font.family: "Symbols Nerd Font"
                font.pixelSize: 22
                color: root.connectionType === "none" ? ThemeManager.accentRed : (root.connectionType === "ethernet" ? ThemeManager.accentBlue : ThemeManager.accentGreen)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: root.connectionType === "wifi" ? "Wi-Fi" : (root.connectionType === "ethernet" ? "Ethernet" : "Disconnected")
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.connectionName
                    color: ThemeManager.fgSecondary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: 44
                height: 24
                radius: 12
                color: root.wifiRadio ? ThemeManager.accentGreen : ThemeManager.surface1
                Behavior on color { ColorAnimation { duration: 140 } }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: ThemeManager.fgPrimary
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.wifiRadio ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wifiToggle.command = ["nmcli", "radio", "wifi", root.wifiRadio ? "off" : "on"]
                        wifiToggle.running = true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: ThemeManager.overlay(0.08)
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: networkModel
            boundsBehavior: Flickable.StopAtBounds

            Text {
                visible: networkModel.count === 0
                anchors.centerIn: parent
                text: root.scanning ? "Scanning…" : "No networks found"
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
            }

            delegate: Rectangle {
                required property bool active
                required property string ssid
                required property int signal
                required property string security

                readonly property bool isConnecting: root.connectingSsid === ssid

                width: ListView.view.width
                height: 32
                radius: 8
                opacity: root.connectingSsid.length > 0 && !isConnecting && !active ? 0.55 : 1.0
                color: netMouse.containsMouse ? ThemeManager.surface2 : (active ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.18) : ThemeManager.surface1)
                Behavior on opacity { NumberAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: {
                            if (isConnecting)
                                return "󰔟"
                            const s = signal
                            if (s >= 80) return "󰤨"
                            if (s >= 55) return "󰤥"
                            if (s >= 30) return "󰤢"
                            return "󰤟"
                        }
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: active || isConnecting ? ThemeManager.accentBlue : ThemeManager.fgSecondary
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: isConnecting ? `${ssid}…` : ssid
                        color: ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                    }
                    Text {
                        visible: security && security !== "--" && !isConnecting
                        text: "󰌾"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: ThemeManager.fgTertiary
                    }
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !active && root.connectingSsid.length === 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.connectTo(ssid)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.connectError.length > 0
            text: root.connectError
            color: ThemeManager.accentRed
            font.family: ThemeManager.uiFont
            font.pixelSize: 11
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 8
            color: moreMouse.containsMouse ? ThemeManager.surface2 : ThemeManager.surface1
            scale: moreMouse.pressed ? ThemeManager.bouncePressScale : (moreMouse.containsMouse ? ThemeManager.bounceHoverScale : 1.0)
            Behavior on scale {
                SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
            }

            Text {
                anchors.centerIn: parent
                text: "Network settings"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
            }
            MouseArea {
                id: moreMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openNetworkSettings()
            }
        }
    }
}

import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

Rectangle {
    id: root

    width: 1920
    height: 1080

    TextConstants { id: textConstants }

    property string background: config.stringValue("Background") || ""
    property int backgroundBlur: parseInt(config.stringValue("BackgroundBlur") || "0")
    property color themeColor: config.stringValue("ThemeColor") || "#6db3ce"
    property color accentColor: config.stringValue("AccentColor") || "#a78cfa"
    property color bgBase: config.stringValue("BgBase") || "#181625"
    property color bgSurface: config.stringValue("BgSurface") || "#2b2837"
    property color fgPrimary: config.stringValue("FgPrimary") || "#cdcbe0"
    property color fgSecondary: config.stringValue("FgSecondary") || "#aeafca"
    property color failColor: config.stringValue("FailColor") || "#eb746b"
    property string fontFamily: config.stringValue("Font") || "Inter"
    property string titleFontFamily: config.stringValue("TitleFont") || "Inter ExtraBold"
    property int fontSize: config.intValue("FontSize") || 13
    property int titleFontSize: config.intValue("TitleFontSize") || 56
    property bool enableAvatars: config.boolValue("EnableAvatars")
    property bool showHostname: config.boolValue("ShowHostname") !== false
    property bool showSessionButton: config.boolValue("ShowSessionButton") !== false
    property bool showPowerButtons: config.boolValue("ShowPowerButtons") !== false
    property string timeFormat: config.stringValue("TimeFormat") || "h:mm AP"
    property string dateFormat: config.stringValue("DateFormat") || "ddd MMM d"
    property real widgetOpacity: parseFloat(config.stringValue("WidgetOpacity") || "0.92")

    property string translateLogin: config.stringValue("TranslateLogin") || textConstants.login
    property string translateLoginFailed: config.stringValue("TranslateLoginFailed") || textConstants.loginFailed
    property string translateUsername: config.stringValue("TranslateUsername") || textConstants.userName
    property string translatePassword: config.stringValue("TranslatePassword") || textConstants.password
    property string translateSession: config.stringValue("TranslateSession") || textConstants.session
    property string translateSuspend: config.stringValue("TranslateSuspend") || textConstants.suspend
    property string translateReboot: config.stringValue("TranslateReboot") || textConstants.reboot
    property string translateShutdown: config.stringValue("TranslateShutdown") || textConstants.shutdown

    readonly property color plateColor: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 1.0)
    readonly property color cardColor: Qt.rgba(bgSurface.r, bgSurface.g, bgSurface.b, Math.min(1, widgetOpacity + 0.08))
    readonly property string lastUser: userModel.lastUser || ""
    readonly property string homeFace: lastUser !== "" ? "file:///home/" + lastUser + "/.face.icon" : ""
    readonly property string systemFace: lastUser !== "" ? "file:///usr/share/sddm/faces/" + lastUser + ".face.icon" : ""

    Image {
        id: backgroundImage
        anchors.fill: parent
        source: background !== "" ? (background.indexOf("/") === 0 || background.indexOf("file:") === 0
            ? background : Qt.resolvedUrl(background)) : ""
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
        cache: false

        layer.enabled: root.backgroundBlur > 0
        layer.effect: FastBlur {
            radius: root.backgroundBlur
        }
    }

    Rectangle {
        anchors.fill: parent
        color: bgBase
        visible: !backgroundImage.visible
    }

    Rectangle {
        id: plate
        anchors.centerIn: parent
        width: 580
        height: column.height + 80
        radius: 28
        color: plateColor

        Column {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 40
            width: parent.width - 72
            spacing: 18

            Rectangle {
                id: avatarFrame
                width: 196
                height: 196
                radius: plate.radius
                color: root.cardColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.enableAvatars

                Image {
                    id: avatar
                    property int faceTry: 0
                    readonly property var faceCandidates: root.homeFace !== "" ? [root.homeFace, root.systemFace] : []
                    anchors.fill: parent
                    source: faceTry < faceCandidates.length ? faceCandidates[faceTry] : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    cache: false
                    onStatusChanged: {
                        if (status === Image.Error && faceTry < faceCandidates.length - 1)
                            faceTry++
                    }
                }

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: avatarFrame.radius
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: avatar
                    maskSource: avatarMask
                    visible: avatar.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: avatar.status !== Image.Ready
                    text: root.lastUser !== "" ? root.lastUser.charAt(0).toUpperCase() : "\uf007"
                    font.family: root.lastUser !== "" ? root.fontFamily : "Symbols Nerd Font"
                    font.pixelSize: root.lastUser !== "" ? 72 : 48
                    font.weight: Font.Medium
                    color: root.themeColor
                }
            }

            Column {
                width: parent.width
                spacing: 4

                Text {
                    width: parent.width
                    text: Qt.formatTime(timeSource.currentDateTime, root.timeFormat)
                    font.family: root.titleFontFamily
                    font.pixelSize: root.titleFontSize
                    font.weight: Font.Bold
                    color: root.fgPrimary
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: Qt.formatDate(timeSource.currentDateTime, root.dateFormat)
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 3
                    color: root.themeColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: sddm.hostName
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    color: root.fgSecondary
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.showHostname && sddm.hostName !== ""
                }
            }

            Rectangle {
                width: parent.width
                height: 52
                radius: 18
                color: root.cardColor

                TextField {
                    id: usernameField
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    placeholderText: root.translateUsername
                    placeholderTextColor: Qt.rgba(root.fgSecondary.r, root.fgSecondary.g, root.fgSecondary.b, 0.65)
                    text: userModel.lastUser
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 1
                    color: root.fgPrimary
                    selectionColor: root.themeColor
                    selectedTextColor: root.bgBase
                    background: Item {}
                    Keys.onReturnPressed: passwordField.forceActiveFocus()
                    Keys.onTabPressed: passwordField.forceActiveFocus()
                }
            }

            Rectangle {
                width: parent.width
                height: 52
                radius: 18
                color: root.cardColor
                border.width: passwordField.activeFocus ? 2 : 0
                border.color: root.themeColor

                TextField {
                    id: passwordField
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    placeholderText: root.translatePassword
                    placeholderTextColor: Qt.rgba(root.fgSecondary.r, root.fgSecondary.g, root.fgSecondary.b, 0.65)
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 1
                    color: root.fgPrimary
                    echoMode: TextInput.Password
                    focus: true
                    selectionColor: root.themeColor
                    selectedTextColor: root.bgBase
                    background: Item {}
                    Keys.onReturnPressed: sddm.login(usernameField.text, passwordField.text, sessionCombo.index)
                    Keys.onEscapePressed: passwordField.text = ""
                    onTextChanged: loginFailedText.visible = false
                }
            }

            Text {
                id: loginFailedText
                width: parent.width
                text: root.translateLoginFailed
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                color: root.failColor
                horizontalAlignment: Text.AlignHCenter
                visible: false

                Connections {
                    target: sddm
                    function onLoginFailed() {
                        loginFailedText.visible = true
                        passwordField.selectAll()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 52
                radius: 18
                color: loginMouse.containsPress ? Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.40)
                     : loginMouse.containsMouse ? Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.28)
                     : Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: root.translateLogin
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 2
                    font.weight: Font.DemiBold
                    color: root.themeColor
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.login(usernameField.text, passwordField.text, sessionCombo.index)
                }
            }

            Rectangle {
                id: sessionCombo
                visible: root.showSessionButton
                width: 200
                height: 52
                radius: 26
                color: root.cardColor
                anchors.horizontalCenter: parent.horizontalCenter
                property int index: sessionModel.lastIndex

                Repeater {
                    id: sessionRepeater
                    model: sessionModel
                    Item {
                        property string sessionName: model.name || ""
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    color: root.fgPrimary
                    text: {
                        sessionCombo.index
                        if (sessionRepeater.count === 0)
                            return root.translateSession
                        const item = sessionRepeater.itemAt(sessionCombo.index)
                        return (item && item.sessionName) ? item.sessionName : root.translateSession
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (sessionRepeater.count < 2)
                            return
                        sessionCombo.index = (sessionCombo.index + 1) % sessionRepeater.count
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                visible: root.showPowerButtons

                Repeater {
                    model: [
                        { glyph: "󰒲", kind: "suspend" },
                        { glyph: "󰜉", kind: "reboot" },
                        { glyph: "󰐥", kind: "shutdown" }
                    ]

                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        color: powerMouse.containsMouse ? Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.22) : root.cardColor

                        Text {
                            anchors.centerIn: parent
                            text: modelData.glyph
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 18
                            color: modelData.kind === "shutdown" ? root.failColor : root.fgPrimary
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.kind === "suspend")
                                    sddm.suspend()
                                else if (modelData.kind === "reboot")
                                    sddm.reboot()
                                else
                                    sddm.powerOff()
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: timeSource
        property var currentDateTime: new Date()
        interval: 1000
        repeat: true
        running: true
        onTriggered: currentDateTime = new Date()
    }

    Component.onCompleted: {
        if (usernameField.text === "")
            usernameField.forceActiveFocus()
        else
            passwordField.forceActiveFocus()
    }
}

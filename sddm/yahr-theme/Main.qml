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
    // Fixed greeter blur; theme.conf is kept in sync by sddm-apply.
    property int backgroundBlur: {
        const v = config.intValue("BackgroundBlur")
        return v > 0 ? v : 40
    }
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
    property real widgetOpacity: parseFloat(config.stringValue("WidgetOpacity") || "0.75")

    property string translateLogin: config.stringValue("TranslateLogin") || textConstants.login
    property string translateLoginFailed: config.stringValue("TranslateLoginFailed") || textConstants.loginFailed
    property string translateUsername: config.stringValue("TranslateUsername") || textConstants.userName
    property string translatePassword: config.stringValue("TranslatePassword") || textConstants.password
    property string translateSession: config.stringValue("TranslateSession") || textConstants.session
    property string translateSuspend: config.stringValue("TranslateSuspend") || "Sleep"
    property string translateReboot: config.stringValue("TranslateReboot") || "Restart"
    property string translateShutdown: config.stringValue("TranslateShutdown") || "Power Off"

    readonly property color dockColor: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, Math.min(0.92, Math.max(0.72, widgetOpacity + 0.12)))
    readonly property color cardColor: Qt.rgba(bgSurface.r, bgSurface.g, bgSurface.b, Math.min(1, widgetOpacity + 0.18))
    readonly property color loginLabelColor: {
        // Contrast against the filled accent button (works for light + dark palettes).
        const r = themeColor.r, g = themeColor.g, b = themeColor.b
        const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return lum > 0.62 ? Qt.rgba(0.1, 0.1, 0.12, 1) : bgBase
    }
    readonly property string lastUser: userModel.lastUser || ""
    readonly property string homeFace: lastUser !== "" ? "file:///home/" + lastUser + "/.face.icon" : ""
    readonly property string systemFace: lastUser !== "" ? "file:///usr/share/sddm/faces/" + lastUser + ".face.icon" : ""
    readonly property int avatarSize: 140
    readonly property int dockWidth: Math.min(860, Math.max(560, width * 0.48))
    readonly property var backgroundFallbacks: {
        const names = []
        const seen = {}
        const add = name => {
            if (!name || seen[name])
                return
            seen[name] = true
            names.push(name)
        }
        add(background)
        add("login-background.png")
        add("login-background.jpg")
        add("login-background.jpeg")
        add("login-background.webp")
        return names
    }

    function doLogin() {
        sddm.login(usernameField.text, passwordField.text, sessionCombo.index)
    }

    Image {
        id: backgroundImage
        property int sourceTry: 0
        anchors.fill: parent
        source: {
            const name = root.backgroundFallbacks[sourceTry] || ""
            if (name === "")
                return ""
            if (name.indexOf("/") === 0 || name.indexOf("file:") === 0)
                return name
            return Qt.resolvedUrl(name)
        }
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
        cache: false
        onStatusChanged: {
            if (status === Image.Error && sourceTry < root.backgroundFallbacks.length - 1)
                sourceTry++
        }

        layer.enabled: root.backgroundBlur > 0 && status === Image.Ready
        layer.effect: FastBlur {
            radius: root.backgroundBlur
        }
    }

    Rectangle {
        anchors.fill: parent
        color: bgBase
        visible: !backgroundImage.visible
    }

    // Soft theme-tinted scrims so clock/dock stay readable on any wallpaper.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.42) }
            GradientStop { position: 0.38; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.05) }
            GradientStop { position: 0.72; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.18) }
            GradientStop { position: 1.0; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.62) }
        }
    }

    Column {
        id: clockColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(48, parent.height * 0.08)
        spacing: 8

        Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), root.timeFormat)
            font.family: root.titleFontFamily
            font.pixelSize: Math.max(72, Math.min(104, root.titleFontSize + 36))
            font.weight: Font.Bold
            color: root.fgPrimary
            style: Text.Outline
            styleColor: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.35)

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: timeLabel.text = Qt.formatTime(new Date(), root.timeFormat)
            }
        }

        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), root.dateFormat)
            font.family: root.fontFamily
            font.pixelSize: root.fontSize + 5
            font.weight: Font.Medium
            color: root.fgSecondary

            Timer {
                interval: 30000
                running: true
                repeat: true
                onTriggered: dateLabel.text = Qt.formatDate(new Date(), root.dateFormat)
            }
        }

        Text {
            visible: root.showHostname
            anchors.horizontalCenter: parent.horizontalCenter
            text: sddm.hostName || ""
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            color: root.fgSecondary
            opacity: 0.8
        }
    }

    Item {
        id: dockHost
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(48, parent.height * 0.07)
        width: root.dockWidth
        height: dock.implicitHeight + root.avatarSize * 0.52

        DropShadow {
            anchors.fill: dock
            source: dock
            horizontalOffset: 0
            verticalOffset: 22
            radius: 36
            samples: 52
            color: Qt.rgba(0, 0, 0, 0.55)
            cached: true
        }

        Rectangle {
            id: avatarFrame
            z: 2
            width: root.avatarSize
            height: root.avatarSize
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            color: root.cardColor
            border.width: 4
            border.color: Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.55)
            visible: root.enableAvatars

            Image {
                id: avatar
                property int faceTry: 0
                readonly property var faceCandidates: root.homeFace !== "" ? [root.homeFace, root.systemFace] : []
                anchors.fill: parent
                anchors.margins: 4
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
                anchors.fill: avatar
                radius: width / 2
                visible: false
            }

            OpacityMask {
                anchors.fill: avatar
                source: avatar
                maskSource: avatarMask
                visible: avatar.status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                text: {
                    const name = usernameField.text || root.lastUser
                    if (name !== "")
                        return name.charAt(0).toUpperCase()
                    return "\uf007"
                }
                font.family: (usernameField.text || root.lastUser) !== "" ? root.fontFamily : "Symbols Nerd Font"
                font.pixelSize: (usernameField.text || root.lastUser) !== "" ? 56 : 40
                font.weight: Font.DemiBold
                color: root.themeColor
            }
        }

        Rectangle {
            id: dock
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitHeight: dockColumn.implicitHeight + 56
            height: implicitHeight
            radius: 28
            color: root.dockColor
            border.width: 1
            border.color: Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.22)

            Column {
                id: dockColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                anchors.bottomMargin: 24
                // Leave room for the overlapping avatar.
                topPadding: root.enableAvatars ? root.avatarSize * 0.42 : 8
                spacing: 14

                Row {
                    id: fieldRow
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: (parent.width - loginBtn.width - parent.spacing * 2) / 2
                        height: 52
                        radius: 16
                        color: root.cardColor
                        border.width: usernameField.activeFocus ? 2 : 0
                        border.color: root.themeColor

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
                        width: (parent.width - loginBtn.width - parent.spacing * 2) / 2
                        height: 52
                        radius: 16
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
                            Keys.onReturnPressed: root.doLogin()
                            Keys.onEscapePressed: passwordField.text = ""
                            onTextChanged: loginFailedText.visible = false
                        }
                    }

                    Rectangle {
                        id: loginBtn
                        width: 128
                        height: 52
                        radius: 16
                        color: loginMouse.containsPress ? Qt.darker(root.themeColor, 1.12)
                             : loginMouse.containsMouse ? Qt.lighter(root.themeColor, 1.08)
                             : root.themeColor

                        Text {
                            anchors.centerIn: parent
                            text: root.translateLogin
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize + 2
                            font.weight: Font.DemiBold
                            color: root.loginLabelColor
                        }

                        MouseArea {
                            id: loginMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.doLogin()
                        }
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
                            passwordField.forceActiveFocus()
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        id: sessionCombo
                        visible: root.showSessionButton
                        width: Math.min(180, parent.width * 0.34)
                        height: 36
                        radius: 18
                        color: root.cardColor
                        border.width: 1
                        border.color: Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.35)
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
                            color: root.themeColor
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

                    Item {
                        width: Math.max(0, parent.width
                            - (sessionCombo.visible ? sessionCombo.width + parent.spacing : 0)
                            - powerRow.width)
                        height: 1
                    }

                    Row {
                        id: powerRow
                        spacing: 8
                        visible: root.showPowerButtons

                        Repeater {
                            model: [
                                { label: root.translateSuspend, kind: "suspend" },
                                { label: root.translateReboot, kind: "reboot" },
                                { label: root.translateShutdown, kind: "shutdown" }
                            ]

                            Rectangle {
                                height: 36
                                width: Math.max(78, powerLabel.implicitWidth + 22)
                                radius: 14
                                color: powerMouse.containsMouse
                                    ? Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.22)
                                    : root.cardColor

                                Text {
                                    id: powerLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 1
                                    font.weight: Font.DemiBold
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
        }
    }

    Component.onCompleted: {
        if (usernameField.text === "")
            usernameField.forceActiveFocus()
        else
            passwordField.forceActiveFocus()
    }
}

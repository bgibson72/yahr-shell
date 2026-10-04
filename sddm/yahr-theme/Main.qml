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
    property string translateSuspend: config.stringValue("TranslateSuspend") || "Sleep"
    property string translateReboot: config.stringValue("TranslateReboot") || "Restart"
    property string translateShutdown: config.stringValue("TranslateShutdown") || "Power Off"

    readonly property color plateColor: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 1.0)
    readonly property color cardColor: Qt.rgba(bgSurface.r, bgSurface.g, bgSurface.b, Math.min(1, widgetOpacity + 0.08))
    readonly property string lastUser: userModel.lastUser || ""
    readonly property string homeFace: lastUser !== "" ? "file:///home/" + lastUser + "/.face.icon" : ""
    readonly property string systemFace: lastUser !== "" ? "file:///usr/share/sddm/faces/" + lastUser + ".face.icon" : ""
    readonly property url backgroundSource: {
        if (background === "")
            return ""
        if (background.indexOf("/") === 0 || background.indexOf("file:") === 0)
            return background
        return Qt.resolvedUrl(background)
    }
    readonly property string welcomeName: {
        const name = (usernameField.text || root.lastUser || "").trim()
        if (name === "")
            return "!"
        return name.charAt(0).toUpperCase() + name.slice(1) + "!"
    }

    Image {
        id: backgroundImage
        anchors.fill: parent
        source: root.backgroundSource
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
        width: Math.min(920, parent.width * 0.78)
        height: 480
        radius: 28
        color: plateColor

        // clip:true does not honor radius — mask the whole plate so the hero
        // wallpaper gets the same rounded corners as the solid right side.
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Item {
                width: plate.width
                height: plate.height
                Rectangle {
                    anchors.fill: parent
                    radius: plate.radius
                    color: "#ffffff"
                }
            }
        }

        Row {
            anchors.fill: parent

            // ── Left: wallpaper crop + stacked welcome ──────────────────────
            Item {
                id: hero
                width: plate.width / 2
                height: plate.height

                Image {
                    id: heroImage
                    anchors.fill: parent
                    // Same asset as the full-screen Background. Blur is applied only
                    // on the desktop Image via FastBlur, so this crop stays sharp and
                    // cannot drift to a stale login-hero.* file.
                    source: root.backgroundSource
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    cache: false
                    asynchronous: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.bgSurface
                    visible: !heroImage.visible
                }

                // Light scrim only — keep the hero wallpaper looking sharp.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(root.bgBase.r, root.bgBase.g, root.bgBase.b, 0.28) }
                        GradientStop { position: 0.50; color: Qt.rgba(root.bgBase.r, root.bgBase.g, root.bgBase.b, 0.08) }
                        GradientStop { position: 1.0; color: Qt.rgba(root.bgBase.r, root.bgBase.g, root.bgBase.b, 0.32) }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.60; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(root.bgBase.r, root.bgBase.g, root.bgBase.b, 0.35) }
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 36
                    anchors.rightMargin: 28
                    anchors.bottomMargin: 40
                    spacing: 0

                    Text {
                        width: parent.width
                        text: "Welcome"
                        font.family: root.titleFontFamily
                        font.pixelSize: Math.max(40, Math.min(root.titleFontSize, hero.width * 0.14))
                        font.weight: Font.Bold
                        color: root.fgPrimary
                        wrapMode: Text.NoWrap
                    }

                    Text {
                        width: parent.width
                        text: "Back,"
                        font.family: root.titleFontFamily
                        font.pixelSize: Math.max(40, Math.min(root.titleFontSize, hero.width * 0.14))
                        font.weight: Font.Bold
                        color: root.fgPrimary
                        wrapMode: Text.NoWrap
                    }

                    Text {
                        width: parent.width
                        text: root.welcomeName
                        font.family: root.titleFontFamily
                        font.pixelSize: Math.max(40, Math.min(root.titleFontSize, hero.width * 0.14))
                        font.weight: Font.Bold
                        color: root.themeColor
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }
            }

            // ── Right: avatar, fields, session, power ───────────────────────
            Item {
                id: formPanel
                width: plate.width / 2
                height: plate.height

                Column {
                    id: formColumn
                    anchors.centerIn: parent
                    width: parent.width - 88
                    spacing: 14

                    Rectangle {
                        id: avatarFrame
                        width: 96
                        height: 96
                        radius: 48
                        color: root.cardColor
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.enableAvatars
                        border.width: 3
                        border.color: Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.40)

                        Image {
                            id: avatar
                            property int faceTry: 0
                            readonly property var faceCandidates: root.homeFace !== "" ? [root.homeFace, root.systemFace] : []
                            anchors.fill: parent
                            anchors.margins: 3
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
                            font.pixelSize: (usernameField.text || root.lastUser) !== "" ? 40 : 28
                            font.weight: Font.Medium
                            color: root.themeColor
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 16
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
                        height: 48
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
                        height: 48
                        radius: 16
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
                        width: Math.min(200, parent.width)
                        height: 40
                        radius: 20
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
                        spacing: 10
                        visible: root.showPowerButtons

                        Repeater {
                            model: [
                                { label: root.translateSuspend, kind: "suspend" },
                                { label: root.translateReboot, kind: "reboot" },
                                { label: root.translateShutdown, kind: "shutdown" }
                            ]

                            Rectangle {
                                height: 36
                                width: Math.max(72, powerLabel.implicitWidth + 24)
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

import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

// YAHR_SDDM_MAIN_V=5 equal-frame + loader-panel
// Frame + joins are inlined so sddm-apply only needs to copy this one QML file.
// V5: uniform radius only (per-corner props need Qt 6.7+) and no anchors/width
// reset via undefined (those abort the greeter → embedded default theme).

Rectangle {
    id: root

    width: 1920
    height: 1080

    TextConstants { id: textConstants }

    property string background: config.stringValue("Background") || ""
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
    property string fontKey: config.stringValue("FontKey") || config.stringValue("Font") || "Inter"
    property string fontHint: config.stringValue("Font") || "Inter"
    property int fontSize: config.intValue("FontSize") || 13
    property int titleFontSize: config.intValue("TitleFontSize") || 56
    property bool enableAvatars: config.boolValue("EnableAvatars")
    property bool showHostname: config.boolValue("ShowHostname") !== false
    property bool showSessionButton: config.boolValue("ShowSessionButton") !== false
    property bool showPowerButtons: config.boolValue("ShowPowerButtons") !== false
    property string timeFormat: config.stringValue("TimeFormat") || "h:mm AP"
    property string dateFormat: config.stringValue("DateFormat") || "ddd MMM d"
    property real widgetOpacity: parseFloat(config.stringValue("WidgetOpacity") || "0.75")

    property bool useFrame: {
        const v = config.stringValue("UseFrame")
        if (v === "false" || v === "0")
            return false
        return true
    }
    property int frameThickness: {
        const v = config.intValue("FrameThickness")
        return v > 0 ? v : 10
    }
    property int frameInnerRadius: {
        const v = config.intValue("FrameInnerRadius")
        return v > 0 ? v : 12
    }
    property real frameOpacity: {
        const v = parseFloat(config.stringValue("FrameOpacity") || "0.92")
        return isNaN(v) ? 0.92 : Math.max(0.5, Math.min(1, v))
    }

    property string translateLogin: config.stringValue("TranslateLogin") || textConstants.login
    property string translateLoginFailed: config.stringValue("TranslateLoginFailed") || textConstants.loginFailed
    property string translateUsername: config.stringValue("TranslateUsername") || textConstants.userName
    property string translatePassword: config.stringValue("TranslatePassword") || textConstants.password
    property string translateSession: config.stringValue("TranslateSession") || textConstants.session
    property string translateSuspend: config.stringValue("TranslateSuspend") || "Sleep"
    property string translateReboot: config.stringValue("TranslateReboot") || "Restart"
    property string translateShutdown: config.stringValue("TranslateShutdown") || "Power Off"

    readonly property var uiFontCatalog: [
        { key: "Inter", families: ["Inter", "Inter Variable"] },
        { key: "Source Sans", families: ["Source Sans 3", "Source Sans Variable", "Source Sans 3 VF", "Source Sans Pro"] },
        { key: "Roboto", families: ["Roboto Flex", "Roboto"] },
        { key: "Manrope", families: ["Manrope"] },
        { key: "Overpass", families: ["Overpass", "Overpass Nerd Font"] },
        { key: "Space Grotesk", families: ["Space Grotesk", "SpaceGrotesk"] },
        { key: "IBM Plex Sans", families: ["IBM Plex Sans Var", "IBM Plex Sans"] }
    ]

    function listHas(list, name) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === name)
                return true
        }
        return false
    }

    function normalizeFontKey(name) {
        return String(name || "").toLowerCase().replace(/[^a-z0-9]/g, "")
    }

    function matchFamily(installed, name) {
        let best = ""
        const want = normalizeFontKey(name)
        for (let i = 0; i < installed.length; i++) {
            const fam = installed[i]
            if (fam === name)
                return fam
            if (fam.toLowerCase() === String(name).toLowerCase())
                return fam
            const norm = normalizeFontKey(fam)
            if (norm === want)
                return fam
            if (fam.indexOf(name + " ") === 0 && (!best || fam.length < best.length))
                best = fam
        }
        return best
    }

    function resolveUiFont(stored, hint) {
        const wanted = stored || hint || "Inter"
        let families = []
        if (hint)
            families.push(hint)
        families.push(wanted)
        for (let i = 0; i < uiFontCatalog.length; i++) {
            const item = uiFontCatalog[i]
            const keyNorm = normalizeFontKey(item.key)
            const wantNorm = normalizeFontKey(wanted)
            if (item.key === wanted || listHas(item.families, wanted)
                || keyNorm === wantNorm
                || (wantNorm.indexOf("space") !== -1 && wantNorm.indexOf("grost") !== -1 && item.key === "Space Grotesk")) {
                for (let k = 0; k < item.families.length; k++)
                    families.push(item.families[k])
                break
            }
        }
        const seen = {}
        const ordered = []
        for (let n = 0; n < families.length; n++) {
            const f = families[n]
            if (!f || seen[f])
                continue
            seen[f] = true
            ordered.push(f)
        }
        const installed = Qt.fontFamilies()
        for (let j = 0; j < ordered.length; j++) {
            const found = matchFamily(installed, ordered[j])
            if (found)
                return found
        }
        return ordered[0] || "Inter"
    }

    readonly property string fontFamily: resolveUiFont(fontKey, fontHint)
    readonly property int holeInset: useFrame ? frameThickness : 0
    readonly property color frameFill: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, frameOpacity)
    readonly property color dockColor: useFrame
        ? frameFill
        : Qt.rgba(bgBase.r, bgBase.g, bgBase.b, Math.min(0.92, Math.max(0.72, widgetOpacity + 0.12)))
    readonly property color cardColor: Qt.rgba(bgSurface.r, bgSurface.g, bgSurface.b, Math.min(1, widgetOpacity + 0.18))
    readonly property color loginLabelColor: {
        const r = themeColor.r, g = themeColor.g, b = themeColor.b
        const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return lum > 0.62 ? Qt.rgba(0.1, 0.1, 0.12, 1) : bgBase
    }
    readonly property string lastUser: userModel.lastUser || ""
    readonly property string homeFace: lastUser !== "" ? "file:///home/" + lastUser + "/.face.icon" : ""
    readonly property string systemFace: lastUser !== "" ? "file:///usr/share/sddm/faces/" + lastUser + ".face.icon" : ""
    readonly property int avatarSize: 140
    readonly property int dockWidth: Math.min(860, Math.max(560, width * 0.48))
    readonly property int tabHeight: 44
    readonly property int joinR: useFrame ? frameInnerRadius : 0
    readonly property int dockRadius: useFrame ? frameInnerRadius : 28
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

    property bool loginOpen: false
    property real loginReveal: 0
    Behavior on loginReveal {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    function doLogin() {
        const body = panelLoader.item
        if (!body)
            return
        sddm.login(body.userField.text, body.passField.text, body.sessionIndex)
    }

    function openLogin() {
        loginOpen = true
        loginReveal = 1
        openFocusTimer.restart()
    }

    function closeLogin() {
        loginOpen = false
        loginReveal = 0
    }

    function toggleLogin() {
        if (loginOpen)
            closeLogin()
        else
            openLogin()
    }

    Timer {
        id: openFocusTimer
        interval: 280
        onTriggered: {
            if (!root.loginOpen || !panelLoader.item)
                return
            const body = panelLoader.item
            if (!body.userField.text)
                body.userField.forceActiveFocus()
            else
                body.passField.forceActiveFocus()
        }
    }

    // Fully unload the form when the close animation finishes.
    Timer {
        id: unloadTimer
        interval: 450
        onTriggered: {
            if (!root.loginOpen && root.loginReveal < 0.01)
                panelLoader.active = false
        }
    }

    onLoginRevealChanged: {
        if (loginReveal < 0.01 && !loginOpen)
            unloadTimer.restart()
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
        layer.effect: FastBlur { radius: root.backgroundBlur }
    }

    Rectangle {
        anchors.fill: parent
        color: bgBase
        visible: !backgroundImage.visible
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.useFrame
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.42) }
            GradientStop { position: 0.38; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.05) }
            GradientStop { position: 0.72; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.18) }
            GradientStop { position: 1.0; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.62) }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.useFrame
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.18) }
            GradientStop { position: 0.45; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.04) }
            GradientStop { position: 1.0; color: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, 0.28) }
        }
    }

    // Equal thickness on all four sides — never use bar height.
    Item {
        id: screenFrame
        visible: root.useFrame
        z: 5
        anchors.fill: parent

        onWidthChanged: frameCanvas.requestPaint()
        onHeightChanged: frameCanvas.requestPaint()
        Component.onCompleted: frameCanvas.requestPaint()

        Connections {
            target: root
            function onFrameThicknessChanged() { frameCanvas.requestPaint() }
            function onFrameInnerRadiusChanged() { frameCanvas.requestPaint() }
            function onFrameFillChanged() { frameCanvas.requestPaint() }
            function onUseFrameChanged() { if (root.useFrame) frameCanvas.requestPaint() }
        }

        Canvas {
            id: frameCanvas
            anchors.fill: parent
            antialiasing: false
            onPaint: {
                const ctx = getContext("2d")
                const w = screenFrame.width
                const h = screenFrame.height
                const t = Math.max(1, root.frameThickness)
                const joinTop = t
                const joinBot = Math.max(joinTop + 2, h - t)
                const innerW = w - 2 * t
                const innerH = joinBot - joinTop
                let rr = root.frameInnerRadius
                if (rr * 2 > innerW)
                    rr = Math.max(0, innerW / 2)
                if (rr * 2 > innerH)
                    rr = Math.max(0, innerH / 2)
                if (w < 2 || h < 2)
                    return

                function invCorner(x0, y0, kind) {
                    ctx.beginPath()
                    if (kind === "tl") {
                        ctx.moveTo(x0, y0)
                        ctx.lineTo(x0 + rr, y0)
                        ctx.arc(x0 + rr, y0 + rr, rr, -Math.PI / 2, Math.PI, true)
                    } else if (kind === "tr") {
                        ctx.moveTo(x0, y0)
                        ctx.lineTo(x0, y0 + rr)
                        ctx.arc(x0 - rr, y0 + rr, rr, 0, -Math.PI / 2, true)
                    } else if (kind === "bl") {
                        ctx.moveTo(x0, y0)
                        ctx.lineTo(x0, y0 - rr)
                        ctx.arc(x0 + rr, y0 - rr, rr, Math.PI, Math.PI / 2, true)
                    } else {
                        ctx.moveTo(x0, y0)
                        ctx.lineTo(x0 - rr, y0)
                        ctx.arc(x0 - rr, y0 - rr, rr, Math.PI / 2, 0, true)
                    }
                    ctx.closePath()
                    ctx.fill()
                }

                ctx.clearRect(0, 0, w, h)
                ctx.fillStyle = root.frameFill
                ctx.fillRect(0, 0, t, h)
                ctx.fillRect(w - t, 0, t, h)
                ctx.fillRect(t, 0, w - 2 * t, joinTop)
                ctx.fillRect(t, joinBot, w - 2 * t, h - joinBot)
                if (rr >= 1) {
                    invCorner(t, joinTop, "tl")
                    invCorner(w - t, joinTop, "tr")
                    invCorner(t, joinBot, "bl")
                    invCorner(w - t, joinBot, "br")
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: root.loginOpen
        onClicked: root.closeLogin()
    }

    Column {
        id: clockColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.useFrame
            ? root.holeInset + Math.max(28, parent.height * 0.05)
            : Math.max(48, parent.height * 0.08)
        spacing: 8
        z: 2

        Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), root.timeFormat)
            font.family: root.fontFamily
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

    Component {
        id: loginPanelComponent
        Rectangle {
            id: dockBody
            property alias userField: usernameField
            property alias passField: passwordField
            property alias sessionIndex: sessionCombo.index
            // Parent is the Loader; bind to its width (avoid outer-id timing / zero width).
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: dockColumn.implicitHeight + 40
            height: implicitHeight
            // Uniform radius only — per-corner radius props need Qt 6.7+ and crash older greeters.
            radius: root.dockRadius
            color: root.dockColor
            border.width: root.useFrame ? 0 : 1
            border.color: Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.22)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: {}
            }

            Column {
                id: dockColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                anchors.bottomMargin: 18
                topPadding: root.enableAvatars ? root.avatarSize * 0.42 : 8
                spacing: 14

                Row {
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
                            Keys.onEscapePressed: root.closeLogin()
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
                            selectionColor: root.themeColor
                            selectedTextColor: root.bgBase
                            background: Item {}
                            Keys.onReturnPressed: root.doLogin()
                            Keys.onEscapePressed: {
                                if (passwordField.text !== "")
                                    passwordField.text = ""
                                else
                                    root.closeLogin()
                            }
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
                            root.openLogin()
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
                            Item { property string sessionName: model.name || "" }
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

    Item {
        id: loginHost
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.useFrame ? root.holeInset : Math.max(48, parent.height * 0.07)
        width: root.dockWidth + (root.useFrame ? root.joinR * 2 : 0)
        height: root.tabHeight + panelSlot.height
            + (root.enableAvatars ? Math.round(root.avatarSize * 0.52 * root.loginReveal) : 0)
        z: 6

        Canvas {
            id: frameJoins
            antialiasing: false
            z: 1
            readonly property int chromeX: root.useFrame ? root.joinR : loginTab.x
            readonly property int chromeY: loginTab.y - panelSlot.height
            readonly property int chromeW: root.useFrame ? root.dockWidth : loginTab.width
            readonly property int chromeH: root.tabHeight + panelSlot.height
            x: chromeX - root.joinR
            y: chromeY - root.joinR
            width: Math.max(0, chromeW + root.joinR * 2)
            height: Math.max(0, chromeH + root.joinR * 2)
            visible: root.useFrame && root.joinR > 1 && chromeW > 1 && chromeH > 1
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: root
                function onFrameFillChanged() { frameJoins.requestPaint() }
                function onJoinRChanged() { frameJoins.requestPaint() }
                function onLoginRevealChanged() { frameJoins.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                const rr = root.joinR
                const w = frameJoins.chromeW
                const h = frameJoins.chromeH
                if (rr < 1 || w < 2 || h < 2)
                    return
                ctx.clearRect(0, 0, frameJoins.width, frameJoins.height)
                ctx.fillStyle = root.frameFill
                function inv(x0, y0, kind) {
                    const x = x0 + rr
                    const y = y0 + rr
                    ctx.beginPath()
                    if (kind === "bl") {
                        ctx.moveTo(x, y)
                        ctx.lineTo(x, y - rr)
                        ctx.arc(x + rr, y - rr, rr, Math.PI, Math.PI / 2, true)
                    } else {
                        ctx.moveTo(x, y)
                        ctx.lineTo(x - rr, y)
                        ctx.arc(x - rr, y - rr, rr, Math.PI / 2, 0, true)
                    }
                    ctx.closePath()
                    ctx.fill()
                }
                inv(0, h, "bl")
                inv(w, h, "br")
            }
        }

        Rectangle {
            id: avatarFrame
            z: 3
            width: root.avatarSize
            height: root.avatarSize
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: panelSlot.top
            anchors.bottomMargin: -root.avatarSize * 0.48
            color: root.cardColor
            border.width: 4
            border.color: Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.55)
            visible: root.enableAvatars && root.loginReveal > 0.02
            opacity: root.loginReveal
            scale: 0.85 + 0.15 * root.loginReveal

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
                    const typed = (panelLoader.item && panelLoader.item.userField)
                        ? panelLoader.item.userField.text : ""
                    const name = typed || root.lastUser
                    if (name !== "")
                        return name.charAt(0).toUpperCase()
                    return "\uf007"
                }
                font.family: {
                    const typed = (panelLoader.item && panelLoader.item.userField)
                        ? panelLoader.item.userField.text : ""
                    return (typed || root.lastUser) !== "" ? root.fontFamily : "Symbols Nerd Font"
                }
                font.pixelSize: {
                    const typed = (panelLoader.item && panelLoader.item.userField)
                        ? panelLoader.item.userField.text : ""
                    return (typed || root.lastUser) !== "" ? 56 : 40
                }
                font.weight: Font.DemiBold
                color: root.themeColor
            }
        }

        Item {
            id: panelSlot
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: loginTab.top
            anchors.leftMargin: root.useFrame ? root.joinR : 0
            anchors.rightMargin: root.useFrame ? root.joinR : 0
            height: {
                if (!panelLoader.item)
                    return 0
                return Math.round(panelLoader.item.implicitHeight * root.loginReveal)
            }
            clip: true
            visible: height > 0
            z: 2

            Loader {
                id: panelLoader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                active: false
                sourceComponent: loginPanelComponent
                onLoaded: {
                    if (root.loginOpen)
                        openFocusTimer.restart()
                }
            }
        }

        Rectangle {
            id: loginTab
            // Width-only layout: never mix horizontalCenter with left/right, and never
            // assign anchors/width to undefined (greeter treats that as a load error).
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: root.useFrame
                ? Math.max(0, parent.width - 2 * root.joinR)
                : Math.max(120, tabRow.implicitWidth + 36)
            height: root.tabHeight
            // Flat when open so the plate joins cleanly; rounded when collapsed.
            radius: {
                if (!root.useFrame)
                    return 18
                return root.loginOpen ? 0 : root.dockRadius
            }
            color: tabMouse.containsMouse
                ? Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.22)
                : root.dockColor
            border.width: root.useFrame ? 0 : 1
            border.color: Qt.rgba(root.themeColor.r, root.themeColor.g, root.themeColor.b, 0.28)
            z: 4

            Row {
                id: tabRow
                anchors.centerIn: parent
                spacing: loginLabel.visible ? 10 : 0

                Text {
                    id: loginLabel
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.loginOpen
                    text: root.translateLogin
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 2
                    font.weight: Font.DemiBold
                    color: root.fgPrimary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.loginOpen ? "\uf078" : "\uf077"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: root.fontSize + 1
                    color: root.themeColor
                }
            }

            MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: 2
                onClicked: root.toggleLogin()
            }
        }
    }

    // Activate the Loader when opening so the plate exists before reveal animates.
    onLoginOpenChanged: {
        if (loginOpen) {
            unloadTimer.stop()
            panelLoader.active = true
        } else {
            unloadTimer.restart()
        }
    }

    Component.onCompleted: {
        root.loginOpen = false
        root.loginReveal = 0
        panelLoader.active = false
    }
}

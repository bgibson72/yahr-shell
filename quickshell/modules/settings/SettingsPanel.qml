import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"

Panel {
    id: root
    width: 780
    height: 620
    property bool isVisible: false
    property string tab: "theme"
    property var themes: []
    property string seedBg: "#1e1e2e"
    property string seedBlue: "#89b4fa"
    property string seedPurple: "#cba6f7"
    property string seedPink: "#f5c2e7"
    property string seedRed: "#f38ba8"
    property string seedOrange: "#fab387"
    property string seedYellow: "#f9e2af"
    property string seedGreen: "#a6e3a1"
    property string seedTeal: "#94e2d5"
    property string saveName: "Custom"

    signal requestClose()
    focus: true
    Keys.onEscapePressed: root.requestClose()

    onIsVisibleChanged: if (isVisible) themeList.running = true

    Process {
        id: themeList
        running: false
        command: ["yahr-theme", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const out = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (!line.trim())
                        continue
                    const active = line.trim().startsWith("*")
                    const parts = line.replace(/^\*\s*/, "").trim().split(/\s{2,}/)
                    out.push({
                        id: parts[0],
                        name: parts[1] || parts[0],
                        custom: (parts[2] || "").indexOf("custom") !== -1,
                        active: active
                    })
                }
                root.themes = out
            }
        }
    }

    Process {
        id: applyTheme
        running: false
        property string themeId: "catppuccin"
        command: ["yahr-theme", "apply", themeId]
        onExited: themeList.running = true
    }

    Process {
        id: saveTheme
        running: false
        command: ["yahr-theme", "save",
            "--name", root.saveName,
            "--bg", root.seedBg,
            "--blue", root.seedBlue,
            "--purple", root.seedPurple,
            "--pink", root.seedPink,
            "--red", root.seedRed,
            "--orange", root.seedOrange,
            "--yellow", root.seedYellow,
            "--green", root.seedGreen,
            "--teal", root.seedTeal
        ]
        onExited: themeList.running = true
    }

    Process {
        id: deleteTheme
        running: false
        property string themeId: ""
        command: ["yahr-theme", "delete", themeId]
        onExited: themeList.running = true
    }

    function hexField(label, prop) {
        return label
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Yahr Settings"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 18
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            Text {
                text: "✕"
                color: ThemeManager.fgSecondary
                font.pixelSize: 16
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.requestClose() }
            }
        }

        Row {
            spacing: 6
            Repeater {
                model: [
                    { id: "quickshell", label: "Quickshell" },
                    { id: "bar", label: "Bar" },
                    { id: "dock", label: "Dock" },
                    { id: "theme", label: "Theme" },
                    { id: "wallpaper", label: "Wallpaper" },
                    { id: "hypr", label: "Hyprland" },
                    { id: "about", label: "About" }
                ]
                Rectangle {
                    required property var modelData
                    width: tabLabel.implicitWidth + 16
                    height: 28
                    radius: 6
                    color: root.tab === modelData.id ? ThemeManager.accentBlue : ThemeManager.surface1
                    Text {
                        id: tabLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.tab === modelData.id ? ThemeManager.bgBase : ThemeManager.fgPrimary
                        font.family: ThemeManager.uiFont
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = modelData.id
                    }
                }
            }
        }

        // Quickshell
        Column {
            visible: root.tab === "quickshell"
            Layout.fillWidth: true
            spacing: 10
            ToggleRow { label: "24-hour clock"; checked: Settings.clockFormat24hr; onToggled: { Settings.clockFormat24hr = checked; Settings.save() } }
            ToggleRow { label: "Show seconds"; checked: Settings.showSeconds; onToggled: { Settings.showSeconds = checked; Settings.save() } }
            ToggleRow { label: "Widget borders"; checked: Settings.showWidgetBorders; onToggled: { Settings.showWidgetBorders = checked; Settings.save() } }
            ToggleRow { label: "Day of week"; checked: Settings.showDayOfWeek; onToggled: { Settings.showDayOfWeek = checked; Settings.save() } }
            ToggleRow { label: "Long date"; checked: Settings.dateLong; onToggled: { Settings.dateLong = checked; Settings.save() } }
        }

        // Bar
        Column {
            visible: root.tab === "bar"
            Layout.fillWidth: true
            spacing: 10
            ToggleRow { label: "Bar on bottom"; checked: Settings.barPosition === "bottom"; onToggled: { Settings.barPosition = checked ? "bottom" : "top"; Settings.save() } }
            ToggleRow { label: "Large bar"; checked: Settings.barSize === "large"; onToggled: { Settings.barSize = checked ? "large" : "small"; Settings.save() } }
            ToggleRow { label: "Floating bar"; checked: Settings.barFloating; onToggled: { Settings.barFloating = checked; Settings.save() } }
            ToggleRow { label: "Numbered workspaces"; checked: Settings.workspaceStyle === "numbers"; onToggled: { Settings.workspaceStyle = checked ? "numbers" : "dots"; Settings.save() } }
            ToggleRow { label: "Opaque bar"; checked: Settings.barBackgroundStyle === "opaque"; onToggled: { Settings.barBackgroundStyle = checked ? "opaque" : "translucent"; Settings.save() } }
        }

        // Dock
        Column {
            visible: root.tab === "dock"
            Layout.fillWidth: true
            spacing: 10
            ToggleRow { label: "Enable dock"; checked: Settings.dockEnabled; onToggled: { Settings.dockEnabled = checked; Settings.save() } }
            ToggleRow { label: "Floating dock"; checked: Settings.dockFloating; onToggled: { Settings.dockFloating = checked; Settings.save() } }
            Text {
                text: "Pin apps from the launcher (right-click a dock icon to unpin)."
                color: ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                width: 700
            }
        }

        // Theme
        Flickable {
            visible: root.tab === "theme"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: themeCol.height
            clip: true

            Column {
                id: themeCol
                width: parent.width
                spacing: 10

                Grid {
                    columns: 4
                    spacing: 8
                    Repeater {
                        model: root.themes
                        Rectangle {
                            required property var modelData
                            width: 170
                            height: 56
                            radius: 8
                            color: modelData.active ? Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.3) : ThemeManager.surface0
                            border.width: 1
                            border.color: modelData.active ? ThemeManager.accentBlue : ThemeManager.border0
                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    text: modelData.name
                                    color: ThemeManager.fgPrimary
                                    font.family: ThemeManager.uiFont
                                    font.pixelSize: 13
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    visible: modelData.custom
                                    text: "custom"
                                    color: ThemeManager.fgTertiary
                                    font.pixelSize: 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton && modelData.custom) {
                                        deleteTheme.themeId = modelData.id
                                        deleteTheme.running = true
                                        return
                                    }
                                    applyTheme.themeId = modelData.id
                                    applyTheme.running = true
                                }
                            }
                        }
                    }
                }

                Text {
                    text: "Custom theme — background + 8 accents (hex). Right-click a custom card to delete."
                    color: ThemeManager.fgSecondary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                }

                Grid {
                    columns: 3
                    spacing: 8
                    ColorSeed { label: "Background"; text: root.seedBg; onEdited: root.seedBg = value }
                    ColorSeed { label: "Blue"; text: root.seedBlue; onEdited: root.seedBlue = value }
                    ColorSeed { label: "Purple"; text: root.seedPurple; onEdited: root.seedPurple = value }
                    ColorSeed { label: "Pink"; text: root.seedPink; onEdited: root.seedPink = value }
                    ColorSeed { label: "Red"; text: root.seedRed; onEdited: root.seedRed = value }
                    ColorSeed { label: "Orange"; text: root.seedOrange; onEdited: root.seedOrange = value }
                    ColorSeed { label: "Yellow"; text: root.seedYellow; onEdited: root.seedYellow = value }
                    ColorSeed { label: "Green"; text: root.seedGreen; onEdited: root.seedGreen = value }
                    ColorSeed { label: "Teal"; text: root.seedTeal; onEdited: root.seedTeal = value }
                }

                Row {
                    spacing: 8
                    TextField {
                        id: nameField
                        width: 200
                        text: root.saveName
                        onTextChanged: root.saveName = text
                        color: ThemeManager.fgPrimary
                        background: Rectangle { color: ThemeManager.surface0; radius: 6; border.color: ThemeManager.border0; border.width: 1 }
                    }
                    Rectangle {
                        width: 110
                        height: 32
                        radius: 6
                        color: ThemeManager.accentBlue
                        Text { anchors.centerIn: parent; text: "Save & Apply"; color: ThemeManager.bgBase; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; onClicked: saveTheme.running = true }
                    }
                }
            }
        }

        // Wallpaper shortcut
        Column {
            visible: root.tab === "wallpaper"
            spacing: 8
            Text {
                text: "Open the wallpaper picker with Super+Shift+W, or:"
                color: ThemeManager.fgSecondary
                font.family: ThemeManager.uiFont
            }
            Rectangle {
                width: 160
                height: 32
                radius: 6
                color: ThemeManager.accentBlue
                Text { anchors.centerIn: parent; text: "Browse wallpapers"; color: ThemeManager.bgBase }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.requestClose()
                        Quickshell.execDetached(["qs", "ipc", "call", "yahr", "toggleWallpaper"])
                    }
                }
            }
        }

        // Hyprland
        Column {
            visible: root.tab === "hypr"
            spacing: 10
            Text {
                text: `Window rounding: ${Settings.hyprRounding}`
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
            }
            Row {
                spacing: 8
                Repeater {
                    model: [0, 4, 8, 12, 16, 20]
                    Rectangle {
                        required property int modelData
                        width: 40
                        height: 28
                        radius: 6
                        color: Settings.hyprRounding === modelData ? ThemeManager.accentBlue : ThemeManager.surface1
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Settings.hyprRounding === modelData ? ThemeManager.bgBase : ThemeManager.fgPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Settings.hyprRounding = modelData
                                Settings.save()
                                Quickshell.execDetached(["hyprctl", "keyword", "decoration:rounding", `${modelData}`])
                            }
                        }
                    }
                }
            }
        }

        Column {
            visible: root.tab === "about"
            spacing: 8
            Text {
                text: "Yahr Shell"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Text {
                text: "Unified theming for Hyprland + Quickshell.\nhttps://github.com/bgibson72/yahr-shell"
                color: ThemeManager.fgSecondary
                font.family: ThemeManager.uiFont
                font.pixelSize: 13
            }
        }
    }

    component ToggleRow: Row {
        property string label
        property bool checked
        signal toggled()
        spacing: 10
        width: 400
        Text {
            text: label
            color: ThemeManager.fgPrimary
            font.family: ThemeManager.uiFont
            font.pixelSize: 13
            width: 280
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            width: 42
            height: 22
            radius: 11
            color: checked ? ThemeManager.accentBlue : ThemeManager.surface2
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: 18
                height: 18
                radius: 9
                x: checked ? 22 : 2
                y: 2
                color: ThemeManager.fgPrimary
                Behavior on x { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    parent.parent.checked = !parent.parent.checked
                    parent.parent.toggled()
                }
            }
        }
    }

    component ColorSeed: Row {
        property string label
        property string text
        signal edited(string value)
        spacing: 6
        width: 230
        Text {
            text: label
            width: 80
            color: ThemeManager.fgSecondary
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            width: 18
            height: 18
            radius: 4
            color: parent.text
            border.color: ThemeManager.border0
            anchors.verticalCenter: parent.verticalCenter
        }
        TextField {
            width: 90
            text: parent.text
            color: ThemeManager.fgPrimary
            font.pixelSize: 12
            background: Rectangle { color: ThemeManager.surface0; radius: 4 }
            onEditingFinished: parent.edited(text)
        }
    }
}

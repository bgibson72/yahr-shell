import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"
import "../.."

Panel {
    id: root
    width: 880
    height: 640
    floatCenter: true
    slideOffsetY: 0
    entranceScale: 0.92

    signal requestClose()
    focus: true

    property var binds: []
    property string searchText: ""
    property bool dirty: false
    property string statusText: ""
    property bool listening: false
    property string listenId: ""
    property bool listenSpecial: false
    property bool wantSuper: true
    property bool wantCtrl: false
    property bool wantAlt: false
    property bool wantShift: false
    property string specialDraft: ""
    property bool conflictOpen: false
    property string pendingId: ""
    property string pendingCombo: ""
    property string conflictId: ""
    property string conflictLabel: ""

    readonly property var groupOrder: [
        "Applications", "Shell", "Windows", "Workspaces",
        "Mouse", "Media", "Display", "System", "Other"
    ]

    readonly property var conflictCombos: {
        const seen = {}
        const clash = {}
        for (let i = 0; i < binds.length; i++) {
            const c = root.normalize(binds[i].combo)
            if (!c)
                continue
            if (seen[c])
                clash[c] = true
            else
                seen[c] = binds[i].id
        }
        return clash
    }

    readonly property bool hasConflicts: Object.keys(conflictCombos).length > 0

    readonly property var visibleGroups: {
        const q = searchText.trim().toLowerCase()
        const buckets = {}
        for (let i = 0; i < binds.length; i++) {
            const b = binds[i]
            const hay = `${b.label || ""} ${b.pretty || ""} ${b.combo || ""} ${b.group || ""}`.toLowerCase()
            if (q && hay.indexOf(q) < 0)
                continue
            const g = b.group || "Other"
            if (!buckets[g])
                buckets[g] = []
            buckets[g].push(b)
        }
        const out = []
        const seen = {}
        for (let i = 0; i < groupOrder.length; i++) {
            const g = groupOrder[i]
            if (buckets[g] && buckets[g].length) {
                out.push({ title: g, rows: buckets[g] })
                seen[g] = true
            }
        }
        const extras = Object.keys(buckets)
        extras.sort()
        for (let i = 0; i < extras.length; i++) {
            if (!seen[extras[i]])
                out.push({ title: extras[i], rows: buckets[extras[i]] })
        }
        return out
    }

    onIsVisibleChanged: {
        if (isVisible) {
            root.reload()
            root.forceActiveFocus()
        } else {
            root.cancelListen()
        }
    }

    Keys.onPressed: event => {
        if (conflictOpen) {
            event.accepted = true
            return
        }
        if (!listening)
            return
        if (event.isAutoRepeat) {
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Escape) {
            root.cancelListen()
            event.accepted = true
            return
        }
        if (listenSpecial) {
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
            root.commitCombo(listenId, "")
            event.accepted = true
            return
        }
        if (root.isModifier(event.key)) {
            event.accepted = true
            return
        }
        const key = root.qtKey(event)
        if (!key) {
            event.accepted = true
            return
        }
        const mods = []
        if (wantSuper || event.modifiers & Qt.MetaModifier)
            mods.push("SUPER")
        if (wantCtrl || event.modifiers & Qt.ControlModifier)
            mods.push("CTRL")
        if (wantAlt || event.modifiers & Qt.AltModifier)
            mods.push("ALT")
        if (wantShift || event.modifiers & Qt.ShiftModifier)
            mods.push("SHIFT")
        root.tryAssign(listenId, mods.concat([key]).join(" + "))
        event.accepted = true
    }

    function normalize(raw) {
        const s = (raw || "").trim()
        if (!s)
            return ""
        if (s.toLowerCase().indexOf("switch:") === 0)
            return s
        const order = ["SUPER", "CTRL", "ALT", "SHIFT"]
        const parts = s.split("+").map(p => p.trim()).filter(p => p)
        const mods = []
        let key = ""
        for (let i = 0; i < parts.length; i++) {
            let u = parts[i].toUpperCase()
            u = u.replace("CONTROL", "CTRL").replace("MOD4", "SUPER").replace("META", "SUPER")
            if (order.indexOf(u) >= 0) {
                if (mods.indexOf(u) < 0)
                    mods.push(u)
            } else {
                key = parts[i].trim()
            }
        }
        const bits = order.filter(m => mods.indexOf(m) >= 0)
        if (key)
            bits.push(key)
        return bits.join(" + ")
    }

    function pretty(combo) {
        if (!combo)
            return "Not set"
        return combo.split(" + ").map(p => {
            if (p === "SUPER") return "Super"
            if (p === "CTRL") return "Ctrl"
            if (p === "ALT") return "Alt"
            if (p === "SHIFT") return "Shift"
            return p
        }).join(" + ")
    }

    function isModifier(key) {
        return key === Qt.Key_Control || key === Qt.Key_Shift || key === Qt.Key_Alt
            || key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R
            || key === Qt.Key_AltGr || key === Qt.Key_CapsLock
    }

    function qtKey(event) {
        const k = event.key
        const map = {}
        map[Qt.Key_Return] = "Return"
        map[Qt.Key_Enter] = "Return"
        map[Qt.Key_Space] = "space"
        map[Qt.Key_Tab] = "Tab"
        map[Qt.Key_Left] = "left"
        map[Qt.Key_Right] = "right"
        map[Qt.Key_Up] = "up"
        map[Qt.Key_Down] = "down"
        map[Qt.Key_Period] = "period"
        map[Qt.Key_Comma] = "comma"
        map[Qt.Key_Minus] = "minus"
        map[Qt.Key_Equal] = "equal"
        map[Qt.Key_Slash] = "slash"
        map[Qt.Key_Backslash] = "backslash"
        map[Qt.Key_Print] = "Print"
        map[Qt.Key_Insert] = "Insert"
        map[Qt.Key_Home] = "Home"
        map[Qt.Key_End] = "End"
        map[Qt.Key_PageUp] = "Prior"
        map[Qt.Key_PageDown] = "Next"
        map[Qt.Key_VolumeUp] = "XF86AudioRaiseVolume"
        map[Qt.Key_VolumeDown] = "XF86AudioLowerVolume"
        map[Qt.Key_VolumeMute] = "XF86AudioMute"
        map[Qt.Key_MediaNext] = "XF86AudioNext"
        map[Qt.Key_MediaPrevious] = "XF86AudioPrev"
        map[Qt.Key_MediaPlay] = "XF86AudioPlay"
        map[Qt.Key_MediaPause] = "XF86AudioPause"
        map[Qt.Key_MediaTogglePlayPause] = "XF86AudioPlay"
        if (map[k])
            return map[k]
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12)
            return "F" + (k - Qt.Key_F1 + 1)
        if (k >= Qt.Key_0 && k <= Qt.Key_9)
            return String.fromCharCode(k)
        const t = (event.text || "").trim()
        if (t.length === 1)
            return t.toUpperCase()
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(k)
        return ""
    }

    function findConflict(id, combo) {
        const n = root.normalize(combo)
        if (!n)
            return null
        for (let i = 0; i < binds.length; i++) {
            if (binds[i].id !== id && root.normalize(binds[i].combo) === n)
                return binds[i]
        }
        return null
    }

    function patchBind(id, mutator) {
        const next = []
        for (let i = 0; i < binds.length; i++) {
            const row = Object.assign({}, binds[i])
            if (row.options)
                row.options = Object.assign({}, row.options)
            if (row.id === id)
                mutator(row)
            row.pretty = root.pretty(row.combo)
            next.push(row)
        }
        binds = next
        dirty = true
        statusText = ""
    }

    function commitCombo(id, combo) {
        const n = root.normalize(combo)
        root.patchBind(id, row => { row.combo = n })
        root.cancelListen()
    }

    function tryAssign(id, combo) {
        const n = root.normalize(combo)
        const other = root.findConflict(id, n)
        if (other) {
            pendingId = id
            pendingCombo = n
            conflictId = other.id
            conflictLabel = other.label
            conflictOpen = true
            return
        }
        root.commitCombo(id, n)
    }

    function overwriteConflict() {
        root.patchBind(conflictId, row => { row.combo = "" })
        root.patchBind(pendingId, row => { row.combo = pendingCombo })
        conflictOpen = false
        root.cancelListen()
    }

    function startListen(bind) {
        listenId = bind.id
        listenSpecial = bind.capture === "special"
        specialDraft = bind.combo || ""
        const parts = root.normalize(bind.combo).split(" + ")
        wantSuper = parts.indexOf("SUPER") >= 0 || (!bind.combo && true)
        wantCtrl = parts.indexOf("CTRL") >= 0
        wantAlt = parts.indexOf("ALT") >= 0
        wantShift = parts.indexOf("SHIFT") >= 0
        if (!bind.combo)
            wantSuper = true
        listening = true
        conflictOpen = false
        root.forceActiveFocus()
    }

    function cancelListen() {
        listening = false
        listenId = ""
        listenSpecial = false
        conflictOpen = false
    }

    function reload() {
        dumpProc.running = false
        dumpProc.running = true
    }

    function save() {
        if (hasConflicts)
            return
        const payload = JSON.stringify({ version: 1, binds: binds }, null, 2) + "\n"
        draftFile.setText(payload)
        statusText = "Saving…"
        applyTimer.restart()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "Yahr Keybinds"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 18
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            IconButton {
                compact: true
                glyph: "\uf00d"
                pixelSize: 14
                onClicked: root.requestClose()
            }
        }

        Text {
            visible: root.hasConflicts
            Layout.fillWidth: true
            text: "Two or more actions share the same shortcut. Fix the highlighted rows before saving."
            color: ThemeManager.accentRed
            font.family: ThemeManager.uiFont
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        InputField {
            id: searchField
            Layout.fillWidth: true
            height: 34
            placeholderText: "Search actions or shortcuts"
            font.pixelSize: 13
            onTextChanged: root.searchText = text
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: listCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            Column {
                id: listCol
                width: parent.width
                spacing: 16

                Repeater {
                    model: root.visibleGroups
                    Column {
                        required property var modelData
                        width: listCol.width
                        spacing: 8

                        Text {
                            text: modelData.title
                            color: ThemeManager.fgTertiary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1.2
                            leftPadding: 4
                        }

                        Repeater {
                            model: modelData.rows
                            Rectangle {
                                required property var modelData
                                width: listCol.width
                                height: 48
                                radius: 12
                                color: ThemeManager.cardColor
                                border.width: root.conflictCombos[root.normalize(modelData.combo)] ? 1 : 0
                                border.color: ThemeManager.accentRed

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        elide: Text.ElideRight
                                        color: ThemeManager.fgPrimary
                                        font.family: ThemeManager.uiFont
                                        font.pixelSize: 13
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: 30
                                        Layout.preferredWidth: Math.max(108, chipLabel.implicitWidth + 20)
                                        radius: 8
                                        color: root.listening && root.listenId === modelData.id
                                            ? ThemeManager.accentBlue
                                            : ThemeManager.overlay(0.08)
                                        Text {
                                            id: chipLabel
                                            anchors.centerIn: parent
                                            text: modelData.combo ? root.pretty(modelData.combo) : "Not set"
                                            color: root.listening && root.listenId === modelData.id
                                                ? ThemeManager.bgBase
                                                : (modelData.combo ? ThemeManager.fgPrimary : ThemeManager.fgTertiary)
                                            font.family: ThemeManager.uiFont
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.startListen(modelData)
                                        }
                                    }

                                    IconButton {
                                        compact: true
                                        glyph: "\uf057"
                                        pixelSize: 13
                                        glyphColor: ThemeManager.fgTertiary
                                        visible: !!modelData.combo
                                        onClicked: root.commitCombo(modelData.id, "")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: root.statusText || (root.dirty ? "Unsaved changes" : "Click a shortcut to reassign it")
                color: root.dirty ? ThemeManager.accentYellow : ThemeManager.fgTertiary
                font.family: ThemeManager.uiFont
                font.pixelSize: 12
            }
            Rectangle {
                Layout.preferredHeight: 36
                Layout.preferredWidth: 96
                radius: 10
                opacity: root.hasConflicts ? 0.45 : 1
                color: ThemeManager.accentBlue
                scale: saveMouse.pressed ? ThemeManager.bouncePressScale : (saveMouse.containsMouse ? 1.04 : 1)
                Behavior on scale {
                    SpringAnimation {
                        spring: ThemeManager.bounceSpring
                        damping: ThemeManager.bounceDamping
                        mass: ThemeManager.bounceMass
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    color: ThemeManager.bgBase
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.hasConflicts ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                    enabled: !root.hasConflicts
                    onClicked: root.save()
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.listening
        color: ThemeManager.overlay(0.45)
        radius: root.chromeRadius
        MouseArea {
            anchors.fill: parent
            onClicked: root.cancelListen()
        }

        Rectangle {
            width: 420
            height: listenCol.implicitHeight + 36
            radius: 16
            color: ThemeManager.panelColor
            border.width: ThemeManager.showWidgetBorders ? ThemeManager.widgetBorderWidth : 0
            border.color: ThemeManager.chromeBorderColor
            anchors.centerIn: parent

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: listenCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                Text {
                    text: root.listenSpecial ? "Edit special shortcut" : "Press a key"
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    visible: !root.listenSpecial
                    text: "Modifiers are toggles so Super shortcuts do not fire while you assign them. Escape cancels. Backspace clears."
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.listenSpecial
                    text: "Mouse and lid binds use Hyprland’s own names, for example Super + mouse:272."
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                Row {
                    spacing: 8
                    visible: !root.listenSpecial
                    Repeater {
                        model: [
                            { id: "SUPER", label: "Super" },
                            { id: "SHIFT", label: "Shift" },
                            { id: "CTRL", label: "Ctrl" },
                            { id: "ALT", label: "Alt" }
                        ]
                        Rectangle {
                            required property var modelData
                            width: 70
                            height: 30
                            radius: 8
                            readonly property bool on: modelData.id === "SUPER" ? root.wantSuper
                                : (modelData.id === "SHIFT" ? root.wantShift
                                    : (modelData.id === "CTRL" ? root.wantCtrl : root.wantAlt))
                            color: on ? ThemeManager.accentBlue : ThemeManager.overlay(0.08)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.on ? ThemeManager.bgBase : ThemeManager.fgPrimary
                                font.family: ThemeManager.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.id === "SUPER")
                                        root.wantSuper = !root.wantSuper
                                    else if (modelData.id === "SHIFT")
                                        root.wantShift = !root.wantShift
                                    else if (modelData.id === "CTRL")
                                        root.wantCtrl = !root.wantCtrl
                                    else
                                        root.wantAlt = !root.wantAlt
                                }
                            }
                        }
                    }
                }

                InputField {
                    visible: root.listenSpecial
                    Layout.fillWidth: true
                    height: 34
                    text: root.specialDraft
                    font.pixelSize: 13
                    onTextChanged: root.specialDraft = text
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 84
                        radius: 8
                        color: ThemeManager.overlay(0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelListen()
                        }
                    }
                    Rectangle {
                        visible: root.listenSpecial
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 84
                        radius: 8
                        color: ThemeManager.accentBlue
                        Text {
                            anchors.centerIn: parent
                            text: "Set"
                            color: ThemeManager.bgBase
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tryAssign(root.listenId, root.specialDraft)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.conflictOpen
        color: ThemeManager.overlay(0.55)
        radius: root.chromeRadius
        z: 20
        MouseArea { anchors.fill: parent }

        Rectangle {
            width: 440
            height: conflictCol.implicitHeight + 36
            radius: 16
            color: ThemeManager.panelColor
            border.width: ThemeManager.showWidgetBorders ? ThemeManager.widgetBorderWidth : 0
            border.color: ThemeManager.chromeBorderColor
            anchors.centerIn: parent

            ColumnLayout {
                id: conflictCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                Text {
                    text: "Shortcut already in use"
                    color: ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: `${root.pretty(root.pendingCombo)} is assigned to “${root.conflictLabel}”. Overwrite that bind, or pick a different shortcut.`
                    color: ThemeManager.fgSecondary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: 140
                        radius: 8
                        color: ThemeManager.overlay(0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "Choose another"
                            color: ThemeManager.fgPrimary
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.conflictOpen = false
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: 110
                        radius: 8
                        color: ThemeManager.accentRed
                        Text {
                            anchors.centerIn: parent
                            text: "Overwrite"
                            color: ThemeManager.bgBase
                            font.family: ThemeManager.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.overwriteConflict()
                        }
                    }
                }
            }
        }
    }

    FileView {
        id: draftFile
        path: `${Quickshell.env("HOME")}/.config/yahr/keybinds.json`
    }

    Process {
        id: dumpProc
        running: false
        command: ["python3", `${Quickshell.shellDir}/scripts/keybinds-store.py`, "dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    const rows = data.binds || []
                    for (let i = 0; i < rows.length; i++)
                        rows[i].pretty = root.pretty(rows[i].combo)
                    root.binds = rows
                    root.dirty = false
                    root.statusText = ""
                } catch (e) {
                    root.statusText = "Could not load keybinds"
                }
            }
        }
    }

    Process {
        id: applyProc
        running: false
        command: [
            "python3",
            `${Quickshell.shellDir}/scripts/keybinds-store.py`,
            "apply",
            "--file",
            `${Quickshell.env("HOME")}/.config/yahr/keybinds.json`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    if (data.ok) {
                        root.dirty = false
                        root.statusText = data.reloaded ? "Saved and reloaded Hyprland" : "Saved"
                    } else {
                        root.statusText = "Save failed"
                    }
                } catch (e) {
                    root.statusText = "Save failed"
                }
            }
        }
    }

    Timer {
        id: applyTimer
        interval: 80
        repeat: false
        onTriggered: {
            applyProc.running = false
            applyProc.running = true
        }
    }
}

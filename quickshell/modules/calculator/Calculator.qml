import QtQuick
import QtQuick.Layouts
import "../../components"
import "../.."

Panel {
    id: root
    width: 332
    height: 508
    floatCenter: true
    slideOffsetY: 0
    entranceScale: 0.92

    signal requestClose()
    focus: true

    property string display: "0"
    property string tape: ""
    property real acc: 0
    property string op: ""
    property bool fresh: true
    property bool errored: false

    onIsVisibleChanged: {
        if (isVisible) {
            root.forceActiveFocus()
        }
    }

    Keys.onPressed: event => {
        const k = event.text
        if (event.key === Qt.Key_Backspace) {
            root.backspace()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || k === "=") {
            root.equals()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Delete || k === "c" || k === "C") {
            root.clearAll()
            event.accepted = true
            return
        }
        if (k >= "0" && k <= "9") {
            root.digit(k)
            event.accepted = true
            return
        }
        if (k === "." || k === ",") {
            root.digit(".")
            event.accepted = true
            return
        }
        if (k === "+" || k === "-") {
            root.setOp(k)
            event.accepted = true
            return
        }
        if (k === "*" || k === "x" || k === "X") {
            root.setOp("×")
            event.accepted = true
            return
        }
        if (k === "/") {
            root.setOp("÷")
            event.accepted = true
            return
        }
        if (k === "%") {
            root.percent()
            event.accepted = true
        }
    }

    function parseDisplay() {
        const n = Number(display)
        return isFinite(n) ? n : 0
    }

    function formatNum(n) {
        if (!isFinite(n))
            return "Error"
        if (Math.abs(n) >= 1e12 || (n !== 0 && Math.abs(n) < 1e-9))
            return n.toExponential(6).replace(/\.?0+e/, "e")
        let s = n.toPrecision(12)
        if (s.indexOf("e") === -1) {
            s = String(Number(s))
            if (s.indexOf(".") >= 0)
                s = s.replace(/\.?0+$/, "")
        }
        return s
    }

    function symbol(o) {
        if (o === "*")
            return "×"
        if (o === "/")
            return "÷"
        return o
    }

    function digit(d) {
        if (errored)
            clearAll()
        if (d === ".") {
            if (fresh) {
                display = "0."
                fresh = false
                return
            }
            if (display.indexOf(".") !== -1)
                return
            display += "."
            return
        }
        if (fresh || display === "0") {
            display = d
            fresh = false
            return
        }
        if (display.replace("-", "").replace(".", "").length >= 14)
            return
        display += d
    }

    function backspace() {
        if (errored || fresh) {
            clearAll()
            return
        }
        if (display.length <= 1 || (display.length === 2 && display[0] === "-")) {
            display = "0"
            fresh = true
            return
        }
        display = display.slice(0, -1)
    }

    function negate() {
        if (errored)
            return
        if (display === "0" || display === "0.")
            return
        if (display[0] === "-")
            display = display.slice(1)
        else
            display = "-" + display
    }

    function percent() {
        if (errored)
            return
        display = formatNum(parseDisplay() / 100)
        fresh = true
    }

    function clearEntry() {
        display = "0"
        fresh = true
    }

    function clearAll() {
        display = "0"
        tape = ""
        acc = 0
        op = ""
        fresh = true
        errored = false
    }

    readonly property bool clearingEntry: !fresh && display !== "0" && !errored

    function apply(a, operator, b) {
        if (operator === "+")
            return a + b
        if (operator === "-")
            return a - b
        if (operator === "×" || operator === "*")
            return a * b
        if (operator === "÷" || operator === "/") {
            if (b === 0)
                return NaN
            return a / b
        }
        return b
    }

    function setOp(next) {
        if (errored)
            clearAll()
        const n = parseDisplay()
        if (op !== "" && !fresh) {
            const r = apply(acc, op, n)
            if (!isFinite(r)) {
                display = "Error"
                errored = true
                tape = ""
                op = ""
                fresh = true
                return
            }
            acc = r
            display = formatNum(r)
        } else {
            acc = n
        }
        op = next
        tape = formatNum(acc) + " " + symbol(next)
        fresh = true
    }

    function equals() {
        if (errored || op === "")
            return
        const n = parseDisplay()
        const r = apply(acc, op, n)
        tape = formatNum(acc) + " " + symbol(op) + " " + formatNum(n)
        if (!isFinite(r)) {
            display = "Error"
            errored = true
            op = ""
            fresh = true
            return
        }
        acc = r
        display = formatNum(r)
        op = ""
        fresh = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Yahr Calculator"
                color: ThemeManager.fgPrimary
                font.family: ThemeManager.uiFont
                font.pixelSize: 16
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            radius: 14
            color: ThemeManager.cardColor

            Column {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 14
                anchors.bottomMargin: 12
                spacing: 4

                Text {
                    width: parent.width
                    text: root.tape
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                    color: ThemeManager.fgTertiary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: 13
                    height: 18
                }
                Text {
                    width: parent.width
                    text: root.display
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                    color: root.errored ? ThemeManager.accentRed : ThemeManager.fgPrimary
                    font.family: ThemeManager.uiFont
                    font.pixelSize: root.display.length > 10 ? 28 : 34
                    font.weight: Font.DemiBold
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: [
                    { label: "AC", kind: "fn", action: "clear" },
                    { label: "⌫", kind: "fn", action: "back" },
                    { label: "%", kind: "fn", action: "pct" },
                    { label: "÷", kind: "op", action: "÷" },
                    { label: "7", kind: "num", action: "7" },
                    { label: "8", kind: "num", action: "8" },
                    { label: "9", kind: "num", action: "9" },
                    { label: "×", kind: "op", action: "×" },
                    { label: "4", kind: "num", action: "4" },
                    { label: "5", kind: "num", action: "5" },
                    { label: "6", kind: "num", action: "6" },
                    { label: "−", kind: "op", action: "-" },
                    { label: "1", kind: "num", action: "1" },
                    { label: "2", kind: "num", action: "2" },
                    { label: "3", kind: "num", action: "3" },
                    { label: "+", kind: "op", action: "+" },
                    { label: "±", kind: "fn", action: "neg" },
                    { label: "0", kind: "num", action: "0" },
                    { label: ".", kind: "num", action: "." },
                    { label: "=", kind: "eq", action: "eq" }
                ]

                Rectangle {
                    id: key
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    readonly property bool activeOp: modelData.kind === "op" && root.op === modelData.action && root.fresh
                    color: {
                        if (modelData.kind === "eq")
                            return ThemeManager.accentBlue
                        if (key.activeOp)
                            return ThemeManager.accentBlue
                        if (modelData.kind === "op")
                            return Qt.rgba(ThemeManager.accentBlue.r, ThemeManager.accentBlue.g, ThemeManager.accentBlue.b, 0.16)
                        if (modelData.kind === "fn")
                            return ThemeManager.overlay(0.08)
                        return ThemeManager.cardColor
                    }
                    scale: keyMouse.pressed ? ThemeManager.bouncePressScale : (keyMouse.containsMouse ? 1.04 : 1.0)
                    Behavior on scale {
                        SpringAnimation {
                            spring: ThemeManager.bounceSpring
                            damping: ThemeManager.bounceDamping
                            mass: ThemeManager.bounceMass
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        text: key.modelData.action === "clear" && root.clearingEntry ? "C" : key.modelData.label
                        font.family: ThemeManager.uiFont
                        font.pixelSize: key.modelData.kind === "eq" || key.modelData.label === "⌫" ? 22 : 18
                        font.weight: Font.DemiBold
                        color: {
                            if (key.modelData.kind === "eq" || key.activeOp)
                                return ThemeManager.bgBase
                            if (key.modelData.kind === "op")
                                return ThemeManager.accentBlue
                            if (key.modelData.kind === "fn")
                                return ThemeManager.fgSecondary
                            return ThemeManager.fgPrimary
                        }
                    }

                    MouseArea {
                        id: keyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const a = key.modelData.action
                            if (a === "clear") {
                                if (root.clearingEntry)
                                    root.clearEntry()
                                else
                                    root.clearAll()
                            }
                            else if (a === "back")
                                root.backspace()
                            else if (a === "pct")
                                root.percent()
                            else if (a === "neg")
                                root.negate()
                            else if (a === "eq")
                                root.equals()
                            else if (key.modelData.kind === "op")
                                root.setOp(a)
                            else
                                root.digit(a)
                            root.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }
}

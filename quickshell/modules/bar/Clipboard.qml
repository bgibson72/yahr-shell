import QtQuick
import "../../components"
import "../.."

IconButton {
    id: clip
    glyph: "󰅍"
    glyphColor: ThemeManager.accentYellow

    signal toggleClipboard()
    onClicked: clip.toggleClipboard()
}

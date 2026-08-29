import QtQuick
import Quickshell
import "../../components"
import "../.."

IconButton {
    id: net
    compact: true
    glyph: {
        if (NetworkState.connectionType === "wifi")
            return "󰤨"
        if (NetworkState.connectionType === "ethernet")
            return "󰈀"
        return "󰌙"
    }
    glyphColor: {
        if (NetworkState.connectionType === "wifi")
            return ThemeManager.accentGreen
        if (NetworkState.connectionType === "ethernet")
            return ThemeManager.accentBlue
        return ThemeManager.accentRed
    }
    signal togglePanel()

    onClicked: net.togglePanel()
}

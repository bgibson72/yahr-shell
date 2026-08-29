import QtQuick
import QtQuick.Controls
import ".."

TextField {
    color: ThemeManager.fgPrimary
    placeholderTextColor: ThemeManager.placeholderColor
    font.family: ThemeManager.uiFont
    selectedTextColor: ThemeManager.bgBase
    selectionColor: ThemeManager.accentBlue
    palette.placeholderText: ThemeManager.placeholderColor
    background: Rectangle {
        color: ThemeManager.cardColor
        radius: 8
    }
}

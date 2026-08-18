import QtQuick
import ".."

Rectangle {
    id: panel
    color: ThemeManager.panelColor
    radius: ThemeManager.hyprRounding
    border.width: ThemeManager.showWidgetBorders ? ThemeManager.widgetBorderWidth : 0
    border.color: ThemeManager.accentBorder
    antialiasing: true
}

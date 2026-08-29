import QtQuick
import ".."

// Rounded "card" background for clustering a handful of bar icons together.
// The fill is a sibling behind the icons so bar transparency only fades
// the chrome, never the glyphs/buttons themselves.
Item {
    id: pill
    default property alias content: row.data
    property real horizontalPadding: 8
    property bool circular: false
    property int spacing: 4

    // Nested icon-group cards belong to the solid bar. Islands already
    // wrap the whole right cluster in its own pill, so extra cards just
    // stack chrome on chrome.
    readonly property bool showBackground: Settings.barStyle !== "islands"
    readonly property real effectivePadding: showBackground ? horizontalPadding : 0

    // Sized off the glyph's own pixel size rather than the icon buttons'
    // fixed (and much taller) hit-box, so the card gets the same kind of
    // breathing room against the bar's edges as the clock's pill. The icon
    // buttons themselves stay full-size for hover/click and simply center
    // through the card without being clipped.
    readonly property real cardHeight: ThemeManager.fontSizeIcon + 14

    implicitHeight: cardHeight
    implicitWidth: (circular && showBackground) ? cardHeight : row.implicitWidth + effectivePadding * 2
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: ThemeManager.barPillColor
        visible: pill.showBackground
    }

    Row {
        id: row
        z: 1
        anchors.centerIn: parent
        spacing: pill.spacing
    }
}

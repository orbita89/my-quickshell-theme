import QtQuick
import QtQuick.Controls

Flickable {
    id: root

    clip: true
    maximumFlickVelocity: 3500
    // See StyledListView: a touchpad scroll phase is a drag to Flickable, and
    // DragOverBounds turns the end of the page into an overshoot-and-snap jump.
    boundsBehavior: Flickable.StopAtBounds

    property bool smoothWheelScrolling: true
    // Compatibility for existing callers; the shared policy is now enabled by default.
    property alias fasterTouchpadScroll: root.smoothWheelScrolling
    property bool showVerticalScrollBar: true

    ScrollBar.vertical: StyledScrollBar {
        policy: root.showVerticalScrollBar ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    }

    WheelScrollController {
        flickable: root
        enabled: root.smoothWheelScrolling && root.interactive
        orientation: root.flickableDirection === Flickable.HorizontalFlick || (root.flickableDirection
                                                                               !== Flickable.VerticalFlick
                                                                               && root.contentWidth
                                                                               > root.width
                                                                               && root.contentHeight
                                                                               <= root.height)
                     ? Qt.Horizontal : Qt.Vertical
    }
}

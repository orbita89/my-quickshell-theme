import QtQuick
import QtQuick.Controls

ListView {
    id: root

    spacing: 0
    clip: true
    maximumFlickVelocity: 3500
    // Touchpad wheel events arrive with a scroll phase, so Flickable treats them
    // as a drag. DragOverBounds would let that drag pull the content past the
    // last row and then rubber-band it back — the list appears to jump instead
    // of stopping. WheelScrollController deliberately stops accepting events at
    // the edge (to leave scrolling to an enclosing view), so those leftover
    // events reach Flickable directly and this is the only thing guarding them.
    boundsBehavior: Flickable.StopAtBounds

    property real removeOvershoot: 20
    property bool popin: true
    property bool animateAppearance: true
    property bool animateMovement: false
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
        orientation: root.orientation
    }

    Component {
        id: elementMoveAnimation

        ElementMoveAnimation {}
    }

    add: Transition {
        animations: root.animateAppearance ? [elementMoveAnimation.createObject(this, {
                                                                                    properties: root.popin
                                                                                                ? "opacity,scale" :
                                                                                                  "opacity",
                                                                                    from: 0,
                                                                                    to: 1
                                                                                }),] : []
    }

    addDisplaced: Transition {
        animations: root.animateAppearance ? [elementMoveAnimation.createObject(this, {
                                                                                    property: "y"
                                                                                }), elementMoveAnimation.createObject(
                                                  this, {
                                                      properties: root.popin ? "opacity,scale" : "opacity",
                                                      to: 1
                                                  }),] : []
    }

    displaced: Transition {
        animations: root.animateMovement ? [elementMoveAnimation.createObject(this, {
                                                                                  property: "y"
                                                                              }), elementMoveAnimation.createObject(
                                                this, {
                                                    properties: "opacity,scale",
                                                    to: 1
                                                }),] : []
    }

    move: Transition {
        animations: root.animateMovement ? [elementMoveAnimation.createObject(this, {
                                                                                  property: "y"
                                                                              }), elementMoveAnimation.createObject(
                                                this, {
                                                    properties: "opacity,scale",
                                                    to: 1
                                                }),] : []
    }

    moveDisplaced: Transition {
        animations: root.animateMovement ? [elementMoveAnimation.createObject(this, {
                                                                                  property: "y"
                                                                              }), elementMoveAnimation.createObject(
                                                this, {
                                                    properties: "opacity,scale",
                                                    to: 1
                                                }),] : []
    }

    remove: Transition {
        animations: root.animateAppearance ? [elementMoveAnimation.createObject(this, {
                                                                                    property: "x",
                                                                                    to: root.width
                                                                                        + root.removeOvershoot
                                                                                }), elementMoveAnimation.createObject(
                                                  this, {
                                                      property: "opacity",
                                                      to: 0
                                                  }),] : []
    }

    removeDisplaced: Transition {
        animations: root.animateAppearance ? [elementMoveAnimation.createObject(this, {
                                                                                    property: "y"
                                                                                }), elementMoveAnimation.createObject(
                                                  this, {
                                                      properties: "opacity,scale",
                                                      to: 1
                                                  }),] : []
    }
}

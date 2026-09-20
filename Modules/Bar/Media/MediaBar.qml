pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

TopBarPill {
    id: root

    property bool vertical: false
    property real maximumTitleWidth: 180
    readonly property var player: MediaManager.active
    readonly property string title: player ? player.trackTitle || player.identity || qsTr("No media") : qsTr(
                                                 "No media")
    readonly property bool spectrumActive: visible && player !== null && player.isPlaying
    readonly property string spectrumToken: "bar-media-" + String(root)

    implicitWidth: vertical ? Sizes.barVisualThickness : layout.implicitWidth + 2
                              * Sizes.barPillHorizontalPadding
    implicitHeight: vertical ? layout.implicitHeight + 16 : Sizes.barPillThickness

    onSpectrumActiveChanged: updateSpectrum()
    Component.onCompleted: updateSpectrum()
    Component.onDestruction: AudioSpectrum.release(spectrumToken)

    function updateSpectrum() {
        if (spectrumActive)
            AudioSpectrum.acquire(spectrumToken);
        else
            AudioSpectrum.release(spectrumToken);
    }

    GridLayout {
        id: layout

        anchors.centerIn: parent
        columns: root.vertical ? 1 : 5
        rowSpacing: 6
        columnSpacing: 4

        Row {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            spacing: 2

            Repeater {
                model: 6

                Rectangle {
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 2 + 20 * (root.spectrumActive && AudioSpectrum.available ? Math.max(0, Math.min(1,
                                                                                                            Number(AudioSpectrum.values[Math.floor(
                                                                                                                                            index * AudioSpectrum.bars
                                                                                                                                            / 6)]) || 0)) :
                                                                                       0)
                    radius: 1.5
                    color: Appearance.colors.colPrimary

                    Behavior on height {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                        }
                    }
                }
            }
        }

        MediaButton {
            iconName: "skip_previous"
            accessibleName: qsTr("Previous track")
            enabled: root.player !== null && root.player.canGoPrevious
            onClicked: root.player.previous()
        }

        MediaButton {
            iconName: root.player && root.player.isPlaying ? "pause" : "play_arrow"
            accessibleName: root.player && root.player.isPlaying ? qsTr("Pause") : qsTr("Play")
            enabled: root.player !== null && root.player.canTogglePlaying
            iconColor: Appearance.colors.colPrimary
            onClicked: root.player.togglePlaying()
        }

        MediaButton {
            iconName: "skip_next"
            accessibleName: qsTr("Next track")
            enabled: root.player !== null && root.player.canGoNext
            onClicked: root.player.next()
        }

        Item {
            id: titleSlot

            readonly property real titleExtent: Math.min(Math.max(0, root.maximumTitleWidth),
                                                         titleText.implicitWidth)
            implicitWidth: root.vertical ? 28 : titleExtent
            implicitHeight: root.vertical ? titleExtent : 28
            Layout.alignment: Qt.AlignCenter

            Item {
                id: titleViewport

                anchors.centerIn: parent
                width: titleSlot.titleExtent
                height: 28
                rotation: root.vertical ? (PersonalizationConfig.barPosition === "left" ? -90 : 90) : 0
                clip: true
                readonly property bool overflowing: titleText.implicitWidth > width

                onWidthChanged: restartScroll()
                Component.onCompleted: restartScroll()

                function restartScroll() {
                    titleScroll.stop();
                    titleStrip.x = 0;
                    if (overflowing && root.visible)
                        titleScroll.start();
                }

                Item {
                    id: titleStrip

                    height: parent.height
                    width: titleText.implicitWidth

                    Text {
                        id: titleText

                        anchors.verticalCenter: parent.verticalCenter
                        text: root.title
                        textFormat: Text.PlainText
                        font.family: Fonts.ui
                        font.pointSize: 11
                        color: Appearance.colors.colOnSurface
                        onTextChanged: Qt.callLater(titleViewport.restartScroll)
                        onImplicitWidthChanged: Qt.callLater(titleViewport.restartScroll)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: titleText.implicitWidth + 32
                        text: root.title
                        textFormat: Text.PlainText
                        font: titleText.font
                        color: titleText.color
                        visible: titleViewport.overflowing
                    }
                }

                Connections {
                    target: root
                    function onVisibleChanged() {
                        titleViewport.restartScroll();
                    }
                }

                SequentialAnimation {
                    id: titleScroll

                    loops: Animation.Infinite
                    PropertyAction {
                        target: titleStrip
                        property: "x"
                        value: 0
                    }
                    PauseAnimation {
                        duration: 1200
                    }
                    NumberAnimation {
                        target: titleStrip
                        property: "x"
                        from: 0
                        to: -(titleText.implicitWidth + 32)
                        duration: (titleText.implicitWidth + 32) * 35
                        easing.type: Easing.Linear
                    }
                }
            }

            HoverHandler {
                id: titleHover
            }

            StyledToolTip {
                text: root.title
                extraVisibleCondition: titleHover.hovered && titleViewport.overflowing
            }
        }
    }

    component MediaButton: IconButton {
        Layout.alignment: Qt.AlignCenter
        controlSize: 28
        iconSize: 22
        opacity: enabled ? 1 : 0.35
    }
}

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

        // МОЁ ИЗМЕНЕНИЕ: в панели осталась только волна. Клик по ней
        // открывает мини-плеер островка (вкладка Media) — там перемотка,
        // пауза и обложка. Кнопки и бегущее название отсюда убраны.
        //
        // MouseArea лежит в Item поверх Row, а не внутри Row: элемент с
        // anchors внутри Row ломает раскладку («Row will not function»).
        Item {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28

            Row {
                id: spectrumRow

                anchors.centerIn: parent
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

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: KeystoneBridge.mediaRequested()
            }

            StyledToolTip {
                text: root.title === "" ? qsTr("Open player") : root.title
                extraVisibleCondition: spectrumHover.hovered
            }

            HoverHandler {
                id: spectrumHover
            }
        }

        // МОЁ ИЗМЕНЕНИЕ: бегущее название трека убрано из панели —
        // оно видно в мини-плеере и во всплывающей подсказке волны.
    }

}

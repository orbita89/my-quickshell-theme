import QtQuick
import QtQuick.Layouts

// Layout adapted from Caelestia Shell's dashboard composition (GPL-3.0).
Item {
    id: root

    property var screen: null
    readonly property var keyholeGlassItems: keyholeCardCarousel.blurBackgroundItems
    readonly property real clockColumnWidth: 160
    readonly property real profileColumnWidth: 392
    readonly property real layoutMargin: 32
    readonly property real layoutSpacing: 24
    // ЛОКАЛЬНАЯ ПРАВКА: плашка была 340 и отстояла от календаря на 30 —
    // вместе с промежутком колонок это давало 54 px пустоты, а справа от
    // самой плашки оставалось ещё 38. Теперь она шире, а отступ меньше.
    readonly property real keyholeWidth: 400
    readonly property real keyholeLeftMargin: 14
    readonly property real keyholeCenterOffset: layoutMargin + clockColumnWidth + layoutSpacing + profileColumnWidth + layoutSpacing + keyholeLeftMargin - implicitWidth / 2
    // Вырез в фоне островка рисуется по этим числам (KeystoneSurface.qml),
    // раньше они были продублированы там вручную.
    readonly property real keyholeHeight: implicitHeight - layoutMargin * 2
    readonly property real keyholeTopOffset: layoutMargin

    signal closeRequested()
    signal avatarEditRequested()

    // Ширина складывается из колонок, иначе её пришлось бы пересчитывать
    // руками при каждом изменении плашки.
    implicitWidth: layoutMargin + clockColumnWidth + layoutSpacing + profileColumnWidth + layoutSpacing
                   + keyholeLeftMargin + keyholeWidth + layoutMargin
    implicitHeight: 520

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.layoutMargin
        spacing: root.layoutSpacing

        DashboardClock {
            Layout.minimumWidth: root.clockColumnWidth
            Layout.preferredWidth: root.clockColumnWidth
            Layout.maximumWidth: root.clockColumnWidth
            Layout.fillHeight: true
        }

        ColumnLayout {
            Layout.minimumWidth: root.profileColumnWidth
            Layout.preferredWidth: root.profileColumnWidth
            Layout.maximumWidth: root.profileColumnWidth
            Layout.fillHeight: true
            spacing: 16

            // ЛОКАЛЬНАЯ ПРАВКА: вместо карточки с данными о системе
            // (пользователь, дистрибутив, аптайм) — накопленный расход
            // ресурсов по программам за час, день и неделю.
            ResourceStats {
                Layout.fillWidth: true
                // Поля 12+12, шапка 20, отступ 8 и четыре строки по 26
                // с промежутками 8 — ровно столько, чтобы список не обрезался.
                Layout.preferredHeight: 180
            }

            CalendarCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            KeyholeCardCarousel {
                id: keyholeCardCarousel

                width: root.keyholeWidth
                anchors.left: parent.left
                anchors.leftMargin: root.keyholeLeftMargin
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                screen: root.screen
            }

        }

    }

}

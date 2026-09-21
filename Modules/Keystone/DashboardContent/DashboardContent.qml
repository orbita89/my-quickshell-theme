import QtQuick
import QtQuick.Layouts

// Layout adapted from Caelestia Shell's dashboard composition (GPL-3.0).
Item {
    id: root

    property var screen: null
    readonly property var keyholeGlassItems: keyholeCardCarousel.blurBackgroundItems
    // ЛОКАЛЬНАЯ ПРАВКА: колонка с большими часами убрана — время и так есть
    // в плашке островка. Освободившиеся 184 px (160 колонка + 24 промежуток)
    // частично ушли в правую карточку: она была 340, потом 400, теперь 440.
    readonly property real profileColumnWidth: 392
    // ЛОКАЛЬНАЯ ПРАВКА: было 32. Поле отделяло плашку от правого края
    // панели заметной полосой, а сверху и снизу съедало высоту, которой
    // не хватало быстрым настройкам.
    readonly property real layoutMargin: 20
    // ЛОКАЛЬНАЯ ПРАВКА: было 24 плюс ещё 14 отступа у самой плашки — между
    // ней и календарём набегало 38. Теперь промежуток один и такой же, как
    // между карточками внутри левой колонки.
    readonly property real layoutSpacing: 16
    // Плашка забрала освободившиеся 22 px: её правый край остался на месте,
    // сдвинулся только левый.
    readonly property real keyholeWidth: 462
    readonly property real keyholeLeft: layoutMargin + profileColumnWidth + layoutSpacing
    readonly property real keyholeCenterOffset: keyholeLeft - implicitWidth / 2
    // Вырез в фоне островка рисуется по этим числам (KeystoneSurface.qml),
    // раньше они были продублированы там вручную.
    readonly property real keyholeHeight: implicitHeight - layoutMargin * 2
    readonly property real keyholeTopOffset: layoutMargin

    signal closeRequested()
    signal avatarEditRequested()

    // Ширина складывается из колонок, иначе её пришлось бы пересчитывать
    // руками при каждом изменении плашки.
    implicitWidth: keyholeLeft + keyholeWidth + layoutMargin
    implicitHeight: 520

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.layoutMargin
        spacing: root.layoutSpacing

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
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                screen: root.screen
            }

        }

    }

}

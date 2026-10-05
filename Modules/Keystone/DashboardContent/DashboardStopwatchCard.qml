import QtQuick
import "../../Sidebars/Dashboard/infoTools"

// МОЙ МОДУЛЬ: карточка «Секундомер» в плашке Dashboard.
//
// Тот же Stopwatch, что раньше был во вкладке «Таймер» центра уведомлений
// (вкладку убрали): время, круги, старт/пауза и сброс. Состояние живёт в
// TimerService, поэтому запущенный секундомер продолжает идти, даже пока
// карточка не видна.
Item {
    id: root

    property bool active: false

    Stopwatch {
        anchors.fill: parent
    }
}

import QtQuick
import "../../Sidebars/Dashboard/infoTools"

// МОЙ МОДУЛЬ: карточка Pomodoro в плашке Dashboard.
//
// Раньше здесь была своя урезанная версия: кольцо, точки циклов и две
// кнопки. Ни длительности, ни макро-задачи настроить было нельзя, а вся
// логика дублировала боковую панель — значит любую правку пришлось бы
// делать дважды.
//
// Теперь это тот же PomodoroTimer, что и во вкладке Timer боковой панели:
// поля задачи, сохранённые задачи, шаги длительностей, Start и Reset.
// Отличается только размером кольца — в карточке места меньше.
Item {
    id: root

    property bool active: false

    PomodoroTimer {
        anchors.fill: parent
        ringSize: 170
        ringAnimated: root.active
    }
}

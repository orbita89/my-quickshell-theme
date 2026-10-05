import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Services
import qs.Widgets.common

// ЛОКАЛЬНАЯ ПРАВКА: колонка групп в прокручиваемой области, а не ListView.
//
// У групп разная высота, и ListView угадывал размер ещё не созданных строк,
// а по мере их появления сдвигал всё содержимое (originY гулял на сотни
// пикселей). Контроллер колеса (WheelScrollController) в это время докручивал
// к уже неверной цели: один щелчок уводил список на 600 px вниз, следующий —
// за верхний край, и казалось, что прокрутка не работает вовсе. Групп немного
// (по одной на приложение), поэтому все они создаются сразу, высота известна
// точно и прыгать нечему.
StyledFlickable {
    id: root

    property bool popup: false
    property int dragIndex: -1
    property real dragDistance: 0

    function resetDrag() {
        root.dragIndex = -1;
        root.dragDistance = 0;
    }

    contentWidth: width
    contentHeight: groupsColumn.implicitHeight
    flickableDirection: Flickable.VerticalFlick

    Column {
        id: groupsColumn

        width: root.width
        spacing: 3

        Repeater {
            model: ScriptModel {
                values: root.popup ? NotificationManager.popupAppNameList : NotificationManager.appNameList
            }

            delegate: NotificationGroup {
                required property int index
                required property var modelData

                delegateIndex: index
                dragHost: root
                popup: root.popup
                width: groupsColumn.width
                notificationGroup: root.popup ? NotificationManager.popupGroupsByAppName[modelData] :
                                                NotificationManager.groupsByAppName[modelData]
            }
        }
    }
}

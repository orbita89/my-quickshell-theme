import QtQuick
import QtQuick.Layouts
import qs.Services
import "./notifications"
import "./infoTools"

Item {
    id: root

    signal imageSelectionRequested(bool forAvatar)
    signal bannerColorRequested

    property string screenName: ""
    property bool foreground: false
    readonly property bool isForeground: root.foreground

    onIsForegroundChanged: {
        SystemIdentityService.setUptimeConsumer("left-sidebar-info:" + root.screenName, root.isForeground);
        if (isForeground) {
            NotificationManager.hideAllPopups();
            NotificationManager.beginViewing();
            Time.refreshNow();
        }
    }
    Component.onCompleted: SystemIdentityService.setUptimeConsumer("left-sidebar-info:" + root.screenName,
                                                                   root.isForeground)
    Component.onDestruction: SystemIdentityService.setUptimeConsumer("left-sidebar-info:" + root.screenName,
                                                                     false)

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ЛОКАЛЬНАЯ ПРАВКА: карточка профиля (аватар, имя машины, аптайм)
        // убрана — не нужна. Вместо выдвижной панели с тремя инструментами
        // здесь остались только уведомления: календарь убран, а «To-do» и
        // «Timer» переехали в замочную скважину главного меню (Dashboard).
        NotificationList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

    }
}

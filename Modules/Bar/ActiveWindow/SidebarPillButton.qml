import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    id: root

    property string viewName: "info"
    property string sidebarIconName: "notifications"
    property color activeColor: Appearance.colors.colSecondaryContainer
    property color activeContentColor: Appearance.colors.colOnSecondaryContainer
    readonly property bool isActive: WidgetState.dashboardSidebarOpen && WidgetState.dashboardSidebarView
                                     === root.viewName

    function toggleView() {
        if (root.isActive) {
            WidgetState.dashboardSidebarOpen = false;
            return;
        }
        WidgetState.dashboardSidebarView = root.viewName;
        WidgetState.dashboardSidebarOpen = true;
    }

    selected: root.isActive
    iconName: root.sidebarIconName
    containerColor: root.activeColor
    rippleColor: root.activeContentColor
    iconColor: root.activeContentColor
    tooltipText: root.viewName === "drawer" ? qsTr("Drawer") : qsTr("Notification center")
    onClicked: root.toggleView()

    // МОЁ ДОБАВЛЕНИЕ: красная точка на колокольчике — есть непрочитанные
    // уведомления (NotificationManager.unread). Гаснет, когда центр
    // уведомлений открыт.
    Rectangle {
        readonly property real size: 8

        visible: root.viewName === "info" && NotificationManager.unread > 0 && !root.isActive
        width: size
        height: size
        radius: size / 2
        x: parent.width / 2 + 3
        y: parent.height / 2 - 9
        z: 10
        color: "#f2453d"
        border.width: 1.5
        border.color: Appearance.colors.colLayer0
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets.common

MouseArea {
    id: root

    property int delegateIndex: -1
    property var notificationGroup
    property var notifications: notificationGroup && notificationGroup.notifications
                                ? notificationGroup.notifications : []
    property int notificationCount: notifications.length
    property bool multipleNotifications: notificationCount > 1
    // ЛОКАЛЬНАЯ ПРАВКА: группы всегда раскрыты — все уведомления видны сразу,
    // сворачивать нечего (кнопка свёртывания скрыта).
    readonly property bool expanded: true
    property bool popup: false
    property real padding: 10
    property real dragConfirmThreshold: 70
    property real dismissOvershoot: 20
    property var dragHost
    property int parentDragIndex: dragHost ? dragHost.dragIndex : -1
    property real parentDragDistance: dragHost ? dragHost.dragDistance : 0
    property int dragIndexDiff: Math.abs(parentDragIndex - delegateIndex)
    property real xOffset: dragIndexDiff === 0 ? parentDragDistance : Math.abs(parentDragDistance)
                                                 > dragConfirmThreshold ? 0 : dragIndexDiff === 1
                                                                          ? parentDragDistance * 0.3 :
                                                                            dragIndexDiff === 2
                                                                            ? parentDragDistance * 0.1 : 0
    readonly property bool latestNotificationHasImage: notificationCount > 0
                                                       && notifications[notificationCount - 1].image !== ""

    function isCriticalUrgency(urgency) {
        return urgency === NotificationUrgency.Critical || String(urgency).endsWith("Critical");
    }

    function destroyWithAnimation(left = false) {
        if (root.dragHost)
            root.dragHost.resetDrag();

        dragManager.resetDrag();
        background.anchors.leftMargin = background.anchors.leftMargin;
        destroyAnimation.left = left;
        destroyAnimation.running = true;
    }

    // Группы всегда раскрыты; оставлено для правого клика и кнопки.
    function toggleExpanded() {}

    implicitHeight: background.implicitHeight
    hoverEnabled: true

    NotificationUtils {
        id: notifUtils
    }

    SequentialAnimation {
        id: destroyAnimation

        property bool left: true

        running: false
        onFinished: {
            NotificationManager.discardNotifications(root.notifications.map(notif => {
                return notif.notificationId;
            }));
        }

        NumberAnimation {
            target: background.anchors
            property: "leftMargin"
            to: (root.width + root.dismissOvershoot) * (destroyAnimation.left ? -1 : 1)
            duration: Appearance.animation.expressiveDefaultSpatial.duration
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }
    }

    DragManager {
        id: dragManager

        anchors.fill: parent
        interactive: !root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton)
                root.toggleExpanded();
        }
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.destroyWithAnimation();
            else if (mouse.button === Qt.LeftButton && root.notificationCount === 1)
                NotificationManager.activateNotification(root.notifications[0].notificationId);
        }
        onDraggingChanged: {
            if (dragging && root.dragHost)
                root.dragHost.dragIndex = root.delegateIndex;
        }
        onDragDiffXChanged: {
            if (root.dragHost)
                root.dragHost.dragDistance = dragDiffX;
        }
        onDragReleased: diffX => {
            if (Math.abs(diffX) > root.dragConfirmThreshold) {
                root.destroyWithAnimation(diffX < 0);
            } else {
                dragManager.resetDrag();
                if (root.dragHost)
                    root.dragHost.resetDrag();
            }
        }
    }

    Rectangle {
        id: background

        anchors.left: parent.left
        anchors.leftMargin: root.xOffset
        width: parent.width
        color: root.popup ? Appearance.colors.colBackgroundSurfaceContainer :
                            BlurService.opaqueBackgroundColor(Appearance.m3colors.m3surfaceContainer)
        radius: Appearance.rounding.normal
        clip: true
        implicitHeight: root.expanded ? row.implicitHeight + root.padding * 2 : Math.min(80,
                                                                                         row.implicitHeight
                                                                                         + root.padding * 2)

        RowLayout {
            id: row

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.padding
            spacing: 10

            NotificationAppIcon {
                Layout.alignment: Qt.AlignTop
                image: root.multipleNotifications || root.notificationCount === 0 ? "" :
                                                                                    root.notifications[0].image

                appIcon: root.notificationGroup ? root.notificationGroup.appIcon : ""
                summary: root.notificationCount > 0 ? root.notifications[root.notificationCount - 1].summary :
                                                      ""
                urgency: root.notifications.some(notif => {
                    return root.isCriticalUrgency(notif.urgency);
                }) ? NotificationUrgency.Critical : NotificationUrgency.Normal
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: root.expanded ? (root.multipleNotifications ? (root.latestNotificationHasImage ? 35 :
                                                                                                          5) : 0) : 0

                Item {
                    id: topRow

                    property real fontSize: 12
                    property bool showAppName: root.multipleNotifications

                    Layout.fillWidth: true
                    implicitHeight: Math.max(topTextRow.implicitHeight, expandButton.implicitHeight)

                    RowLayout {
                        id: topTextRow

                        anchors.left: parent.left
                        anchors.right: expandButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            // Несколько уведомлений — шапка группы с источником
                            // («Brave · Slack»), одно — его заголовок.
                            text: (topRow.showAppName ? (root.notificationCount > 0
                                                         ? NotificationManager.sourceLabel(
                                                               root.notifications[root.notificationCount - 1])
                                                         : root.notificationGroup
                                                           ? root.notificationGroup.appName : "") : (
                                                            root.notificationCount > 0
                                                            ? root.notifications[0].summary : "")) || ""
                            font.family: Fonts.ui
                            font.pixelSize: topRow.showAppName ? topRow.fontSize : 13
                            font.bold: !topRow.showAppName
                            color: topRow.showAppName ? Appearance.colors.colSubtext :
                                                        Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.rightMargin: 10
                            horizontalAlignment: Text.AlignLeft
                            // Одиночное уведомление: источник и время прихода. У группы
                            // из нескольких время стоит у каждого уведомления
                            // (NotificationItem), здесь его не повторяем.
                            visible: text !== ""
                            text: {
                                if (topRow.showAppName || root.notificationCount === 0)
                                    return "";
                                const source = NotificationManager.sourceLabel(root.notifications[0]);
                                const time = NotificationManager.receivedTimeText(root.notifications[0].receivedAt,
                                                                                  Time.now);
                                return source !== "" ? source + " · " + time : time;
                            }
                            font.family: Fonts.numeric
                            font.pixelSize: topRow.fontSize
                            color: Appearance.colors.colSubtext
                        }
                    }

                    NotificationGroupExpandButton {
                        id: expandButton

                        visible: false
                        width: 0
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        count: root.notificationCount
                        expanded: root.expanded
                        fontSize: topRow.fontSize
                        onClicked: root.toggleExpanded()
                        altAction: () => {
                            return root.toggleExpanded();
                        }
                    }
                }

                // ЛОКАЛЬНАЯ ПРАВКА: колонка, а не ListView. ListView угадывал
                // высоту ещё не созданных карточек, высота группы плясала, и
                // прокрутка центра уведомлений в раскрытых группах прыгала (см.
                // NotificationListView.qml).
                Column {
                    id: notificationsColumn

                    property int dragIndex: -1
                    property real dragDistance: 0

                    function resetDrag() {
                        dragIndex = -1;
                        dragDistance = 0;
                    }

                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: ScriptModel {
                            // Новые (с красной точкой) — первыми.
                            values: NotificationManager.orderedForDisplay(root.notifications)
                            objectProp: "notificationId"
                        }

                        delegate: NotificationItem {
                            required property int index
                            required property var modelData

                            delegateIndex: index
                            dragHost: notificationsColumn
                            width: notificationsColumn.width
                            height: implicitHeight
                            notificationObject: modelData
                            expanded: root.expanded
                            onlyNotification: root.notificationCount === 1
                            onDismissGroup: left => {
                                return root.destroyWithAnimation(left);
                            }
                        }
                    }
                }

                Behavior on spacing {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveDefaultEffects.duration
                        easing.type: Appearance.animation.expressiveDefaultEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                    }
                }
            }
        }

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging && !destroyAnimation.running

            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Behavior on implicitHeight {
            id: implicitHeightAnim

            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }
    }
}

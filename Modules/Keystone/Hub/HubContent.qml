import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Components
import qs.Modules.Keystone.CloudUploadContent
import qs.Modules.Keystone.DashboardContent
import qs.Modules.Keystone.Media

Item {
    id: root

    property var player: null
    property var screen: null
    property int currentIndex: 0
    property bool dragActive: false
    readonly property var dashboardKeyholeGlassItems: dashboardContent.keyholeGlassItems
    readonly property real dashboardKeyholeCenterOffset: dashboardContent.keyholeCenterOffset
    readonly property real dashboardKeyholeWidth: dashboardContent.keyholeWidth
    readonly property real dashboardKeyholeHeight: dashboardContent.keyholeHeight
    // 10 — отступ панели вкладок сверху, 80 — её высота, ещё 10 — зазор до
    // содержимого; дальше начинается сам Dashboard со своими полями.
    readonly property real dashboardKeyholeTopOffset: 100 + dashboardContent.keyholeTopOffset

    signal closeRequested
    signal avatarEditRequested

    function finishCloudUploadDrop(addedCount) {
        // Вкладка загрузки создаётся лениво: до первого открытия её нет.
        if (cloudUploadLoader.item)
            cloudUploadLoader.item.finishDrop(addedCount);
    }

    implicitWidth: currentIndex === 0 ? dashboardContent.implicitWidth : currentIndex === 2 ? 960 : currentIndex
                                                                                              === 3 ? 960 :
                                                                                                      760
    // ЛОКАЛЬНАЯ ПРАВКА: панель погоды (была четвёртой) убрана, высота
    // последней вкладки задана числом вместо weatherContent.height.
    implicitHeight: 80 + 20 + (currentIndex === 0 ? 520 : currentIndex === 1 ? 480 : 480)

    Shortcut {
        sequence: "Tab"
        onActivated: root.currentIndex = (root.currentIndex + 1) % 3
    }

    Shortcut {
        sequence: "Shift+Tab"
        onActivated: root.currentIndex = (root.currentIndex + 2) % 3
    }

    RowLayout {
        id: tabBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        anchors.margins: 10
        spacing: 15

        TabBtn {
            icon: "dashboard"
            title: qsTr("Dashboard")
            index: 0
        }

        TabBtn {
            icon: "queue_music"
            title: qsTr("Media")
            index: 1
        }

        TabBtn {
            icon: "cloud_upload"
            title: qsTr("Upload")
            index: 2
        }

    }

    component TabBtn: Item {
        property string icon: ""
        property string title: ""
        property int index: 0
        property bool active: root.currentIndex === index

        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: parent.parent.icon
                iconSize: 22
                fill: parent.parent.active ? 1 : 0
                color: parent.parent.active ? Appearance.colors.colOnLayer0 : Appearance.applyAlpha(
                                                  Appearance.colors.colOnLayer0, 0.5)
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            Text {
                text: parent.parent.title
                font.pixelSize: 13
                font.bold: parent.parent.active
                color: parent.parent.active ? Appearance.colors.colOnLayer0 : Appearance.applyAlpha(
                                                  Appearance.colors.colOnLayer0, 0.5)
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.active ? 40 : 0
            height: 3
            radius: 1.5
            color: Appearance.colors.colPrimary
            opacity: parent.active ? 1 : 0

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentIndex = parent.index
        }
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10

        DashboardContent {
            id: dashboardContent

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            screen: root.screen
            visible: root.currentIndex === 0
            opacity: visible ? 1 : 0
            onCloseRequested: root.closeRequested()
            onAvatarEditRequested: root.avatarEditRequested()

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }

        // ЛОКАЛЬНАЯ ПРАВКА: вкладки Media и Upload создаются при первом
        // открытии, а не при старте оболочки.
        //
        // Раньше они строились сразу вместе со всем деревом: плеер с
        // обложками и панель загрузки висели в памяти, даже если хаб ни разу
        // не открывали. Замер показал 14 МБ на двоих. Однажды загруженная
        // вкладка остаётся жить (loadedOnce) — переключение между вкладками
        // не должно каждый раз всё пересобирать.
        Loader {
            id: mediaLoader

            property bool loadedOnce: false

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.currentIndex === 1 || mediaLoader.loadedOnce
            asynchronous: true
            visible: opacity > 0.01
            opacity: root.currentIndex === 1 ? 1 : 0
            onLoaded: mediaLoader.loadedOnce = true

            sourceComponent: Media {
                player: root.player
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }

        Loader {
            id: cloudUploadLoader

            property bool loadedOnce: false

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.95
            height: 480
            active: root.currentIndex === 2 || cloudUploadLoader.loadedOnce
            asynchronous: true
            visible: opacity > 0.01
            opacity: root.currentIndex === 2 ? 1 : 0
            onLoaded: cloudUploadLoader.loadedOnce = true

            sourceComponent: CloudUploadContent {
                dragActive: root.dragActive
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }

    }
}

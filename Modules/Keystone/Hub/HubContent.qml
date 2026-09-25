import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Components
import qs.Modules.Keystone.CloudUploadContent
import qs.Modules.Keystone.DashboardContent
import qs.Modules.Keystone.DeveloperContent
import qs.Modules.Keystone.Media

Item {
    id: root

    property var player: null
    property var screen: null
    property int currentIndex: 0
    property bool dragActive: false
    // Вкладка Dashboard создаётся лениво, поэтому её может не быть.
    readonly property var dashboard: dashboardLoader.item
    readonly property var dashboardKeyholeGlassItems: root.dashboard ? root.dashboard.keyholeGlassItems : []
    readonly property real dashboardKeyholeCenterOffset: root.dashboard ? root.dashboard.keyholeCenterOffset : 0
    readonly property real dashboardKeyholeWidth: root.dashboard ? root.dashboard.keyholeWidth : 0
    readonly property real dashboardKeyholeHeight: root.dashboard ? root.dashboard.keyholeHeight : 0
    // 10 — отступ панели вкладок сверху, 80 — её высота, ещё 10 — зазор до
    // содержимого; дальше начинается сам Dashboard со своими полями.
    readonly property real dashboardKeyholeTopOffset: 100 + (root.dashboard ? root.dashboard.keyholeTopOffset : 0)

    // Пока вкладка не создана, островку нужен размер для анимации открытия —
    // иначе он раскрылся бы в ноль и дёрнулся. Значения те же, что выдаёт
    // DashboardContent: поля 20, колонка 392, промежуток 16, плашка 462.
    readonly property real dashboardFallbackWidth: 910

    signal closeRequested
    signal avatarEditRequested

    // Вкладки остаются в памяти после первого открытия. Выгружать их по
    // таймеру я пробовал — не имеет смысла: после уничтожения объектов
    // glibc не отдаёт кучу обратно системе, замер показал возврат всего
    // 5 МБ из 27. Зато пересборка при каждом открытии давала бы рывок.

    function finishCloudUploadDrop(addedCount) {
        // Вкладка загрузки создаётся лениво: до первого открытия её нет.
        if (cloudUploadLoader.item)
            cloudUploadLoader.item.finishDrop(addedCount);
    }

    // Размер островка в режиме хаба берётся отсюда (KeystoneSurface передаёт
    // его в раскладку как hubWidth/hubHeight). Пока вкладка Dashboard не
    // создана, ширину даёт запасное значение — иначе островок раскрылся бы
    // в нулевой размер и на экране не появилось бы ничего.
    // ЛОКАЛЬНАЯ ПРАВКА: вкладка Upload заметно уже и ниже остальных — на
    // ноутбучном экране 1536x864 прежние 960x580 занимали две трети высоты.
    readonly property int uploadWidth: 440
    readonly property int uploadHeight: 220

    implicitWidth: currentIndex === 0 ? (root.dashboard ? root.dashboard.implicitWidth : root.dashboardFallbackWidth) : currentIndex
                                                                                              === 2 ? root.uploadWidth :
                                                                                                      760
    // ЛОКАЛЬНАЯ ПРАВКА: панель погоды (была четвёртой) убрана, высота
    // последней вкладки задана числом вместо weatherContent.height.
    implicitHeight: 80 + 20 + (currentIndex === 0 ? 520 : currentIndex === 2 ? root.uploadHeight : 480)

    Shortcut {
        sequence: "Tab"
        onActivated: root.currentIndex = (root.currentIndex + 1) % 4
    }

    Shortcut {
        sequence: "Shift+Tab"
        onActivated: root.currentIndex = (root.currentIndex + 3) % 4
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

        TabBtn {
            icon: "terminal"
            title: qsTr("Developer")
            index: 3
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

        // Создаётся при первом открытии вкладки и отпускается, когда
        // островок долго закрыт (см. releaseTimer ниже). Загрузка
        // синхронная: вкладка открывается по умолчанию, и асинхронная
        // давала бы скачок размера островка на первом кадре.
        Loader {
            id: dashboardLoader

            property bool loadedOnce: false

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            active: (root.visible && root.currentIndex === 0) || dashboardLoader.loadedOnce
            visible: root.visible && opacity > 0.01
            opacity: root.currentIndex === 0 ? 1 : 0
            onLoaded: dashboardLoader.loadedOnce = true

            sourceComponent: DashboardContent {
                screen: root.screen
                onCloseRequested: root.closeRequested()
                onAvatarEditRequested: root.avatarEditRequested()
            }

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
            active: (root.visible && root.currentIndex === 1) || mediaLoader.loadedOnce
            asynchronous: true
            visible: root.visible && opacity > 0.01
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
            height: root.uploadHeight
            active: (root.visible && root.currentIndex === 2) || cloudUploadLoader.loadedOnce
            asynchronous: true
            visible: root.visible && opacity > 0.01
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

        // ЛОКАЛЬНАЯ ПРАВКА: вкладка Developer (Docker-виджет), тот же ленивый
        // паттерн, что у Media и Upload.
        Loader {
            id: developerLoader

            property bool loadedOnce: false

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 760
            height: 480
            active: (root.visible && root.currentIndex === 3) || developerLoader.loadedOnce
            asynchronous: true
            visible: root.visible && opacity > 0.01
            opacity: root.currentIndex === 3 ? 1 : 0
            onLoaded: developerLoader.loadedOnce = true

            sourceComponent: DockerWidget {
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }

    }
}

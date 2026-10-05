import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
// Папки вкладок импортируются, хотя типы отсюда не используются: Quickshell
// регистрирует модуль qs.* только для папок, до которых доходит по
// импортам. Без этого файл вкладки, загруженный по пути из реестра, не
// видел бы соседей («… is not a type»). Импорт ничего не создаёт.
// Новая вкладка в новой папке — добавьте её импорт сюда.
import qs.Modules.Keystone.CloudUploadContent
import qs.Modules.Keystone.DashboardContent
import qs.Modules.Keystone.DeveloperContent
import qs.Modules.Keystone.Media

// Главное меню (хаб островка Keystone): панель вкладок и их содержимое.
//
// Какие вкладки бывают — Common/KeystoneHubRegistry.qml; какие включены и в
// каком порядке — PersonalizationConfig.keystoneHubTabs. Сам этот файл
// вкладок не знает: он строит их по реестру. Как добавить вкладку —
// README.md рядом.
//
// Открытую вкладку выбирает KeystoneSurface (currentTabId). Клик по вкладке
// и Tab/Shift+Tab только просят о переключении (tabRequested) — так
// состояние живёт в одном месте.
Item {
    id: root

    property var player: null
    property var screen: null
    property bool dragActive: false
    // id открытой вкладки; KeystoneSurface гарантирует, что она включена.
    property string currentTabId: ""

    readonly property var enabledTabs: PersonalizationConfig.keystoneHubTabs
    readonly property var currentEntry: KeystoneHubRegistry.tab(root.currentTabId)
    // Созданные вкладки по id. Объект переприсваивается целиком, чтобы
    // привязки ниже узнавали о каждой новой вкладке.
    property var loadedTabs: ({})
    readonly property var currentItem: root.loadedTabs[root.currentTabId] || null

    // Свойства выреза под плашку Dashboard (KeystoneSurface рисует по ним
    // окно в фоне островка). Вкладка создаётся лениво, поэтому её может не быть.
    readonly property var dashboard: root.loadedTabs["dashboard"] || null
    readonly property bool dashboardKeyholeVisible: root.dashboard ? root.dashboard.keyholeVisible : false
    readonly property var dashboardKeyholeGlassItems: root.dashboard ? root.dashboard.keyholeGlassItems : []
    readonly property real dashboardKeyholeCenterOffset: root.dashboard ? root.dashboard.keyholeCenterOffset : 0
    readonly property real dashboardKeyholeWidth: root.dashboard ? root.dashboard.keyholeWidth : 0
    readonly property real dashboardKeyholeHeight: root.dashboard ? root.dashboard.keyholeHeight : 0
    readonly property real dashboardKeyholeTopOffset: KeystoneHubRegistry.tabBarBlockHeight + (root.dashboard
                                                                                                ? root.dashboard.keyholeTopOffset :
                                                                                                  0)

    signal tabRequested(string tabId)
    signal closeRequested
    // Запрос сменить аватар; сейчас его никто не шлёт, KeystoneSurface
    // по-прежнему умеет на него ответить.
    signal avatarEditRequested

    // Вкладки остаются в памяти после первого открытия. Выгружать их по
    // таймеру я пробовал — не имеет смысла: после уничтожения объектов
    // glibc не отдаёт кучу обратно системе, замер показал возврат всего
    // 5 МБ из 27. Зато пересборка при каждом открытии давала бы рывок.
    // Выключенная в настройках вкладка уничтожается и больше не создаётся.

    function registerTab(tabId, item) {
        const next = {};
        for (const key in root.loadedTabs) {
            if (key !== tabId)
                next[key] = root.loadedTabs[key];
        }
        if (item)
            next[tabId] = item;
        root.loadedTabs = next;
    }

    // Соседняя включённая вкладка по кругу; step = 1 или -1.
    function cycleTab(step) {
        const tabs = root.enabledTabs;
        if (tabs.length === 0)
            return;
        const index = tabs.indexOf(root.currentTabId);
        const next = index === -1 ? 0 : (index + step + tabs.length) % tabs.length;
        root.tabRequested(tabs[next]);
    }

    // Итог перетаскивания или Ctrl+V: вкладка, принимающая файлы, сама
    // решает, что показать.
    function finishCloudUploadDrop(addedCount) {
        const item = root.loadedTabs["upload"];
        if (item && typeof item.finishDrop === "function")
            item.finishDrop(addedCount);
    }

    // Размер островка в режиме хаба берётся отсюда (KeystoneSurface передаёт
    // его в раскладку как hubWidth/hubHeight). Пока вкладка не создана,
    // размер даёт реестр — иначе островок раскрылся бы в ноль и дёрнулся.
    implicitWidth: root.currentItem ? root.currentItem.implicitWidth : root.currentEntry ? root.currentEntry.width :
                                                                                          760
    implicitHeight: KeystoneHubRegistry.tabBarBlockHeight + (root.currentItem ? root.currentItem.implicitHeight :
                                                                                root.currentEntry
                                                                                ? root.currentEntry.height : 480)

    Shortcut {
        sequence: "Tab"
        onActivated: root.cycleTab(1)
    }

    Shortcut {
        sequence: "Shift+Tab"
        onActivated: root.cycleTab(-1)
    }

    RowLayout {
        id: tabBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        anchors.margins: 10
        spacing: 15

        Repeater {
            model: root.enabledTabs

            TabBtn {
                required property string modelData
                readonly property var entry: KeystoneHubRegistry.tab(modelData)

                tabId: modelData
                icon: entry ? entry.icon : ""
                title: entry ? entry.title : modelData
            }
        }
    }

    component TabBtn: Item {
        id: tabButton

        property string tabId: ""
        property string icon: ""
        property string title: ""
        readonly property bool active: root.currentTabId === tabId

        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: tabButton.icon
                iconSize: 22
                fill: tabButton.active ? 1 : 0
                color: tabButton.active ? Appearance.colors.colOnLayer0 : Appearance.applyAlpha(
                                              Appearance.colors.colOnLayer0, 0.5)
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            Text {
                text: tabButton.title
                font.pixelSize: 13
                font.bold: tabButton.active
                color: tabButton.active ? Appearance.colors.colOnLayer0 : Appearance.applyAlpha(
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
            width: tabButton.active ? 40 : 0
            height: 3
            radius: 1.5
            color: Appearance.colors.colPrimary
            opacity: tabButton.active ? 1 : 0

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
            onClicked: root.tabRequested(tabButton.tabId)
        }
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10

        // По Loader на каждую вкладку реестра — включённую или нет. Модель
        // статичная нарочно: Repeater по списку включённых пересоздавал бы
        // уже загруженные вкладки при каждой перестановке в настройках.
        // Неактивный Loader почти ничего не стоит: файл вкладки даже не
        // компилируется.
        Repeater {
            model: KeystoneHubRegistry.tabs

            Loader {
                id: tabLoader

                required property var modelData
                readonly property string tabId: modelData.id
                readonly property bool tabEnabled: root.enabledTabs.indexOf(tabId) !== -1
                readonly property bool current: root.currentTabId === tabId
                // Однажды открытая вкладка остаётся жить: переключение не
                // должно каждый раз всё пересобирать.
                property bool loadedOnce: false

                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                active: tabEnabled && ((root.visible && current) || loadedOnce)
                // Dashboard в реестре синхронная: она открывается по
                // умолчанию, и асинхронная давала бы скачок размера островка.
                asynchronous: modelData.asynchronous
                visible: root.visible && opacity > 0.01
                opacity: current ? 1 : 0

                // Неактивным Loader становится, только когда вкладку
                // выключили в настройках: тогда её объекты освобождаются.
                onActiveChanged: {
                    if (!active)
                        loadedOnce = false;
                }
                onLoaded: loadedOnce = true
                onItemChanged: root.registerTab(tabId, item)
                Component.onCompleted: setSource(modelData.source, {
                                                     "hub": root
                                                 })

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }
                }
            }
        }
    }
}

pragma Singleton
import QtQuick

// Реестр модулей главного меню (хаба островка Keystone).
//
// Здесь только описания: какие вкладки и виджеты Dashboard существуют, как
// они называются, откуда грузятся и сколько места занимают. Какие из них
// включены и в каком порядке — решает пользователь, это хранит
// PersonalizationConfig (keystone.hub в config.json).
//
// Реестр лежит в Common, а не в Modules: PersonalizationConfig проверяет по
// нему сохранённые id, а службы модули не импортируют. Поэтому компоненты
// указаны путём (source), а не типом.
//
// Как добавить вкладку или виджет — Modules/Keystone/Hub/README.md и
// Modules/Keystone/DashboardContent/README.md.
QtObject {
    id: root

    // Вкладки хаба. Порядок здесь — порядок по умолчанию.
    //
    //   id              постоянный ключ; хранится в config.json, менять нельзя
    //   title, icon     подпись и значок Material Symbols на панели вкладок
    //   source          файл вкладки; контракт описан в Hub/README.md
    //   width, height   размер области содержимого (без панели вкладок).
    //                   Нужен, пока вкладка ещё не создана: островок
    //                   раскрывается сразу в правильный размер
    //   asynchronous    создавать в фоне. Dashboard открывается первой, у неё
    //                   false — иначе на первом кадре островок дёрнется
    //   stickyOpen      не закрывать хаб, когда курсор ушёл с островка
    //                   (во вкладку перетаскивают файлы)
    //   acceptsFileDrop перетаскивание файла на островок открывает эту вкладку
    //   defaultEnabled  включена ли вкладка у тех, у кого её ещё нет в конфиге
    readonly property var tabs: [({
                                      "id": "dashboard",
                                      "title": qsTranslate("HubContent", "Dashboard"),
                                      "icon": "dashboard",
                                      "source": Qt.resolvedUrl(
                                                    "../Modules/Keystone/DashboardContent/DashboardHubTab.qml"),
                                      "width": 910,
                                      "height": 520,
                                      "asynchronous": false,
                                      "stickyOpen": false,
                                      "acceptsFileDrop": false,
                                      "defaultEnabled": true
                                  }), ({
                                           "id": "media",
                                           "title": qsTranslate("HubContent", "Media"),
                                           "icon": "queue_music",
                                           "source": Qt.resolvedUrl("../Modules/Keystone/Media/MediaHubTab.qml"),
                                           "width": 760,
                                           "height": 480,
                                           "asynchronous": true,
                                           "stickyOpen": false,
                                           "acceptsFileDrop": false,
                                           "defaultEnabled": true
                                       }), ({
                                                "id": "upload",
                                                "title": qsTranslate("HubContent", "Upload"),
                                                "icon": "cloud_upload",
                                                "source": Qt.resolvedUrl(
                                                              "../Modules/Keystone/CloudUploadContent/UploadHubTab.qml"),
                                                "width": 440,
                                                "height": 220,
                                                "asynchronous": true,
                                                "stickyOpen": true,
                                                "acceptsFileDrop": true,
                                                "defaultEnabled": true
                                            }), ({
                                                     "id": "developer",
                                                     "title": qsTranslate("HubContent", "Developer"),
                                                     "icon": "terminal",
                                                     "source": Qt.resolvedUrl(
                                                                   "../Modules/Keystone/DeveloperContent/DeveloperHubTab.qml"),
                                                     "width": 760,
                                                     "height": 480,
                                                     "asynchronous": true,
                                                     "stickyOpen": false,
                                                     "acceptsFileDrop": false,
                                                     "defaultEnabled": true
                                                 })]

    // Виджеты колонки Dashboard (слева от плашки или справа, если плашку
    // перенесли влево). Ширина у всех одна — dashboardColumnWidth.
    //
    //   preferredHeight высота виджета
    //   fillHeight      забирает свободную высоту колонки, если плашка выше
    //   services        какие службы виджет будит (для документации и
    //                   подсказок; включает их сам виджет или его служба)
    readonly property var dashboardWidgets: [({
                                                  "id": "resourceStats",
                                                  "title": qsTranslate("ResourceStats", "Resource usage"),
                                                  "icon": "monitoring",
                                                  "source": Qt.resolvedUrl(
                                                                "../Modules/Keystone/DashboardContent/Widgets/ResourceStats/ResourceStats.qml"),
                                                  "preferredHeight": 180,
                                                  "fillHeight": false,
                                                  "services": ["ProcessStatsService"],
                                                  "defaultEnabled": true
                                              }), ({
                                                       "id": "calendar",
                                                       "title": qsTranslate("KeystoneHubRegistry", "Calendar"),
                                                       "icon": "calendar_month",
                                                       "source": Qt.resolvedUrl(
                                                                     "../Modules/Keystone/DashboardContent/Widgets/Calendar/CalendarCard.qml"),
                                                       "preferredHeight": 284,
                                                       "fillHeight": true,
                                                       "services": [],
                                                       "defaultEnabled": true
                                                   })]

    // Геометрия Dashboard. Сумма по умолчанию: 20 + 392 + 16 + 462 + 20 = 910
    // в ширину, 20 + 480 + 20 = 520 в высоту — как до модульной переделки.
    readonly property int dashboardMargin: 20
    readonly property int dashboardSpacing: 16
    readonly property int dashboardColumnWidth: 392
    readonly property int keyholeWidth: 462
    readonly property int keyholeHeight: 480
    // Высота панели вкладок вместе с полями (10 + 80 + 10). На неё
    // опирается вырез плашки в фоне островка.
    readonly property int tabBarBlockHeight: 100

    readonly property var tabIds: root.tabs.map(entry => entry.id)
    readonly property var dashboardWidgetIds: root.dashboardWidgets.map(entry => entry.id)
    readonly property var defaultDisabledTabIds: root.tabs.filter(entry => entry.defaultEnabled === false).map(
                                                     entry => entry.id)
    readonly property var defaultDisabledDashboardWidgetIds: root.dashboardWidgets.filter(entry => entry.defaultEnabled
                                                                                          === false).map(entry => entry.id)

    // Описание вкладки по id или null.
    function tab(id) {
        return root.tabs.find(entry => entry.id === id) || null;
    }

    // Описание виджета Dashboard по id или null.
    function dashboardWidget(id) {
        return root.dashboardWidgets.find(entry => entry.id === id) || null;
    }

    // Варианты для полей настроек (SortableMultiSelectField).
    function options(entries) {
        return entries.map(entry => ({
                                         "value": entry.id,
                                         "label": entry.title,
                                         "icon": entry.icon
                                     }));
    }
}

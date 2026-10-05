import QtQuick
import qs.Common
import qs.Components
import qs.Services
// Папки виджетов импортируются только для регистрации модулей в Quickshell
// (см. Hub/HubContent.qml): сами виджеты грузятся по пути из реестра.
// Новый виджет в новой папке — добавьте её импорт сюда.
import qs.Modules.Keystone.DashboardContent.Widgets.Calendar
import qs.Modules.Keystone.DashboardContent.Widgets.ResourceStats
import "DashboardLayout.js" as DashboardLayout

// Раскладка вкладки Dashboard: колонка виджетов и плашка с карточками.
// Layout adapted from Caelestia Shell's dashboard composition (GPL-3.0).
//
// Что включено и в каком порядке — PersonalizationConfig
// (keystoneDashboardColumn, keystoneDashboardKeyhole*). Список виджетов —
// Common/KeystoneHubRegistry.qml. Расчёт координат — DashboardLayout.js.
// Как добавить виджет — README.md рядом.
Item {
    id: root

    property var screen: null

    readonly property bool keyholeWanted: PersonalizationConfig.keystoneDashboardKeyholeEnabled
                                          && PersonalizationConfig.keystoneKeyholeCards.length > 0
    readonly property var layout: DashboardLayout.compute(PersonalizationConfig.keystoneDashboardColumn,
                                                          KeystoneHubRegistry.dashboardWidgets, root.keyholeWanted,
                                                          PersonalizationConfig.keystoneDashboardKeyholeSide, {
                                                              "margin": KeystoneHubRegistry.dashboardMargin,
                                                              "spacing": KeystoneHubRegistry.dashboardSpacing,
                                                              "columnWidth": KeystoneHubRegistry.dashboardColumnWidth,
                                                              "keyholeWidth": KeystoneHubRegistry.keyholeWidth,
                                                              "keyholeHeight": KeystoneHubRegistry.keyholeHeight,
                                                              "emptyHeight": 200
                                                          })

    // Вырез в фоне островка рисуется по этим числам (KeystoneSurface.qml
    // через HubContent). Без плашки выреза нет.
    readonly property bool keyholeVisible: root.layout.keyholeVisible
    readonly property var keyholeGlassItems: keyholeLoader.item ? keyholeLoader.item.blurBackgroundItems : []
    readonly property real keyholeWidth: root.keyholeVisible ? KeystoneHubRegistry.keyholeWidth : 0
    readonly property real keyholeLeft: root.layout.keyholeX
    readonly property real keyholeCenterOffset: root.keyholeLeft - implicitWidth / 2
    readonly property real keyholeHeight: root.layout.innerHeight
    readonly property real keyholeTopOffset: KeystoneHubRegistry.dashboardMargin

    implicitWidth: root.layout.width
    implicitHeight: root.layout.height

    // Виджеты колонки. Loader на каждый виджет реестра; выключенный не
    // создаётся вовсе — и не будит свои службы (ResourceStats → ps).
    Repeater {
        model: KeystoneHubRegistry.dashboardWidgets

        Loader {
            required property var modelData
            readonly property var slot: root.layout.items[modelData.id] || null

            active: slot !== null
            // Синхронно: Dashboard открывается первой, и размер островка
            // не должен меняться на первом кадре.
            asynchronous: false
            source: modelData.source
            x: root.layout.stackX
            y: slot ? slot.y : 0
            width: KeystoneHubRegistry.dashboardColumnWidth
            height: slot ? slot.height : 0
        }
    }

    Loader {
        id: keyholeLoader

        active: root.layout.keyholeVisible
        x: root.layout.keyholeX
        y: KeystoneHubRegistry.dashboardMargin
        width: KeystoneHubRegistry.keyholeWidth
        height: root.layout.innerHeight

        sourceComponent: KeyholeCardCarousel {
            screen: root.screen
        }
    }

    // Всё выключено: подсказка, где включить.
    Rectangle {
        visible: root.layout.empty
        x: KeystoneHubRegistry.dashboardMargin
        y: KeystoneHubRegistry.dashboardMargin
        width: KeystoneHubRegistry.dashboardColumnWidth
        height: root.layout.innerHeight
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        Column {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 8

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "widgets"
                iconSize: 28
                color: Appearance.colors.colSubtext
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("All widgets are turned off. Turn them on in Control Center → Keystone → Main menu.")
                color: Appearance.colors.colSubtext
                font.family: Fonts.ui
                font.pixelSize: 13
            }
        }
    }
}

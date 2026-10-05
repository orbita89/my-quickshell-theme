import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

// Центр управления → Keystone → Главное меню.
//
// Все настройки хаба островка в одном месте: какие вкладки показывать и в
// каком порядке, какие виджеты стоят в колонке Dashboard, плашка с
// карточками. Списки модулей берутся из Common/KeystoneHubRegistry.qml,
// значения хранит PersonalizationConfig (keystone.hub в config.json).
//
// Поля со списками — SortableMultiSelectField: перетаскивание меняет
// порядок, крестик выключает, «+» включает обратно. У каждого поля свой
// BarLayoutDragCoordinator — внизу файла.
StyledFlickable {
    id: root

    readonly property real pageContentWidth: 600
    readonly property bool dashboardEnabled: PersonalizationConfig.keystoneHubTabEnabled("dashboard")

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

    ColumnLayout {
        id: contentColumn

        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: 30

        KeystoneSection {
            id: tabsSection
            title: tabsAnchor.title
            SettingsSearchAnchor {
                id: tabsAnchor
                target: tabsSection
                declaration:
                    '{"id":"keystone.hub.section.tabs","route":"keystone.hub","title":"Tabs","context":"KeystoneHubPage","icon":"tab","aliases":["hub tabs","dashboard","media","upload","developer"]}'
            }
            iconName: "tab"

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.rightMargin: Metrics.spacingS
                text: qsTr("Drag to reorder. A turned-off tab is not created and uses no memory. At least one tab stays on.")
                color: Appearance.colors.colSubtext
                font.family: Fonts.ui
                font.pixelSize: Typography.bodySmall.pixelSize
                wrapMode: Text.Wrap
            }

            SortableMultiSelectField {
                id: tabsField

                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.rightMargin: Metrics.spacingS
                values: PersonalizationConfig.keystoneHubTabs
                options: KeystoneHubRegistry.options(KeystoneHubRegistry.tabs)
                zone: "hubTabs"
                dragCoordinator: tabsDragCoordinator
                onToggled: tabId => {
                    return PersonalizationConfig.toggleKeystoneHubTab(tabId);
                }
                onRemoved: tabId => {
                    return PersonalizationConfig.removeKeystoneHubTab(tabId);
                }
            }
        }

        KeystoneSection {
            id: widgetsSection
            title: widgetsAnchor.title
            SettingsSearchAnchor {
                id: widgetsAnchor
                target: widgetsSection
                declaration:
                    '{"id":"keystone.hub.section.dashboard-widgets","route":"keystone.hub","title":"Dashboard widgets","context":"KeystoneHubPage","icon":"widgets","aliases":["resource usage","calendar","widgets"]}'
            }
            iconName: "widgets"
            opacity: root.dashboardEnabled ? 1 : 0.45

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.rightMargin: Metrics.spacingS
                text: root.dashboardEnabled ? qsTr("Widgets of the Dashboard column, top to bottom. Turning off Resource usage also stops collecting its statistics.") :
                                              qsTr("The Dashboard tab is turned off.")
                color: Appearance.colors.colSubtext
                font.family: Fonts.ui
                font.pixelSize: Typography.bodySmall.pixelSize
                wrapMode: Text.Wrap
            }

            SortableMultiSelectField {
                id: widgetsField

                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.rightMargin: Metrics.spacingS
                enabled: root.dashboardEnabled
                values: PersonalizationConfig.keystoneDashboardColumn
                options: KeystoneHubRegistry.options(KeystoneHubRegistry.dashboardWidgets)
                zone: "dashboardColumn"
                dragCoordinator: widgetsDragCoordinator
                onToggled: widgetId => {
                    return PersonalizationConfig.toggleKeystoneDashboardWidget(widgetId);
                }
                onRemoved: widgetId => {
                    return PersonalizationConfig.removeKeystoneDashboardWidget(widgetId);
                }
            }
        }

        KeystoneSection {
            id: keyholeSection
            title: keyholeAnchor.title
            SettingsSearchAnchor {
                id: keyholeAnchor
                target: keyholeSection
                declaration:
                    '{"id":"keystone.hub.section.keyhole","route":"keystone.hub","title":"Keyhole","context":"KeystoneHubPage","icon":"view_carousel","aliases":["cards","quick settings","pomodoro","to-do"]}'
            }
            iconName: "view_carousel"
            opacity: root.dashboardEnabled ? 1 : 0.45

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Show keyhole")
                supportingText: qsTr("The card carousel next to the Dashboard column")
                enabled: root.dashboardEnabled

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.keystoneDashboardKeyholeEnabled
                    Accessible.name: qsTr("Show keyhole")
                    onToggled: PersonalizationConfig.setKeystoneDashboardKeyholeEnabled(checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Keyhole side")
                enabled: root.dashboardEnabled && PersonalizationConfig.keystoneDashboardKeyholeEnabled

                trailing: StyledButtonGroup {
                    model: [({
                                 "value": "left",
                                 "label": qsTr("Left")
                             }), ({
                                      "value": "right",
                                      "label": qsTr("Right")
                                  })]
                    currentValue: PersonalizationConfig.keystoneDashboardKeyholeSide
                    onValueSelected: value => PersonalizationConfig.setKeystoneDashboardKeyholeSide(value)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.rightMargin: Metrics.spacingS
                text: qsTr("Cards in the keyhole. Without cards the keyhole is hidden.")
                color: Appearance.colors.colSubtext
                font.family: Fonts.ui
                font.pixelSize: Typography.bodySmall.pixelSize
                wrapMode: Text.Wrap
            }

            SortableMultiSelectField {
                id: keyholeCardsField

                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.rightMargin: Metrics.spacingS
                enabled: root.dashboardEnabled && PersonalizationConfig.keystoneDashboardKeyholeEnabled
                values: PersonalizationConfig.keystoneKeyholeCards
                options: PersonalizationConfig.keystoneKeyholeCardOptions
                zone: "keyhole"
                dragCoordinator: keyholeDragCoordinator
                onToggled: cardId => {
                    return PersonalizationConfig.toggleKeystoneKeyholeCard(cardId);
                }
                onRemoved: cardId => {
                    return PersonalizationConfig.removeKeystoneKeyholeCard(cardId);
                }
            }
        }
    }

    BarLayoutDragCoordinator {
        id: tabsDragCoordinator

        anchors.fill: parent
        z: 1000
        fields: [tabsField]
        onDropped: (tabId, targetZone, targetIndex) => {
            if (targetZone === "hubTabs")
                PersonalizationConfig.moveKeystoneHubTab(tabId, targetIndex);
        }
    }

    BarLayoutDragCoordinator {
        id: widgetsDragCoordinator

        anchors.fill: parent
        z: 1001
        fields: [widgetsField]
        onDropped: (widgetId, targetZone, targetIndex) => {
            if (targetZone === "dashboardColumn")
                PersonalizationConfig.moveKeystoneDashboardWidget(widgetId, targetIndex);
        }
    }

    BarLayoutDragCoordinator {
        id: keyholeDragCoordinator

        anchors.fill: parent
        z: 1002
        fields: [keyholeCardsField]
        onDropped: (cardId, targetZone, targetIndex) => {
            if (targetZone === "keyhole")
                PersonalizationConfig.moveKeystoneKeyholeCard(cardId, targetIndex);
        }
    }
}

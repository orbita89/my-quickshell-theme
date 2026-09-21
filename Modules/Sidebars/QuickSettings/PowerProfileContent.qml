import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// МОЙ МОДУЛЬ: выбор режима энергопотребления.
//
// Плитка в быстрых настройках переключает режимы по кругу, а здесь они видны
// все сразу с пояснением, чем отличаются. Данные и запись — PowerProfileService
// поверх power-profiles-daemon.
WidgetPanel {
    id: root

    title: qsTr("Power mode")
    icon: "battery_saver"
    showBackButton: true
    backAction: () => WidgetState.quickSettingsView = "settings"

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Metrics.spacingS

        Text {
            visible: !PowerProfileService.available
            Layout.fillWidth: true
            text: qsTr("power-profiles-daemon is not running")
            color: Appearance.colors.colSubtext
            font.family: Fonts.ui
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        // Демон сообщает, когда производительный режим урезан — обычно из-за
        // нагрева или отключённого блока питания. Без этой строки непонятно,
        // почему выбранный режим не даёт прироста.
        Rectangle {
            visible: PowerProfileService.degraded
            Layout.fillWidth: true
            Layout.preferredHeight: degradedText.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: Appearance.colors.colErrorContainer

            Text {
                id: degradedText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                text: qsTr("Performance is limited: %1").arg(PowerProfileService.degradedReason)
                color: Appearance.colors.colOnErrorContainer
                font.family: Fonts.ui
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        Repeater {
            // Демон перечисляет режимы от экономного к мощному; показываем
            // наоборот, чтобы производительный был сверху.
            model: {
                const list = PowerProfileService.profiles.slice();
                list.reverse();
                return list;
            }

            delegate: Rectangle {
                id: profileRow

                required property string modelData
                readonly property bool current: PowerProfileService.profile === profileRow.modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: Appearance.rounding.normal
                color: profileRow.current ? Appearance.colors.colPrimaryContainer : (rowHover.containsMouse ?
                                                                                         Appearance.colors.colLayer2 :
                                                                                         Appearance.colors.colLayer1)

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    MaterialSymbol {
                        text: PowerProfileService.iconFor(profileRow.modelData)
                        iconSize: 24
                        fill: profileRow.current ? 1 : 0
                        color: profileRow.current ? Appearance.colors.colOnPrimaryContainer :
                                                    Appearance.colors.colOnLayer1
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: PowerProfileService.labelFor(profileRow.modelData)
                            color: profileRow.current ? Appearance.colors.colOnPrimaryContainer :
                                                        Appearance.colors.colOnLayer1
                            font.family: Fonts.ui
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: PowerProfileService.descriptionFor(profileRow.modelData)
                            color: profileRow.current ? Appearance.colors.colOnPrimaryContainer :
                                                        Appearance.colors.colSubtext
                            font.family: Fonts.ui
                            font.pixelSize: 12
                            opacity: profileRow.current ? 0.8 : 1
                            elide: Text.ElideRight
                        }
                    }

                    MaterialSymbol {
                        visible: profileRow.current
                        text: "check"
                        iconSize: 20
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                MouseArea {
                    id: rowHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerProfileService.setProfile(profileRow.modelData)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}

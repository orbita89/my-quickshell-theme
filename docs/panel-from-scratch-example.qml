//@ pragma UseQApplication

// Своя оболочка на Quickshell — каркас.
//
// Запуск:  quickshell -c my
// Рядом спокойно живёт Clavis (quickshell -c clavis): конфигурации
// независимы, и обе можно запускать по очереди, сравнивая.
//
// Здесь намеренно нет ничего лишнего: одна панель сверху, часы, звук,
// батарея и системный трей. Всё это движок отдаёт готовыми типами,
// интеграции писать не нужно.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Widgets   // IconImage — значки трея
import Quickshell.Io        // IpcHandler
import qs.Modules.Launcher  // Spotlight, перенесён из Clavis

ShellRoot {
    // --- Поиск Spotlight ---------------------------------------------------
    // Перенесён из Clavis вместе с зависимостями (Common, Services, Widgets,
    // Components и assets). Нативные плагины Clavis.* стоят в системе
    // (~/.local/lib/qt6/qml), их пересобирать не нужно.
    //
    // Вызов:  quickshell -c my ipc call spotlight toggle
    LauncherWindow {
        id: spotlight
    }

    IpcHandler {
        target: "spotlight"

        function toggle(): string {
            spotlight.toggleWindow();
            return spotlight.windowPhase.toUpperCase();
        }

        function open(): string {
            spotlight.openSpotlight();
            return spotlight.windowPhase.toUpperCase();
        }

        function apps(): string {
            spotlight.openSpotlight("apps");
            return "APPS";
        }

        function close(): string {
            spotlight.requestClose();
            return spotlight.windowPhase.toUpperCase();
        }
    }

    // Панель создаётся для каждого монитора отдельно.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            // Полоса сверху во всю ширину. exclusiveZone резервирует под неё
            // место, чтобы окна не залезали под панель.
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 34
            exclusiveZone: 34
            color: "#d91e1e2e"   // формат AARRGGBB: полупрозрачный фон

            // --- Часы -------------------------------------------------------
            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }

            // --- Звук -------------------------------------------------------
            // Привязка к текущему устройству вывода: меняется само,
            // когда подключаются наушники.
            PwObjectTracker {
                objects: [Pipewire.defaultAudioSink]
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 16

                Text {
                    text: Qt.formatDateTime(clock.date, "dd.MM  HH:mm:ss")
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                }

                Item { Layout.fillWidth: true }   // распорка

                // Системный трей: значки приложений.
                Repeater {
                    model: SystemTray.items

                    MouseArea {
                        required property var modelData
                        implicitWidth: 20
                        implicitHeight: 20
                        onClicked: modelData.activate()

                        IconImage {
                            anchors.fill: parent
                            source: modelData.icon
                        }
                    }
                }

                Text {
                    readonly property var sink: Pipewire.defaultAudioSink
                    text: sink && sink.audio
                          ? "VOL " + Math.round(sink.audio.volume * 100) + "%"
                          : "VOL —"
                    color: "#7fc8ff"
                    font.pixelSize: 13
                }

                Text {
                    readonly property var battery: UPower.displayDevice
                    text: battery && battery.isLaptopBattery
                          ? "BAT " + Math.round(battery.percentage * 100) + "%"
                          : ""
                    color: "#ffc87f"
                    font.pixelSize: 13
                }
            }
        }
    }
}

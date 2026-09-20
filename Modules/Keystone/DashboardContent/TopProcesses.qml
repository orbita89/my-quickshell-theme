import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// МОЙ МОДУЛЬ: список самых прожорливых процессов с возможностью снять любой.
//
// Данные берутся у keytop — он уже стоит в системе и отдаёт готовый JSON
// (pid, name, command, cpuUsagePercent, memoryPercent, user). Это надёжнее
// разбора текстового вывода ps: не ломается от локали, длинных имён с
// пробелами и смены формата колонок.
//
// Проверить руками:
//     keytop value processes --format json
Item {
    id: root

    // --- Настройки внешнего вида -------------------------------------------
    // Вынесены наверх, чтобы подгонять вид под остальную оболочку одной правкой.
    property int visibleRows: 4                  // сколько строк показывать
    property int refreshIntervalMs: 4000         // как часто опрашивать
    property color titleColor: Appearance.colors.colSubtext
    property color nameColor: Appearance.colors.colOnSurface
    property color cpuColor: Appearance.colors.colTertiary      // тёплый
    property color memColor: Appearance.colors.colPrimary       // холодный
    property color barTrackColor: Appearance.colors.colLayer2
    property color cardColor: Appearance.colors.colLayer1
    property int titleFontSize: 12
    property int rowFontSize: 12
    property real cardRadius: Appearance.rounding.normal

    // --- Данные -------------------------------------------------------------
    property var processes: []
    property bool available: true

    // Память у пользовательских программ редко превышает 3-4% от всей ОЗУ,
    // поэтому шкала от 100% давала бы почти невидимые полоски. Масштабируем
    // по самому прожорливому процессу в текущем списке.
    readonly property real peakMemory: {
        let peak = 0;
        for (let i = 0; i < root.processes.length; ++i)
            peak = Math.max(peak, Number(root.processes[i].memoryPercent || 0));
        return Math.max(peak, 0.1);
    }

    // Инструменты, которыми оболочка сама снимает эти же показания. Без
    // фильтра они всплывают наверх собственного списка: короткий процесс
    // тратит почти всё своё время на счёт, и мгновенный CPU у него высокий.
    readonly property var ownToolNames: ["keytop", "key"]

    // Порог отсечения служебной мелочи. Ядерные потоки и однократные утилиты
    // занимают считанные мегабайты; настоящие программы — десятки и сотни.
    readonly property int minMemoryBytes: 8 * 1024 * 1024

    // Процессы ядра и служебная мелочь не нужны: пользователю интересны
    // программы, которые он может закрыть.
    function isUserProcess(entry) {
        if (!entry)
            return false;
        const name = String(entry.name || "");
        // Ядерные потоки перечислены в квадратных скобках и своей памяти не имеют.
        if (name === "" || name.startsWith("["))
            return false;
        if (root.ownToolNames.indexOf(name) >= 0)
            return false;
        if (Number(entry.memoryBytes || 0) < root.minMemoryBytes)
            return false;
        return true;
    }

    // Brave и прочие браузеры разворачиваются в десяток процессов с одним
    // именем. Показываем от каждой программы только самый тяжёлый — иначе
    // четыре строки списка занял бы один Brave.
    function dropDuplicateNames(list) {
        const seen = {};
        return list.filter(entry => {
            const name = String(entry.name || "");
            if (seen[name])
                return false;
            seen[name] = true;
            return true;
        });
    }

    function applyPayload(text) {
        let parsed = null;
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            root.available = false;
            return;
        }

        const list = Array.isArray(parsed && parsed.processes) ? parsed.processes : [];
        const filtered = list.filter(root.isUserProcess);
        // Сортируем по сумме нагрузки, чтобы наверх всплывало и то, что грузит
        // процессор, и то, что съедает память.
        filtered.sort((left, right) => (Number(right.cpuUsagePercent || 0) + Number(right.memoryPercent
                                                                                    || 0))
                                     - (Number(left.cpuUsagePercent || 0) + Number(left.memoryPercent || 0)));

        root.processes = root.dropDuplicateNames(filtered).slice(0, root.visibleRows);
        root.available = true;
    }

    function refresh() {
        // Пока предыдущий запуск не завершился, новый не стартуем — иначе
        // при медленном ответе процессы копились бы.
        if (!sampler.running)
            sampler.running = true;
    }

    function kill(pid) {
        const value = Number(pid);
        if (!isFinite(value) || value <= 0)
            return;
        killer.command = ["kill", "-9", String(Math.floor(value))];
        killer.running = true;
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: root.refreshIntervalMs
        running: root.visible          // не опрашиваем, когда карточка скрыта
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: sampler

        command: ["keytop", "value", "processes", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: root.applyPayload(text)
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.available = false;
        }
    }

    Process {
        id: killer

        // Список обновляем сразу после завершения процесса, чтобы строка
        // исчезла без ожидания следующего тика таймера.
        onExited: Qt.callLater(root.refresh)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: root.cardColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: qsTr("Top processes")
                color: root.titleColor
                font.family: Fonts.ui
                font.pixelSize: root.titleFontSize
                font.weight: Font.Medium
            }

            Text {
                visible: !root.available
                text: qsTr("keytop is unavailable")
                color: root.titleColor
                font.family: Fonts.ui
                font.pixelSize: root.rowFontSize
            }

            Repeater {
                model: root.processes

                delegate: Item {
                    id: processRow

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 26

                    readonly property real cpu: Number(processRow.modelData.cpuUsagePercent || 0)
                    readonly property real mem: Number(processRow.modelData.memoryPercent || 0)

                    MouseArea {
                        id: rowHover

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Имя процесса; длинное — обрезается многоточием.
                        Text {
                            Layout.fillWidth: true
                            text: processRow.modelData.name || qsTr("unknown")
                            color: root.nameColor
                            font.family: Fonts.ui
                            font.pixelSize: root.rowFontSize
                            elide: Text.ElideRight
                        }

                        // Память: полоска плюс число.
                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 4
                            Layout.alignment: Qt.AlignVCenter
                            radius: height / 2
                            color: root.barTrackColor

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, processRow.mem
                                                                            / root.peakMemory))
                                height: parent.height
                                radius: parent.radius
                                color: root.memColor

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.preferredWidth: 54
                            // В мегабайтах понятнее, чем в долях от всей памяти.
                            text: (Number(processRow.modelData.memoryBytes || 0) / 1048576).toFixed(
                                      0) + qsTr(" MB")
                            color: root.memColor
                            font.family: Fonts.numeric
                            font.pixelSize: root.rowFontSize
                            horizontalAlignment: Text.AlignRight
                        }

                        // Значение суммарное по всем ядрам, как в top и btop:
                        // на 8 ядрах занятая целиком программа даст 800%.
                        Text {
                            Layout.preferredWidth: 52
                            text: processRow.cpu.toFixed(1) + "%"
                            color: root.cpuColor
                            font.family: Fonts.numeric
                            font.pixelSize: root.rowFontSize
                            horizontalAlignment: Text.AlignRight
                        }

                        // Кнопка снятия процесса: появляется только при наведении.
                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            opacity: rowHover.containsMouse || killHover.containsMouse ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: killHover.containsMouse ? Appearance.colors.colErrorContainer :
                                                                 "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: killHover.containsMouse ? Appearance.colors.colOnErrorContainer :
                                                                     root.titleColor
                                    font.family: Fonts.ui
                                    font.pixelSize: 14
                                }
                            }

                            MouseArea {
                                id: killHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.kill(processRow.modelData.pid)
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}

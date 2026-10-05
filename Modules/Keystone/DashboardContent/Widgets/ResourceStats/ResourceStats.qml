import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services

// МОЙ МОДУЛЬ: кто съел больше всего ресурсов за час, день и неделю.
//
// Показывает не текущую нагрузку, а накопленный расход — то, по чему видно,
// что стоит оптимизировать. Историю копит ProcessStatsService, здесь только
// вывод.
//
// Единица — процессорные секунды: «42m» значит, что программа за окно
// заняла 42 минуты процессорного времени, неважно, на одном ядре или на
// четырёх сразу. Полоска показывает долю от самой прожорливой программы.
Item {
    id: root

    // --- Настройки внешнего вида -------------------------------------------
    property int visibleRows: 4
    property color titleColor: Appearance.colors.colSubtext
    property color nameColor: Appearance.colors.colOnSurface
    property color cpuColor: Appearance.colors.colTertiary      // тёплый
    property color memColor: Appearance.colors.colPrimary       // холодный
    property color barTrackColor: Appearance.colors.colLayer2
    property color cardColor: Appearance.colors.colLayer1
    property int titleFontSize: 12
    property int rowFontSize: 12
    property real cardRadius: Appearance.rounding.normal

    // --- Окна наблюдения ----------------------------------------------------
    readonly property var ranges: [
        {
            "label": qsTr("Hour"),
            "hours": 1
        },
        {
            "label": qsTr("Day"),
            "hours": 24
        },
        {
            "label": qsTr("Week"),
            "hours": 168
        }
    ]
    property int selectedRange: 0

    readonly property var rows: {
        // Корзины сервис меняет на месте, поэтому о пересчёте сообщает
        // отдельный счётчик — подписываемся на него.
        ProcessStatsService.revision;
        return ProcessStatsService.top(root.ranges[root.selectedRange].hours, root.visibleRows);
    }
    readonly property real peakCpuSeconds: root.rows.length > 0 ? Math.max(0.001, root.rows[0].cpuSeconds) : 1

    // 42 -> "42s", 750 -> "12m", 4800 -> "1h 20m"
    function formatDuration(seconds) {
        const total = Math.round(Number(seconds) || 0);
        if (total < 60)
            return total + qsTr("s");
        const minutes = Math.round(total / 60);
        if (minutes < 60)
            return minutes + qsTr("m");
        return Math.floor(minutes / 60) + qsTr("h") + " " + (minutes % 60) + qsTr("m");
    }

    function formatMemory(megabytes) {
        const value = Number(megabytes) || 0;
        if (value >= 1024)
            return (value / 1024).toFixed(1) + qsTr(" GB");
        return Math.round(value) + qsTr(" MB");
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: root.cardColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Resource usage")
                    color: root.titleColor
                    font.family: Fonts.ui
                    font.pixelSize: root.titleFontSize
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                // Переключатель окна: час / день / неделя.
                Repeater {
                    model: root.ranges

                    delegate: Rectangle {
                        id: rangeTab

                        required property var modelData
                        required property int index
                        readonly property bool selected: root.selectedRange === rangeTab.index

                        implicitWidth: rangeLabel.implicitWidth + 14
                        implicitHeight: 20
                        radius: height / 2
                        color: rangeTab.selected ? Appearance.colors.colPrimary : (tabHover.containsMouse ?
                                                                                       root.barTrackColor :
                                                                                       "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Text {
                            id: rangeLabel

                            anchors.centerIn: parent
                            text: rangeTab.modelData.label
                            color: rangeTab.selected ? Appearance.colors.colOnPrimary : root.titleColor
                            font.family: Fonts.ui
                            font.pixelSize: 11
                            font.weight: rangeTab.selected ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: tabHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedRange = rangeTab.index
                        }
                    }
                }
            }

            // Первые минуты после установки статистики ещё нет — честно об этом говорим.
            Text {
                visible: root.rows.length === 0
                Layout.fillWidth: true
                text: ProcessStatsService.hasPreviousSample ? qsTr("Collecting data…") : qsTr(
                                                                  "Waiting for the first sample…")
                color: root.titleColor
                font.family: Fonts.ui
                font.pixelSize: root.rowFontSize
            }

            Repeater {
                model: root.rows

                delegate: Item {
                    id: statsRow

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 26

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: statsRow.modelData.name
                            color: root.nameColor
                            font.family: Fonts.ui
                            font.pixelSize: root.rowFontSize
                            elide: Text.ElideRight
                        }

                        // Доля от самой прожорливой программы окна.
                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 4
                            Layout.alignment: Qt.AlignVCenter
                            radius: height / 2
                            color: root.barTrackColor

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, statsRow.modelData.cpuSeconds
                                                                           / root.peakCpuSeconds))
                                height: parent.height
                                radius: parent.radius
                                color: root.cpuColor

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.preferredWidth: 52
                            text: root.formatDuration(statsRow.modelData.cpuSeconds)
                            color: root.cpuColor
                            font.family: Fonts.numeric
                            font.pixelSize: root.rowFontSize
                            horizontalAlignment: Text.AlignRight
                        }

                        Text {
                            Layout.preferredWidth: 58
                            text: root.formatMemory(statsRow.modelData.avgMemMb)
                            color: root.memColor
                            font.family: Fonts.numeric
                            font.pixelSize: root.rowFontSize
                            horizontalAlignment: Text.AlignRight
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

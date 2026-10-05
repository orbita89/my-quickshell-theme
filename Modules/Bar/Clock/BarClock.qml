import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

// МОЙ МОДУЛЬ: часы и дата на полосе.
//
// Вертикальная полоса: часы и минуты столбиком, под ними дата «06.10».
// Горизонтальная: «14:32 · пн, 6 окт.». В подсказке — полная дата.
// 12/24 часа — общая настройка UiPreferences.useTwelveHourClock.
// Время — SystemClock с точностью до минуты: обновляется раз в минуту,
// своих таймеров нет. Включается в Настройках → Общие → Полоса («Часы и дата»).
TopBarPill {
    id: root

    property bool vertical: false

    readonly property date now: clock.date
    readonly property int hour24: root.now.getHours()
    readonly property string hours: String(UiPreferences.useTwelveHourClock ? ((root.hour24 + 11) % 12) + 1 :
                                                                               root.hour24).padStart(2, "0")
    readonly property string minutes: Qt.formatDateTime(root.now, "mm")
    readonly property string suffix: UiPreferences.useTwelveHourClock ? (root.hour24 < 12 ? "AM" : "PM") : ""

    implicitWidth: root.vertical ? Sizes.barVisualThickness : horizontalRow.implicitWidth + 24
    implicitHeight: root.vertical ? verticalColumn.implicitHeight + 16 : Sizes.barPillThickness

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Вертикальная полоса.
    ColumnLayout {
        id: verticalColumn

        visible: root.vertical
        anchors.centerIn: parent
        spacing: 0

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.hours
            color: Appearance.colors.colOnLayer0
            font.family: Fonts.numeric
            font.pixelSize: 15
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.minutes
            color: Appearance.colors.colOnLayer0
            font.family: Fonts.numeric
            font.pixelSize: 15
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitWidth: 14
            implicitHeight: 1
            color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.3)
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(root.now, "dd.MM")
            color: Appearance.colors.colSubtext
            font.family: Fonts.numeric
            font.pixelSize: 10
        }
    }

    // Горизонтальная полоса.
    RowLayout {
        id: horizontalRow

        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.hours + ":" + root.minutes + (root.suffix !== "" ? " " + root.suffix : "")
            color: Appearance.colors.colOnLayer0
            font.family: Fonts.numeric
            font.pixelSize: 14
            font.bold: true
        }

        Text {
            text: Qt.formatDateTime(root.now, "ddd, d MMM")
            color: Appearance.colors.colSubtext
            font.family: Fonts.ui
            font.pixelSize: 13
        }
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    StyledToolTip {
        text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
        extraVisibleCondition: hoverArea.containsMouse
    }
}

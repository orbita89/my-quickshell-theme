import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    // Размер кольца задаётся снаружи: в боковой панели места много, а в
    // плашке Dashboard тот же виджет должен помещаться в карточку.
    property real ringSize: 200
    // Анимацию кольца выключаем, когда виджет не на виду.
    property bool ringAnimated: true

    // МОЁ ДОБАВЛЕНИЕ: запуск и остановка макро-задачи.
    function startTask() {
        if (TimerService.startTask(taskNameField.text, taskDurationField.text)) {
            taskNameField.text = "";
            taskDurationField.text = "";
        }
    }

    function stopTask() {
        TimerService.clearTask();
        TimerService.resetPomodoro();
    }

    function saveCurrentTask() {
        const minutes = TimerService.parseDurationMinutes(taskDurationField.text);
        if (PomodoroTaskService.saveTask(taskNameField.text, minutes)) {
            taskNameField.text = "";
            taskDurationField.text = "";
        }
    }

    // Подставляет сохранённую задачу в поля выше. Меняете время и жмёте
    // «Save task» — запись обновится, потому что совпадает название.
    function editSavedTask(task) {
        if (!task)
            return;
        taskNameField.text = task.name;
        taskDurationField.text = root.humanMinutes(task.minutes);
    }

    function startSavedTask(task) {
        if (!task)
            return;
        TimerService.startTask(task.name, task.minutes + "m");
    }

    // 300 → «5h», 90 → «1h 30m», 45 → «45m»
    function humanMinutes(minutes) {
        const total = Math.max(0, Math.round(Number(minutes) || 0));
        const hours = Math.floor(total / 60);
        const rest = total % 60;
        if (hours > 0 && rest > 0)
            return qsTr("%1h %2m").arg(hours).arg(rest);
        if (hours > 0)
            return qsTr("%1h").arg(hours);
        return qsTr("%1m").arg(rest);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolCircularProgress {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: root.ringSize
            lineWidth: root.ringSize >= 180 ? 8 : 6
            value: TimerService.pomodoroLapDuration > 0 ? TimerService.pomodoroSecondsLeft
                                                          / TimerService.pomodoroLapDuration : 0
            enableAnimation: root.ringAnimated

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        const minutes = Math.floor(TimerService.pomodoroSecondsLeft / 60).toString().padStart(
                                  2, "0");
                        const seconds = Math.floor(TimerService.pomodoroSecondsLeft % 60).toString().padStart(
                                  2, "0");
                        return `${minutes}:${seconds}`;
                    }
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.numeric
                    font.pixelSize: Math.round(root.ringSize * 0.2)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.pomodoroLongBreak ? qsTr("Long break") : TimerService.pomodoroBreak
                                                           ? qsTr("Break") : qsTr("Focus")
                    color: Appearance.colors.colSubtext
                    font.family: Fonts.ui
                    font.pixelSize: 14
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitWidth: 36
                implicitHeight: 36
                radius: Appearance.rounding.full
                color: BlurService.opaqueBackgroundColor(Appearance.m3colors.m3surfaceContainer)

                Text {
                    anchors.centerIn: parent
                    text: TimerService.pomodoroCycle + 1
                    color: Appearance.colors.colOnLayer2
                    font.family: Fonts.numeric
                    font.pixelSize: 14
                }
            }
        }

        // МОЁ ДОБАВЛЕНИЕ: макро-задача (таймбоксинг). Вводим название и общее
        // время — из него считается, сколько помидоров нужно отработать.
        // Пока задача идёт, поля заблокированы, а вместо них виден прогресс.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 6
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !TimerService.pomodoroHasTask

                OutlinedTextField {
                    id: taskNameField

                    Layout.fillWidth: true
                    labelText: qsTr("Task")
                    placeholderText: qsTr("Work")
                }

                OutlinedTextField {
                    id: taskDurationField

                    Layout.preferredWidth: 96
                    // Сколько всего работать над задачей: «5h», «300m», «2h30m».
                    // Из этого числа считается количество помидоров.
                    labelText: qsTr("Time")
                    placeholderText: "5h"
                    onAccepted: root.startTask()
                }
            }

            // Прогресс по макро-задаче: «Работа · помидор 3 из 10».
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: TimerService.pomodoroHasTask
                text: {
                    const done = Math.min(TimerService.pomodoroDoneCycles + 1,
                                          TimerService.pomodoroTargetCycles);
                    const name = TimerService.pomodoroTaskName;
                    const counter = qsTr("pomodoro %1 of %2").arg(done).arg(
                                        TimerService.pomodoroTargetCycles);
                    return name === "" ? counter : name + " · " + counter;
                }
                color: Appearance.colors.colSubtext
                font.family: Fonts.ui
                font.pixelSize: 13
                opacity: 0.85
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                // Ширина от текста, а не числом: в 110 px влезали «Start task»
                // и «Save task», а русские «Запустить задачу» и «Сохранить
                // задачу» выползали за края кнопки и налезали друг на друга.
                RippleButton {
                    implicitWidth: startTaskLabel.implicitWidth + 24
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.full
                    containerColor: TimerService.pomodoroHasTask ? Appearance.colors.colSecondaryContainer :
                                                                   Appearance.colors.colPrimaryContainer
                    // Без этого подсветка наведения берётся светлая
                    // (colOnSurface по умолчанию) и текст на кнопке пропадает.
                    stateLayerColor: TimerService.pomodoroHasTask ?
                                         Appearance.colors.colSecondaryContainerHover :
                                         Appearance.colors.colPrimaryContainerHover
                    onClicked: {
                        if (TimerService.pomodoroHasTask)
                            root.stopTask();
                        else
                            root.startTask();
                    }

                    contentItem: Text {
                        id: startTaskLabel

                        text: TimerService.pomodoroHasTask ? qsTr("Stop task") : qsTr("Start task")
                        color: Appearance.colors.colOnSecondaryContainer
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Сохранить задачу, чтобы запускать её в следующие дни.
                // Повторное сохранение с тем же названием обновляет время.
                RippleButton {
                    visible: !TimerService.pomodoroHasTask
                    implicitWidth: saveTaskLabel.implicitWidth + 24
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.full
                    containerColor: Appearance.colors.colLayer2
                    stateLayerColor: Appearance.colors.colSurfaceContainerHighestHover
                    onClicked: root.saveCurrentTask()

                    contentItem: Text {
                        id: saveTaskLabel

                        text: qsTr("Save task")
                        color: Appearance.colors.colOnLayer1
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Сохранённые задачи. У каждой три действия, все видимые:
            //   по названию   — запустить;
            //   карандаш      — подставить в поля выше для изменения;
            //   крестик       — удалить.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 6
                visible: !TimerService.pomodoroHasTask && PomodoroTaskService.list.length > 0

                Repeater {
                    model: PomodoroTaskService.list

                    delegate: Rectangle {
                        id: savedChip

                        required property var modelData
                        required property int index

                        implicitWidth: chipRow.implicitWidth + 16
                        implicitHeight: 28
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colLayer2

                        RowLayout {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 4

                            RippleButton {
                                implicitWidth: savedLabel.implicitWidth + 10
                                implicitHeight: 24
                                buttonRadius: Appearance.rounding.full
                                stateLayerColor: Appearance.colors.colSurfaceContainerHighestHover
                                Accessible.name: qsTr("Start saved task %1").arg(savedChip.modelData.name)
                                onClicked: root.startSavedTask(savedChip.modelData)

                                contentItem: Text {
                                    id: savedLabel

                                    text: savedChip.modelData.name + " · " + root.humanMinutes(
                                              savedChip.modelData.minutes)
                                    color: Appearance.colors.colOnLayer1
                                    font.family: Fonts.ui
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            RippleButton {
                                implicitWidth: 20
                                implicitHeight: 20
                                buttonRadius: Appearance.rounding.full
                                stateLayerColor: Appearance.colors.colSurfaceContainerHighestHover
                                Accessible.name: qsTr("Edit saved task %1").arg(savedChip.modelData.name)
                                onClicked: root.editSavedTask(savedChip.modelData)

                                contentItem: Text {
                                    text: "✎"
                                    color: Appearance.colors.colSubtext
                                    font.family: Fonts.ui
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            RippleButton {
                                implicitWidth: 20
                                implicitHeight: 20
                                buttonRadius: Appearance.rounding.full
                                stateLayerColor: Appearance.colors.colErrorContainerHover
                                Accessible.name: qsTr("Delete saved task %1").arg(savedChip.modelData.name)
                                onClicked: PomodoroTaskService.removeTask(savedChip.index)

                                contentItem: Text {
                                    text: "×"
                                    color: Appearance.colors.colSubtext
                                    font.family: Fonts.ui
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // МОЁ ДОБАВЛЕНИЕ: настройка длительностей. Раньше 25/5/15 минут были
        // зашиты в TimerService и поменять их было нельзя. Значения хранятся
        // в ~/.config/clavis/ui-preferences.json и применяются сразу.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
            spacing: 18
            // Во время отсчёта менять длительности нельзя — сбилась бы текущая
            // фаза; сначала «Reset».
            enabled: !TimerService.pomodoroRunning
            opacity: enabled ? 1 : 0.4

            // Подпись стоит над кнопками, а не слева от них. В русском
            // «Сфокусировать» втрое длиннее «Focus», и три счётчика в ряд с
            // подписями сбоку выходили шире панели (~464 px против ~374 в
            // английском). Самая широкая строка задаёт ширину всей колонки,
            // поэтому вместе с ней расползались и поля «Задача»/«Время» выше.
            component MinuteStepper: ColumnLayout {
                id: stepper

                property string label: ""
                property int value: 0
                property int minimum: 1
                property int maximum: 180
                signal changed(int value)

                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: stepper.label
                    color: Appearance.colors.colSubtext
                    font.family: Fonts.ui
                    font.pixelSize: 11
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    RippleButton {
                        implicitWidth: 22
                        implicitHeight: 22
                        buttonRadius: Appearance.rounding.full
                        stateLayerColor: Appearance.colors.colSurfaceContainerHighestHover
                        Accessible.name: qsTr("Decrease")
                        onClicked: stepper.changed(Math.max(stepper.minimum, stepper.value - 1))

                        contentItem: Text {
                            text: "−"
                            color: Appearance.colors.colOnLayer1
                            font.family: Fonts.ui
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        text: stepper.value
                        color: Appearance.colors.colOnLayer1
                        font.family: Fonts.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        Layout.minimumWidth: 22
                    }

                    RippleButton {
                        implicitWidth: 22
                        implicitHeight: 22
                        buttonRadius: Appearance.rounding.full
                        stateLayerColor: Appearance.colors.colSurfaceContainerHighestHover
                        Accessible.name: qsTr("Increase")
                        onClicked: stepper.changed(Math.min(stepper.maximum, stepper.value + 1))

                        contentItem: Text {
                            text: "+"
                            color: Appearance.colors.colOnLayer1
                            font.family: Fonts.ui
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            MinuteStepper {
                label: qsTr("Focus")
                value: UiPreferences.pomodoroFocusMinutes
                minimum: 1
                maximum: 180
                onChanged: value => UiPreferences.setPomodoroFocusMinutes(value)
            }

            MinuteStepper {
                label: qsTr("Break")
                value: UiPreferences.pomodoroBreakMinutes
                minimum: 1
                maximum: 60
                onChanged: value => UiPreferences.setPomodoroBreakMinutes(value)
            }

            MinuteStepper {
                label: qsTr("Long")
                value: UiPreferences.pomodoroLongBreakMinutes
                minimum: 1
                maximum: 120
                onChanged: value => UiPreferences.setPomodoroLongBreakMinutes(value)
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            RippleButton {
                implicitWidth: 90
                implicitHeight: 35
                buttonRadius: Appearance.rounding.full
                containerColor: TimerService.pomodoroRunning ? Appearance.colors.colSecondaryContainer :
                                                               Appearance.colors.colPrimary
                stateLayerColor: TimerService.pomodoroRunning ? Appearance.colors.colSecondaryContainerHover :
                                                                Appearance.colors.colPrimaryHover
                pressedStateLayerColor: TimerService.pomodoroRunning
                                        ? Appearance.colors.colSecondaryContainerActive :
                                          Appearance.colors.colPrimaryActive
                rippleColor: TimerService.pomodoroRunning ? Appearance.colors.colOnSecondaryContainer :
                                                            Appearance.colors.colOnPrimary
                Accessible.name: TimerService.pomodoroRunning ? qsTr("Pause Pomodoro") : qsTr(
                                                                    "Start Pomodoro")
                onClicked: TimerService.togglePomodoro()

                contentItem: Text {
                    text: TimerService.pomodoroRunning ? qsTr("Pause") : TimerService.pomodoroSecondsLeft
                                                         === TimerService.pomodoroLapDuration ? qsTr("Start") :
                                                                                                qsTr("Resume")
                    color: TimerService.pomodoroRunning ? Appearance.colors.colOnSecondaryContainer :
                                                          Appearance.colors.colOnPrimary
                    font.family: Fonts.ui
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RippleButton {
                implicitWidth: 90
                implicitHeight: 35
                buttonRadius: Appearance.rounding.full
                enabled: TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration
                         || TimerService.pomodoroCycle > 0 || TimerService.pomodoroBreak
                containerColor: Appearance.colors.colErrorContainer
                stateLayerColor: Appearance.colors.colErrorContainerHover
                pressedStateLayerColor: Appearance.colors.colErrorContainerActive
                rippleColor: Appearance.colors.colOnErrorContainer
                Accessible.name: qsTr("Reset Pomodoro")
                onClicked: TimerService.resetPomodoro()

                contentItem: Text {
                    text: qsTr("Reset")
                    color: Appearance.colors.colOnErrorContainer
                    font.family: Fonts.ui
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolCircularProgress {
            Layout.alignment: Qt.AlignHCenter
            implicitSize: 200
            lineWidth: 8
            value: TimerService.pomodoroLapDuration > 0 ? TimerService.pomodoroSecondsLeft
                                                          / TimerService.pomodoroLapDuration : 0
            enableAnimation: true

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
                    font.pixelSize: 40
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

        // МОЁ ДОБАВЛЕНИЕ: настройка длительностей. Раньше 25/5/15 минут были
        // зашиты в TimerService и поменять их было нельзя. Значения хранятся
        // в ~/.config/clavis/ui-preferences.json и применяются сразу.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
            spacing: 14
            // Во время отсчёта менять длительности нельзя — сбилась бы текущая
            // фаза; сначала «Reset».
            enabled: !TimerService.pomodoroRunning
            opacity: enabled ? 1 : 0.4

            component MinuteStepper: RowLayout {
                id: stepper

                property string label: ""
                property int value: 0
                property int minimum: 1
                property int maximum: 180
                signal changed(int value)

                spacing: 4

                Text {
                    text: stepper.label
                    color: Appearance.colors.colSubtext
                    font.family: Fonts.ui
                    font.pixelSize: 12
                }

                RippleButton {
                    implicitWidth: 24
                    implicitHeight: 24
                    buttonRadius: Appearance.rounding.full
                    Accessible.name: qsTr("Decrease")
                    onClicked: stepper.changed(Math.max(stepper.minimum, stepper.value - 1))

                    contentItem: Text {
                        text: "−"
                        color: Appearance.colors.colOnLayer1
                        font.family: Fonts.ui
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    text: stepper.value
                    color: Appearance.colors.colOnLayer1
                    font.family: Fonts.ui
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.minimumWidth: 22
                }

                RippleButton {
                    implicitWidth: 24
                    implicitHeight: 24
                    buttonRadius: Appearance.rounding.full
                    Accessible.name: qsTr("Increase")
                    onClicked: stepper.changed(Math.min(stepper.maximum, stepper.value + 1))

                    contentItem: Text {
                        text: "+"
                        color: Appearance.colors.colOnLayer1
                        font.family: Fonts.ui
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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

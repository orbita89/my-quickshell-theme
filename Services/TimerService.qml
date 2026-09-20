pragma Singleton

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    // МОЁ ИЗМЕНЕНИЕ: длительности берутся из настроек, а не зашиты числами.
    // Меняются во вкладке «Timer» боковой панели; хранятся в
    // ~/.config/clavis/ui-preferences.json.
    readonly property int focusTime: UiPreferences.pomodoroFocusMinutes * 60
    readonly property int breakTime: UiPreferences.pomodoroBreakMinutes * 60
    readonly property int longBreakTime: UiPreferences.pomodoroLongBreakMinutes * 60
    readonly property int cyclesBeforeLongBreak: UiPreferences.pomodoroCyclesBeforeLongBreak
    readonly property int pomodoroSequenceDuration: focusTime * cyclesBeforeLongBreak + breakTime * (
                                                        cyclesBeforeLongBreak - 1) + longBreakTime

    readonly property bool pomodoroRunning: InfoDrawerState.pomodoroRunning
    readonly property bool pomodoroBreak: InfoDrawerState.pomodoroBreak
    readonly property int pomodoroCycle: InfoDrawerState.pomodoroCycle
    readonly property bool pomodoroLongBreak: pomodoroBreak && pomodoroCycle + 1 === cyclesBeforeLongBreak
    readonly property int pomodoroLapDuration: pomodoroLongBreak ? longBreakTime : pomodoroBreak ? breakTime :
                                                                                                   focusTime
    property int pomodoroSecondsLeft: focusTime

    // МОЁ ДОБАВЛЕНИЕ: макро-задача (таймбоксинг).
    // Один «помидор» = фокус + следующий за ним перерыв.
    readonly property string pomodoroTaskName: InfoDrawerState.pomodoroTaskName
    readonly property int pomodoroTargetCycles: InfoDrawerState.pomodoroTargetCycles
    readonly property int pomodoroDoneCycles: InfoDrawerState.pomodoroDoneCycles
    readonly property bool pomodoroHasTask: pomodoroTargetCycles > 0
    readonly property int pomodoroSingleCycleSeconds: focusTime + breakTime

    readonly property bool stopwatchRunning: InfoDrawerState.stopwatchRunning
    property int stopwatchTime: 0
    readonly property var stopwatchLaps: InfoDrawerState.stopwatchLaps

    function currentSeconds() {
        return Math.floor(Date.now() / 1000);
    }

    function currentCentiseconds() {
        return Math.floor(Date.now() / 10);
    }

    function normalizedPomodoroCycle(value) {
        const numberValue = Number(value);
        if (!Number.isFinite(numberValue))
            return 0;
        return Math.max(0, Math.floor(numberValue)) % root.cyclesBeforeLongBreak;
    }

    function pomodoroDurationFor(isBreak, cycle) {
        if (!isBreak)
            return root.focusTime;
        return root.normalizedPomodoroCycle(cycle) + 1 === root.cyclesBeforeLongBreak ? root.longBreakTime :
                                                                                        root.breakTime;
    }

    function syncFromStore() {
        if (!InfoDrawerState.ready)
            return;

        const normalizedCycle = root.normalizedPomodoroCycle(InfoDrawerState.pomodoroCycle);
        const cycleCorrected = normalizedCycle !== InfoDrawerState.pomodoroCycle;
        const storedSecondsLeft = Number(InfoDrawerState.pomodoroSecondsLeft);
        InfoDrawerState.pomodoroCycle = normalizedCycle;
        root.pomodoroSecondsLeft = Math.max(0, Math.min(root.pomodoroLapDuration, Number.isFinite(
                                                            storedSecondsLeft) ? storedSecondsLeft :
                                                                                 root.pomodoroLapDuration));

        if (root.pomodoroRunning)
            root.refreshPomodoro();
        else if (cycleCorrected || root.pomodoroSecondsLeft !== storedSecondsLeft)
            root.persistPomodoro();

        root.stopwatchTime = Math.max(0, InfoDrawerState.stopwatchElapsed);
        if (root.stopwatchRunning)
            root.refreshStopwatch();
    }

    function persistPomodoro() {
        InfoDrawerState.pomodoroSecondsLeft = root.pomodoroSecondsLeft;
        InfoDrawerState.flushSave();
    }

    // Принимает «5h», «300m», «2h30m», «90» (минуты) и возвращает минуты.
    function parseDurationMinutes(text) {
        const value = String(text || "").trim().toLowerCase();
        if (value === "")
            return 0;

        let minutes = 0;
        let matched = false;
        const hours = value.match(/(\d+(?:[.,]\d+)?)\s*(?:h|ч)/);
        if (hours) {
            minutes += parseFloat(hours[1].replace(",", ".")) * 60;
            matched = true;
        }
        const mins = value.match(/(\d+(?:[.,]\d+)?)\s*(?:m|м)/);
        if (mins) {
            minutes += parseFloat(mins[1].replace(",", "."));
            matched = true;
        }
        if (!matched) {
            const plain = parseFloat(value.replace(",", "."));
            if (isFinite(plain))
                minutes = plain;
        }
        return Math.max(0, Math.round(minutes));
    }

    // Считает, сколько помидоров укладывается в отведённое время.
    function cyclesForMinutes(minutes) {
        const perCycle = root.pomodoroSingleCycleSeconds / 60;
        if (perCycle <= 0)
            return 0;
        return Math.max(1, Math.round(minutes / perCycle));
    }

    function startTask(name, durationText) {
        const minutes = root.parseDurationMinutes(durationText);
        if (minutes <= 0)
            return false;

        InfoDrawerState.pomodoroTaskName = String(name || "").trim();
        InfoDrawerState.pomodoroTargetCycles = root.cyclesForMinutes(minutes);
        InfoDrawerState.pomodoroDoneCycles = 0;
        InfoDrawerState.pomodoroBreak = false;
        InfoDrawerState.pomodoroCycle = 0;
        InfoDrawerState.pomodoroStart = root.currentSeconds();
        InfoDrawerState.pomodoroRunning = true;
        root.pomodoroSecondsLeft = root.focusTime;
        root.persistPomodoro();
        root.notifyPomodoroStage();
        return true;
    }

    function clearTask() {
        InfoDrawerState.pomodoroTaskName = "";
        InfoDrawerState.pomodoroTargetCycles = 0;
        InfoDrawerState.pomodoroDoneCycles = 0;
        root.persistPomodoro();
    }

    function notifyTaskFinished() {
        const name = root.pomodoroTaskName;
        const message = name === "" ? qsTr("🎉 All cycles completed!")
                                    : qsTr("🎉 Task «%1» completed!").arg(name);
        Quickshell.execDetached(["notify-send", qsTr("Pomodoro"), message, "-a", "Clavis"]);
    }

    function notifyPomodoroStage() {
        let message = "";
        if (root.pomodoroLongBreak)
            message = qsTr("🌿 Long break: %1 minutes").arg(Math.floor(root.longBreakTime / 60));
        else if (root.pomodoroBreak)
            message = qsTr("☕ Break: %1 minutes").arg(Math.floor(root.breakTime / 60));
        else
            message = qsTr("🔴 Focus: %1 minutes").arg(Math.floor(root.focusTime / 60));

        Quickshell.execDetached(["notify-send", qsTr("Pomodoro"), message, "-a", "Clavis"]);
    }

    function refreshPomodoro() {
        if (!root.pomodoroRunning)
            return;

        const now = root.currentSeconds();
        let phaseStart = Number(InfoDrawerState.pomodoroStart);
        let isBreak = InfoDrawerState.pomodoroBreak;
        let cycle = root.normalizedPomodoroCycle(InfoDrawerState.pomodoroCycle);
        let stateCorrected = cycle !== InfoDrawerState.pomodoroCycle;
        let transitioned = false;

        if (!Number.isFinite(phaseStart) || phaseStart <= 0 || phaseStart > now) {
            phaseStart = now;
            stateCorrected = true;
        }

        let duration = root.pomodoroDurationFor(isBreak, cycle);
        // МОЁ ДОБАВЛЕНИЕ: считаем завершённые помидоры и останавливаемся,
        // когда набрана цель макро-задачи.
        let done = InfoDrawerState.pomodoroDoneCycles;
        let taskFinished = false;

        while (now >= phaseStart + duration) {
            phaseStart += duration;

            // Помидор считается завершённым в момент окончания перерыва:
            // фокус отработан и отдых после него тоже.
            if (isBreak)
                done += 1;

            if (isBreak)
                cycle = (cycle + 1) % root.cyclesBeforeLongBreak;
            isBreak = !isBreak;
            transitioned = true;
            duration = root.pomodoroDurationFor(isBreak, cycle);

            if (root.pomodoroHasTask && done >= root.pomodoroTargetCycles) {
                taskFinished = true;
                break;
            }

            if (!isBreak && cycle === 0) {
                const fullSequences = Math.floor((now - phaseStart) / root.pomodoroSequenceDuration);
                if (fullSequences > 0)
                    phaseStart += fullSequences * root.pomodoroSequenceDuration;
            }
        }

        if (done !== InfoDrawerState.pomodoroDoneCycles)
            InfoDrawerState.pomodoroDoneCycles = done;

        if (taskFinished) {
            // Задача выполнена: останавливаемся и возвращаемся в исходное
            // состояние, цель при этом сбрасывается.
            InfoDrawerState.pomodoroRunning = false;
            InfoDrawerState.pomodoroBreak = false;
            InfoDrawerState.pomodoroCycle = 0;
            InfoDrawerState.pomodoroStart = now;
            root.pomodoroSecondsLeft = root.focusTime;
            root.persistPomodoro();
            root.notifyTaskFinished();
            root.clearTask();
            return;
        }

        InfoDrawerState.pomodoroBreak = isBreak;
        InfoDrawerState.pomodoroCycle = cycle;
        InfoDrawerState.pomodoroStart = phaseStart;
        root.pomodoroSecondsLeft = Math.max(0, duration - (now - phaseStart));

        if (transitioned || stateCorrected)
            root.persistPomodoro();
        if (transitioned)
            root.notifyPomodoroStage();
    }

    function togglePomodoro() {
        if (root.pomodoroRunning) {
            root.refreshPomodoro();
            InfoDrawerState.pomodoroRunning = false;
            root.persistPomodoro();
            return;
        }

        const remaining = Math.max(0, Math.min(root.pomodoroLapDuration, root.pomodoroSecondsLeft));
        InfoDrawerState.pomodoroStart = root.currentSeconds() - (root.pomodoroLapDuration - remaining);
        InfoDrawerState.pomodoroRunning = true;
        root.persistPomodoro();
    }

    function resetPomodoro() {
        InfoDrawerState.pomodoroRunning = false;
        InfoDrawerState.pomodoroBreak = false;
        InfoDrawerState.pomodoroCycle = 0;
        InfoDrawerState.pomodoroStart = root.currentSeconds();
        root.pomodoroSecondsLeft = root.focusTime;
        root.persistPomodoro();
    }

    function refreshStopwatch() {
        if (!root.stopwatchRunning)
            return;

        if (InfoDrawerState.stopwatchStart <= 0)
            InfoDrawerState.stopwatchStart = root.currentCentiseconds() - InfoDrawerState.stopwatchElapsed;

        root.stopwatchTime = Math.max(0, root.currentCentiseconds() - InfoDrawerState.stopwatchStart);
    }

    function toggleStopwatch() {
        if (root.stopwatchRunning)
            root.stopwatchPause();
        else
            root.stopwatchResume();
    }

    function stopwatchPause() {
        root.refreshStopwatch();
        InfoDrawerState.stopwatchElapsed = root.stopwatchTime;
        InfoDrawerState.stopwatchRunning = false;
        InfoDrawerState.flushSave();
    }

    function stopwatchResume() {
        if (root.stopwatchTime === 0)
            InfoDrawerState.stopwatchLaps = [];

        InfoDrawerState.stopwatchStart = root.currentCentiseconds() - root.stopwatchTime;
        InfoDrawerState.stopwatchElapsed = root.stopwatchTime;
        InfoDrawerState.stopwatchRunning = true;
        InfoDrawerState.flushSave();
    }

    function stopwatchReset() {
        root.stopwatchTime = 0;
        InfoDrawerState.stopwatchElapsed = 0;
        InfoDrawerState.stopwatchLaps = [];
        InfoDrawerState.stopwatchRunning = false;
        InfoDrawerState.stopwatchStart = root.currentCentiseconds();
        InfoDrawerState.flushSave();
    }

    function stopwatchRecordLap() {
        if (!root.stopwatchRunning)
            return;

        root.refreshStopwatch();
        InfoDrawerState.stopwatchLaps = [...InfoDrawerState.stopwatchLaps, root.stopwatchTime];
        InfoDrawerState.flushSave();
    }

    Component.onCompleted: root.syncFromStore()

    Connections {
        target: InfoDrawerState

        function onReadyChanged() {
            if (InfoDrawerState.ready)
                root.syncFromStore();
        }
    }

    Timer {
        interval: 200
        running: root.pomodoroRunning
        repeat: true
        onTriggered: root.refreshPomodoro()
    }

    Timer {
        interval: 10
        running: root.stopwatchRunning
        repeat: true
        onTriggered: root.refreshStopwatch()
    }
}

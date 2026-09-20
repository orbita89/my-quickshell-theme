pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// МОЙ МОДУЛЬ: сохранённые помидорные задачи.
//
// Зачем: задать «Работа — 5h» один раз и запускать её потом в любой день
// одним нажатием, а когда захочется работать меньше — поменять время,
// не заводя задачу заново.
//
// Хранилище — ~/.local/state/clavis/pomodoro-tasks.json, по образцу
// TodoService: тот же порядок создания каталога, чтения и записи.
Singleton {
    id: root

    readonly property string stateDir: Paths.stateHome
    readonly property string filePath: stateDir + "/pomodoro-tasks.json"

    property bool storeReady: false
    property bool ready: false
    // [{ name: "Работа", minutes: 300 }, …]
    property var list: []

    function normalizeList(value) {
        if (!Array.isArray(value))
            return [];

        return value
            .filter(item => item && typeof item.name === "string")
            .map(item => ({
                "name": String(item.name).trim(),
                "minutes": Math.max(1, Math.round(Number(item.minutes) || 0))
            }))
            .filter(item => item.name.length > 0 && item.minutes > 0);
    }

    function save() {
        if (!root.storeReady || !root.ready)
            return;
        taskFile.setText(JSON.stringify(root.list, null, 2));
    }

    function indexOfName(name) {
        const needle = String(name || "").trim().toLocaleLowerCase();
        if (needle.length === 0)
            return -1;
        return root.list.findIndex(item => item.name.toLocaleLowerCase() === needle);
    }

    // Одна функция и на добавление, и на обновление: повторное сохранение
    // задачи с тем же именем просто меняет её длительность.
    function saveTask(name, minutes) {
        const title = String(name || "").trim();
        const total = Math.max(1, Math.round(Number(minutes) || 0));
        if (title.length === 0 || total <= 0)
            return false;

        const existing = root.indexOfName(title);
        const next = [...root.list];
        if (existing >= 0)
            next[existing] = {
                "name": title,
                "minutes": total
            };
        else
            next.push({
                "name": title,
                "minutes": total
            });

        root.list = next;
        root.save();
        return true;
    }

    function removeTask(index) {
        if (index < 0 || index >= root.list.length)
            return false;

        const next = [...root.list];
        next.splice(index, 1);
        root.list = next;
        root.save();
        return true;
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]

        onExited: {
            root.storeReady = true;
            taskFile.reload();
        }
    }

    FileView {
        id: taskFile

        path: root.filePath

        onLoaded: {
            try {
                root.list = root.normalizeList(JSON.parse(taskFile.text().trim() || "[]"));
            } catch (error) {
                console.warn("PomodoroTaskService failed to load:", error);
                root.list = [];
            }

            root.ready = true;
        }

        onLoadFailed: error => {
            if (!root.storeReady)
                return;

            if (error !== FileViewError.FileNotFound)
                console.warn("PomodoroTaskService failed to open:", error);

            root.list = [];
            root.ready = true;
            root.save();
        }
    }
}

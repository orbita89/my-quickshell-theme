pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// МОЙ МОДУЛЬ: расход ресурсов по программам за час, день и неделю.
//
// Мгновенный список «кто сейчас грузит процессор» отвечает на вопрос
// «почему сейчас шумит вентилятор», но не на вопрос «что оптимизировать»:
// программа, съевшая за день час процессорного времени короткими всплесками,
// в таком списке не появится ни разу. Поэтому здесь копится история.
//
// Как считается. Раз в 15 секунд снимается срез `ps -eo pid=,times=,rss=,comm=`.
// Колонка times — сколько процессорных секунд процесс потратил с запуска;
// счётчик целочисленный и только растёт, поэтому разница с прошлой выборкой
// и есть расход за эти 15 секунд. Секунды процессора — честная мера:
// 4 минуты на одном ядре и 1 минута на четырёх стоят одинаково.
//
// Первая версия брала расход у keytop как «средняя загрузка × возраст
// процесса». Так делать нельзя: дробный процент слегка дрожит от выборки
// к выборке, а у процесса, живущего часами, сотая доля процента — это
// десятки секунд. Отрицательные разницы отбрасывались, положительные нет,
// и шум копился в одну сторону: за минуту наблюдения набегало «36 минут».
//
// Данные раскладываются по часовым корзинам и лежат в
// ~/.local/state/clavis/process-stats.json, поэтому переживают перезапуск
// оболочки и перезагрузку.
Singleton {
    id: root

    readonly property string stateDir: Paths.stateHome
    readonly property string filePath: stateDir + "/process-stats.json"

    property int sampleIntervalMs: 15000
    readonly property int bucketMs: 3600000          // корзина — один час
    readonly property int keepBuckets: 24 * 7        // храним неделю
    readonly property int keepAppsPerBucket: 30      // в файл пишем только заметные

    property bool storeReady: false
    property bool ready: false

    // [{ h: номер часа от эпохи, apps: { "brave": { c: секунды ЦП, m: сумма МБ, n: выборок } } }]
    property var buckets: []

    // Растёт после каждой выборки. Сводка в виджете подписана на него —
    // сами корзины меняются на месте и об изменении не сообщают.
    property int revision: 0

    // { "<pid>": сколько секунд ЦП процесс потратил к прошлой выборке }
    property var previousCpu: ({})
    property bool hasPreviousSample: false
    property bool dirty: false

    function hourIndexNow() {
        return Math.floor(Date.now() / root.bucketMs);
    }

    function bucketFor(hour) {
        for (let i = root.buckets.length - 1; i >= 0; --i)
            if (root.buckets[i].h === hour)
                return root.buckets[i];

        const fresh = {
            "h": hour,
            "apps": {}
        };
        root.buckets.push(fresh);
        return fresh;
    }

    function prune() {
        const oldest = root.hourIndexNow() - root.keepBuckets;
        root.buckets = root.buckets.filter(bucket => bucket.h > oldest);
    }

    function applySample(text) {
        const lines = String(text || "").split("\n");
        const seenCpu = {};
        // Программа вроде браузера живёт в двух десятках процессов; расход
        // складываем по имени, иначе один Brave занял бы весь список.
        const perApp = {};

        for (let i = 0; i < lines.length; ++i) {
            // "  1234    567  89012 brave" — имя идёт последним, потому что
            // в нём могут быть пробелы, а числа перед ним разобрать проще.
            const parts = lines[i].trim().match(/^(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/);
            if (!parts)
                continue;

            const pid = parts[1];
            const cpuSeconds = Number(parts[2]);
            const memoryKb = Number(parts[3]);
            const name = parts[4].trim();

            // Потоки ядра не занимают память в пространстве пользователя —
            // оптимизировать в них всё равно нечего.
            if (memoryKb <= 0 || name === "")
                continue;

            seenCpu[pid] = cpuSeconds;

            let delta = 0;
            if (root.previousCpu.hasOwnProperty(pid)) {
                // Счётчик только растёт, поэтому падение значит, что pid
                // достался новому процессу: начинаем отсчёт заново.
                delta = Math.max(0, cpuSeconds - root.previousCpu[pid]);
            }
            // Процесс, увиденный впервые, только запоминаем. Засчитать ему
            // всё время с запуска нельзя: после перезапуска оболочки браузер
            // разом принёс бы часы расхода в текущую корзину.

            const slot = perApp[name] || (perApp[name] = {
                "c": 0,
                "m": 0
            });
            slot.c += delta;
            slot.m += memoryKb / 1024;
        }

        const bucket = root.bucketFor(root.hourIndexNow());
        for (const name in perApp) {
            const app = bucket.apps[name] || (bucket.apps[name] = {
                "c": 0,
                "m": 0,
                "n": 0
            });
            app.c += perApp[name].c;
            app.m += perApp[name].m;
            app.n += 1;
        }

        root.previousCpu = seenCpu;
        root.hasPreviousSample = true;
        root.dirty = true;
        root.prune();
        root.revision += 1;
    }

    // Сводка за последние `hours` часов: [{ name, cpuSeconds, avgMemMb }].
    function top(hours, limit) {
        const from = root.hourIndexNow() - (hours - 1);
        const totals = {};

        for (let i = 0; i < root.buckets.length; ++i) {
            const bucket = root.buckets[i];
            if (bucket.h < from)
                continue;

            for (const name in bucket.apps) {
                const app = bucket.apps[name];
                const slot = totals[name] || (totals[name] = {
                    "cpu": 0,
                    "mem": 0,
                    "samples": 0
                });
                slot.cpu += app.c;
                slot.mem += app.m;
                slot.samples += app.n;
            }
        }

        const rows = [];
        for (const name in totals) {
            const slot = totals[name];
            if (slot.cpu <= 0)
                continue;
            rows.push({
                "name": name,
                "cpuSeconds": slot.cpu,
                "avgMemMb": slot.samples > 0 ? slot.mem / slot.samples : 0
            });
        }

        rows.sort((left, right) => right.cpuSeconds - left.cpuSeconds);
        return rows.slice(0, limit);
    }

    function serialize() {
        const out = [];
        for (let i = 0; i < root.buckets.length; ++i) {
            const bucket = root.buckets[i];
            const names = Object.keys(bucket.apps).sort((left, right) => bucket.apps[right].c
                                                      - bucket.apps[left].c).slice(0, root.keepAppsPerBucket);
            const apps = {};
            for (let j = 0; j < names.length; ++j) {
                const app = bucket.apps[names[j]];
                apps[names[j]] = {
                    "c": Math.round(app.c * 100) / 100,
                    "m": Math.round(app.m),
                    "n": app.n
                };
            }
            out.push({
                "h": bucket.h,
                "apps": apps
            });
        }
        return JSON.stringify(out);
    }

    function normalize(value) {
        if (!Array.isArray(value))
            return [];

        return value.filter(bucket => bucket && typeof bucket.h === "number" && bucket.apps).map(bucket => ({
                    "h": bucket.h,
                    "apps": bucket.apps
                }));
    }

    function save() {
        if (!root.storeReady || !root.ready)
            return;
        statsFile.setText(root.serialize());
        root.dirty = false;
    }

    Timer {
        interval: root.sampleIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sampler.running)
                sampler.running = true;
        }
    }

    // Запись раз в минуту, а не после каждой выборки: файл на неделю истории
    // весит сотни килобайт, и переписывать его каждые 15 секунд незачем.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            if (root.dirty)
                root.save();
        }
    }

    Process {
        id: sampler

        command: ["ps", "-eo", "pid=,times=,rss=,comm="]
        stdout: StdioCollector {
            onStreamFinished: root.applySample(text)
        }
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]

        onExited: {
            root.storeReady = true;
            statsFile.reload();
        }
    }

    FileView {
        id: statsFile

        path: root.filePath

        onLoaded: {
            try {
                root.buckets = root.normalize(JSON.parse(statsFile.text().trim() || "[]"));
            } catch (error) {
                console.warn("ProcessStatsService failed to load:", error);
                root.buckets = [];
            }

            root.prune();
            root.ready = true;
            root.revision += 1;
        }

        onLoadFailed: error => {
            if (!root.storeReady)
                return;

            if (error !== FileViewError.FileNotFound)
                console.warn("ProcessStatsService failed to open:", error);

            root.buckets = [];
            root.ready = true;
        }
    }
}

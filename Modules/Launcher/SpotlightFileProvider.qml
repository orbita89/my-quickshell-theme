import QtQuick
import Quickshell.Io
import qs.Common

// ЛОКАЛЬНАЯ ПРАВКА: режим «Файлы» переведён с key-cli на прямой вызов fd.
//
// Раньше провайдер обращался к FileSearchService, тот запускал key-cli, а он
// строил общий индекс по домашнему каталогу. Теперь ищем сами: одна папка на
// выбор, один вызов fd, не больше пятнадцати строк. Плюс появилось действие,
// которого не было вовсе, — положить найденный файл в буфер обмена как файл,
// а не как строку пути.
//
// Внешний вид провайдера не изменился: LauncherWindow по-прежнему читает
// results, searchState, error и зовёт execute(index, reveal), поэтому список,
// клавиатура и контекстное меню работают без правок.
//
// Три вещи, которые стоит знать при чтении:
//
// 1. Запрос не попадает в оболочку: команда собирается массивом аргументов,
//    поэтому кавычки, пробелы и $( ) в нём остаются символами. По той же
//    причине вместо `| head -n 15` взят ключ fd --max-results — он не требует
//    оболочки и останавливает обход дерева на пятнадцатом совпадении.
//
// 2. В Ubuntu утилита называется fdfind, в Arch и Fedora — fd. Имя ищется
//    один раз при запуске; если нет ни того ни другого, работаем через find.
//
// 3. У каждого поиска свой номер. Ответ процесса с чужим номером
//    отбрасывается: иначе поздний ответ предыдущего запроса перетирал бы
//    свежие результаты.
Item {
    id: root

    property bool active: false
    property string query: ""

    // Папки для быстрых фильтров. Показываются только существующие: чип для
    // несуществующей папки молча ничего не находил бы.
    property var searchDirs: [
        {
            "label": qsTr("Downloads"),
            "path": Paths.homeDir + "/Downloads"
        },
        {
            "label": qsTr("Documents"),
            "path": Paths.homeDir + "/Documents"
        },
        {
            "label": qsTr("Pictures"),
            "path": Paths.homeDir + "/Pictures"
        },
        {
            "label": qsTr("Home"),
            "path": Paths.homeDir
        }
    ]
    property var availableDirs: []
    property string currentSearchDir: Paths.homeDir + "/Downloads"
    property int maxResults: 15
    property int debounceMs: 300

    // loading | ready | empty | unavailable — панель результатов читает это.
    property string searchState: "ready"
    property var error: null
    property var results: []

    property string finderPath: ""
    property bool finderIsFd: true
    property int generation: 0
    property int pendingGeneration: -1

    signal activated

    // --- Поиск ---------------------------------------------------------------

    function detectFinder() {
        finderProcess.command = ["sh", "-c", "command -v fd || command -v fdfind || command -v find"];
        finderProcess.running = true;
    }

    // Пути здесь наши, из свойств компонента, а не из ввода пользователя —
    // их можно отдать оболочке.
    function detectDirs() {
        const quoted = root.searchDirs.map(dir => "'" + String(dir.path).replace(/'/g, "'\\''") + "'");
        dirsProcess.command = ["sh", "-c", "for d in " + quoted.join(" ") + "; do [ -d \"$d\" ] && echo \"$d\"; done"];
        dirsProcess.running = true;
    }

    function buildCommand(text, directory) {
        if (root.finderIsFd) {
            return [root.finderPath, "--type", "f", "--ignore-case", "--max-results", String(root.maxResults),
                    "--", text, directory];
        }

        // find не умеет ограничивать число результатов, поэтому ограничиваем
        // глубину, а лишнее отрезаем при разборе вывода.
        return [root.finderPath, directory, "-maxdepth", "6", "-type", "f", "-iname", "*" + text + "*"];
    }

    function stopSearch() {
        if (searchProcess.running)
            searchProcess.running = false;
    }

    function runSearch() {
        const text = String(root.query).trim();
        if (!root.active || text.length === 0) {
            root.stopSearch();
            root.results = [];
            root.searchState = "ready";
            return;
        }

        if (root.finderPath === "") {
            root.searchState = "unavailable";
            return;
        }

        root.stopSearch();
        root.generation += 1;
        root.pendingGeneration = root.generation;
        root.searchState = "loading";
        root.error = null;
        searchProcess.command = root.buildCommand(text, root.currentSearchDir);
        searchProcess.running = true;
    }

    function applyOutput(text, answeredGeneration) {
        if (answeredGeneration !== root.generation)
            return;

        const lines = String(text || "").split("\n");
        const found = [];
        for (let i = 0; i < lines.length && found.length < root.maxResults; ++i) {
            const path = lines[i].trim();
            if (path.length === 0)
                continue;

            const slash = path.lastIndexOf("/");
            const name = slash >= 0 ? path.slice(slash + 1) : path;
            const parent = slash >= 0 ? path.slice(0, slash) : "";
            const dot = name.lastIndexOf(".");
            const extension = dot > 0 ? name.slice(dot + 1) : "";

            found.push({
                "provider": "files",
                "id": path,
                "title": name,
                "subtitle": extension === "" ? root.compactPath(parent) : extension.toUpperCase() + " · "
                            + root.compactPath(parent),
                "icon": "description",
                "actions": ["copy", "open"],
                "path": path,
                "location": root.compactPath(parent)
            });
        }

        root.results = found;
        root.searchState = found.length === 0 ? "empty" : "ready";
    }

    function compactPath(path) {
        const home = String(Paths.homeDir).replace(/\/+$/, "");
        return path === home || path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    function setSearchDir(path) {
        if (!path || path === root.currentSearchDir)
            return;
        root.currentSearchDir = path;
        // Папка сменилась — тот же запрос ищем заново.
        debounceTimer.restart();
    }

    // --- Действия ------------------------------------------------------------

    // Буфер обмена Wayland хранит типизированные данные. text/uri-list
    // означает «здесь файл»: файловый менеджер вставит сам файл, почтовый
    // клиент приложит его к письму.
    //
    // Путь кодируется посегментно, чтобы уцелели слэши, а пробелы, кириллица
    // и решётки в именах не разорвали адрес.
    function fileUri(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
    }

    // reveal приходит по Ctrl+Enter и из контекстного меню; обычный Enter
    // теперь копирует файл, потому что ради этого режим и переделан.
    function execute(index, reveal) {
        const entry = root.results[index];
        if (!entry)
            return false;

        if (reveal)
            actionProcess.command = [Paths.stableKey, "file", "reveal", "--", entry.path];
        else
            actionProcess.command = ["wl-copy", "--type", "text/uri-list", root.fileUri(entry.path)];

        actionProcess.running = true;
        root.activated();
        return true;
    }

    function openEntry(index) {
        const entry = root.results[index];
        if (!entry)
            return false;
        actionProcess.command = [Paths.stableKey, "file", "open", "--", entry.path];
        actionProcess.running = true;
        root.activated();
        return true;
    }

    // --- Жизненный цикл ------------------------------------------------------

    Component.onCompleted: {
        root.detectFinder();
        root.detectDirs();
    }

    onQueryChanged: debounceTimer.restart()
    onActiveChanged: {
        if (!root.active) {
            root.stopSearch();
            debounceTimer.stop();
            root.results = [];
            root.searchState = "ready";
        }
    }
    Component.onDestruction: root.stopSearch()

    // Поиск запускается, когда пользователь перестал печатать: fd вызывается
    // один раз на слово, а не один раз на букву.
    Timer {
        id: debounceTimer

        interval: root.debounceMs
        onTriggered: root.runSearch()
    }

    Process {
        id: finderProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const path = String(text || "").trim().split("\n")[0] || "";
                root.finderPath = path;
                root.finderIsFd = path.endsWith("/fd") || path.endsWith("/fdfind");
                if (path === "")
                    root.searchState = "unavailable";
                else if (String(root.query).trim().length > 0)
                    debounceTimer.restart();
            }
        }
    }

    Process {
        id: dirsProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const existing = String(text || "").split("\n").map(line => line.trim()).filter(line => line.length > 0);
                root.availableDirs = root.searchDirs.filter(dir => existing.indexOf(String(dir.path)) >= 0);
                if (root.availableDirs.length > 0 && existing.indexOf(root.currentSearchDir) < 0)
                    root.currentSearchDir = root.availableDirs[0].path;
            }
        }
    }

    Process {
        id: searchProcess

        // Номер запоминается на старте: к приходу ответа generation может
        // быть уже другим.
        property int answering: root.pendingGeneration

        stdout: StdioCollector {
            onStreamFinished: root.applyOutput(text, searchProcess.answering)
        }

        onExited: exitCode => {
            if (root.searchState === "loading")
                root.searchState = root.results.length === 0 ? "empty" : "ready";
            // У fd код 1 означает «ничего не найдено», это не ошибка.
            if (exitCode > 1)
                root.error = {
                    "message": qsTr("Search failed (code %1)").arg(exitCode)
                };
        }
    }

    Process {
        id: actionProcess

        onExited: exitCode => {
            if (exitCode !== 0)
                root.error = {
                    "message": qsTr("Could not complete the action")
                };
        }
    }
}

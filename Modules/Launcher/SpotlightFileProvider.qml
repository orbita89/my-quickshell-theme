import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services

// Режим «Файлы» в Spotlight: папки-вкладки, обзор папки и поиск в ней.
//
// ЛОКАЛЬНАЯ ПРАВКА (вторая версия). Было: одна папка, поиск fd по запросу,
// при пустом запросе — пусто. Стало:
//
//  * пустой запрос — содержимое текущей папки (подпапки и файлы), с
//    сортировкой из настроек: сначала новые или по имени;
//  * запрос — поиск внутри текущей папки (вглубь), с той же сортировкой;
//  * по папкам ходят как в файловом менеджере: Enter или → на папке —
//    зайти внутрь, ← — на уровень выше (не выше выбранной вкладки).
//    Стрелки ←/→ работают при пустой строке поиска, иначе двигают курсор
//    (LauncherWindow.qml);
//  * вкладки, скрытые файлы и сортировка — в настройках
//    (UiPreferences.spotlightFile*: Центр управления → Общие → Spotlight).
//
// LauncherWindow и SpotlightResultsPanel читают results, searchState, error,
// availableDirs, currentSearchDir, browseDir и зовут execute(index, reveal),
// setSearchDir(path), enterSelected(index), goUp().
//
// Безопасность: запрос пользователя не попадает в текст команды. Где нужна
// оболочка (fd | stat), запрос и папка передаются ей позиционными
// аргументами "$1" "$2" — кавычки и $( ) в них остаются символами.
//
// Устаревшие ответы: у каждого запуска свой номер (generation), ответ с
// чужим номером отбрасывается.
Item {
    id: root

    property bool active: false
    property string query: ""

    // Вкладки: существующие папки из настроек, с подписями.
    property var availableDirs: []
    // Выбранная вкладка и текущая папка внутри неё.
    property string currentSearchDir: ""
    property string browseDir: ""
    readonly property bool browsingSubfolder: root.browseDir !== "" && root.browseDir !== root.currentSearchDir
    // Путь от вкладки до текущей папки — для подсказки в шапке.
    readonly property string browseLabel: root.browsingSubfolder ? root.labelFor(root.currentSearchDir) + " / "
                                                                   + root.browseDir.slice(
                                                                       root.currentSearchDir.length + 1).split(
                                                                       "/").join(" / ") : ""

    property int maxResults: 50
    // Сколько совпадений fd отдаёт до сортировки: из них берутся maxResults.
    property int searchCandidates: 400
    property int debounceMs: 250

    // loading | ready | empty | unavailable — панель результатов читает это.
    property string searchState: "ready"
    property var error: null
    property var results: []

    property string finderPath: ""
    property bool finderIsFd: true
    property int generation: 0
    property int pendingGeneration: -1

    signal activated

    // --- Подписи и типы ------------------------------------------------------

    function labelFor(path) {
        return UiPreferences.spotlightFileDirLabel(path);
    }

    // Тип по расширению — только чтобы показать подходящий значок.
    function mimeFor(name) {
        const dot = name.lastIndexOf(".");
        const extension = dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
        const types = {
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "webp": "image/webp",
            "svg": "image/svg+xml",
            "pdf": "application/pdf",
            "zip": "application/zip",
            "gz": "application/gzip",
            "tar": "application/x-tar",
            "mp4": "video/mp4",
            "mkv": "video/x-matroska",
            "webm": "video/webm",
            "mp3": "audio/mpeg",
            "ogg": "audio/ogg",
            "flac": "audio/flac",
            "txt": "text/plain",
            "md": "text/markdown",
            "json": "application/json",
            "html": "text/html",
            "csv": "text/csv",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "deb": "application/vnd.debian.binary-package",
            "sh": "application/x-shellscript"
        };
        return types[extension] || "";
    }

    function compactPath(path) {
        const home = String(Paths.homeDir).replace(/\/+$/, "");
        return path === home || path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    // --- Команды -------------------------------------------------------------

    function detectFinder() {
        finderProcess.command = ["sh", "-c", "command -v fd || command -v fdfind || command -v find"];
        finderProcess.running = true;
    }

    // Пути здесь из настроек, не из ввода, но всё равно передаются аргументами.
    function detectDirs() {
        const dirs = UiPreferences.spotlightFileDirs;
        dirsProcess.command = ["sh", "-c", "for d in \"$@\"; do [ -d \"$d\" ] && printf '%s\\n' \"$d\"; done", "sh"].concat(
                    dirs);
        dirsProcess.running = true;
    }

    // Содержимое одной папки: «тип\tвремя изменения\tпуть».
    function listCommand(directory) {
        const hidden = UiPreferences.spotlightFileShowHidden ? [] : ["-not", "-name", ".*"];
        return ["find", directory, "-mindepth", "1", "-maxdepth", "1"].concat(hidden, ["-printf",
                                                                                     "%y\t%T@\t%p\n"]);
    }

    // Поиск вглубь. fd не умеет печатать время, поэтому найденное уходит в
    // stat; запрос и папка — позиционные аргументы оболочки.
    function searchCommand(text, directory) {
        if (root.finderIsFd) {
            const hidden = UiPreferences.spotlightFileShowHidden ? " --hidden" : "";
            return ["sh", "-c", "\"$0\" --ignore-case" + hidden + " --max-results " + root.searchCandidates
                    + " --print0 -- \"$1\" \"$2\" | LC_ALL=C xargs -0 -r stat --printf '%F\\t%Y\\t%n\\n'",
                    root.finderPath, text, directory];
        }
        const hidden = UiPreferences.spotlightFileShowHidden ? [] : ["-not", "-path", "*/.*"];
        return ["find", directory, "-mindepth", "1", "-maxdepth", "6"].concat(hidden, ["-iname", "*" + text + "*",
                                                                                     "-printf",
                                                                                     "%y\t%T@\t%p\n"]);
    }

    function stopSearch() {
        if (searchProcess.running)
            searchProcess.running = false;
    }

    function run() {
        if (!root.active) {
            root.stopSearch();
            root.results = [];
            root.searchState = "ready";
            return;
        }
        if (root.browseDir === "")
            return;

        const text = String(root.query).trim();
        if (text.length > 0 && root.finderPath === "") {
            root.searchState = "unavailable";
            return;
        }

        root.stopSearch();
        root.generation += 1;
        root.pendingGeneration = root.generation;
        root.searchState = "loading";
        root.error = null;
        searchProcess.command = text.length > 0 ? root.searchCommand(text, root.browseDir) : root.listCommand(
                                                      root.browseDir);
        searchProcess.running = true;
    }

    function applyOutput(text, answeredGeneration) {
        if (answeredGeneration !== root.generation)
            return;

        const entries = [];
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const parts = lines[i].split("\t");
            if (parts.length < 3)
                continue;
            // fd печатает папки со слэшем на конце — убираем, иначе имя пустое.
            const path = parts.slice(2).join("\t").replace(/\/+$/, "");
            if (path === "" || path === root.browseDir)
                continue;
            // find: d / f; stat (LC_ALL=C): «directory» / «regular file» / «regular empty file».
            const isDir = parts[0] === "d" || parts[0] === "directory";
            entries.push({
                             "path": path,
                             "isDir": isDir,
                             "mtime": Number(parts[1]) || 0
                         });
        }

        if (UiPreferences.spotlightFileSort === "name") {
            entries.sort((a, b) => (Number(b.isDir) - Number(a.isDir)) || a.path.slice(a.path.lastIndexOf("/") + 1)
                         .localeCompare(b.path.slice(b.path.lastIndexOf("/") + 1), undefined, {
                                            "sensitivity": "base",
                                            "numeric": true
                                        }));
        } else {
            entries.sort((a, b) => b.mtime - a.mtime);
        }

        root.results = entries.slice(0, root.maxResults).map(entry => {
                                                                  const slash = entry.path.lastIndexOf("/");
                                                                  const name = entry.path.slice(slash + 1);
                                                                  const parent = entry.path.slice(0, slash);
                                                                  const dot = name.lastIndexOf(".");
                                                                  const extension = !entry.isDir && dot > 0
                                                                  ? name.slice(dot + 1).toUpperCase() : "";
                                                                  const when = Qt.formatDateTime(new Date(
                                                                                                     entry.mtime
                                                                                                     * 1000),
                                                                                                 "dd.MM.yyyy HH:mm");
                                                                  return {
                                                                      "provider": "files",
                                                                      "id": entry.path,
                                                                      "title": name,
                                                                      "subtitle": (entry.isDir ? qsTr("Folder") :
                                                                                                 extension)
                                                                      + (extension !== "" || entry.isDir ? " · " : "")
                                                                      + when + " · " + root.compactPath(parent),
                                                                      "icon": entry.isDir ? "folder" : "description",
                                                                      "actions": entry.isDir ? ["open"] : ["copy",
                                                                                                           "open"],
                                                                      "path": entry.path,
                                                                      "location": root.compactPath(parent),
                                                                      "isDir": entry.isDir,
                                                                      "file": {
                                                                          "isDirectory": entry.isDir,
                                                                          "mimeType": entry.isDir ? "inode/directory" :
                                                                                                    root.mimeFor(name)
                                                                      }
                                                                  };
                                                              });
        root.searchState = root.results.length === 0 ? "empty" : "ready";
    }

    // --- Навигация -----------------------------------------------------------

    function setSearchDir(path) {
        if (!path)
            return;
        root.currentSearchDir = path;
        root.browseDir = path;
        debounceTimer.stop();
        root.run();
    }

    function enterDir(path) {
        root.browseDir = path;
        debounceTimer.stop();
        root.run();
    }

    // → и Enter на папке. Возвращает true, если зашли.
    function enterSelected(index) {
        const entry = root.results[index];
        if (!entry || !entry.isDir)
            return false;
        root.enterDir(entry.path);
        return true;
    }

    // ← — на уровень выше, но не выше выбранной вкладки.
    function goUp() {
        if (!root.browsingSubfolder)
            return false;
        root.enterDir(root.browseDir.slice(0, root.browseDir.lastIndexOf("/")));
        return true;
    }

    // --- Действия ------------------------------------------------------------

    // Буфер обмена Wayland хранит типизированные данные: text/uri-list — «это
    // файл», файловый менеджер вставит сам файл. Путь кодируется посегментно.
    function fileUri(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
    }

    // Enter: папка — зайти внутрь, файл — скопировать как файл.
    // Ctrl+Enter и контекстное меню (reveal) — показать в файловом менеджере.
    function execute(index, reveal) {
        const entry = root.results[index];
        if (!entry)
            return false;

        if (!reveal && entry.isDir)
            return root.enterSelected(index);

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
        if (root.active) {
            // Каждый раз открываемся в корне выбранной вкладки.
            root.browseDir = root.currentSearchDir;
            root.run();
        } else {
            root.stopSearch();
            debounceTimer.stop();
            root.results = [];
            root.searchState = "ready";
        }
    }
    Component.onDestruction: root.stopSearch()

    Connections {
        target: UiPreferences

        function onSpotlightFileDirsChanged() {
            root.detectDirs();
        }

        function onSpotlightFileShowHiddenChanged() {
            root.run();
        }

        function onSpotlightFileSortChanged() {
            root.run();
        }
    }

    // Поиск запускается, когда пользователь перестал печатать.
    Timer {
        id: debounceTimer

        interval: root.debounceMs
        onTriggered: root.run()
    }

    Process {
        id: finderProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const path = String(text || "").trim().split("\n")[0] || "";
                root.finderPath = path;
                root.finderIsFd = path.endsWith("/fd") || path.endsWith("/fdfind");
                if (String(root.query).trim().length > 0)
                    debounceTimer.restart();
            }
        }
    }

    Process {
        id: dirsProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const existing = String(text || "").split("\n").map(line => line.trim()).filter(line => line.length
                                                                                                > 0);
                root.availableDirs = existing.map(path => ({
                                                               "label": root.labelFor(path),
                                                               "path": path
                                                           }));
                if (existing.length === 0) {
                    root.currentSearchDir = "";
                    root.browseDir = "";
                    root.results = [];
                    root.searchState = "empty";
                } else if (existing.indexOf(root.currentSearchDir) < 0) {
                    root.setSearchDir(existing[0]);
                }
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
            // У fd код 1 — «ничего не найдено»; find с 1 — недоступные подпапки.
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

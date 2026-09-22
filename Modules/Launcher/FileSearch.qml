import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Common
import qs.Components
import qs.Widgets.common

// МОЙ МОДУЛЬ: лёгкий поиск файлов по выбранным папкам.
//
// Отличается от SpotlightFileProvider тем, что не ходит в key-cli и не строит
// общий индекс: один вызов fd по одной папке, не больше пятнадцати строк.
// Найденный файл кладётся в буфер обмена как файл, а не как строка пути —
// то есть его можно вставить в файловый менеджер или приложить к письму.
//
// Три вещи, на которые стоит обратить внимание при чтении:
//
// 1. Запрос никогда не попадает в оболочку. Команда собирается массивом
//    аргументов, поэтому кавычки, пробелы, точка с запятой и $( ) в запросе
//    остаются обычными символами. Из-за этого же вместо `| head -n 15`
//    используется собственный ключ fd --max-results: он и безопаснее, и
//    быстрее — поиск останавливается сам, не дочитывая дерево до конца.
//
// 2. Процессы и таймеры объявлены статически и переиспользуются. Ничего не
//    создаётся через createObject, так что повторные поиски не копят объекты.
//
// 3. У каждого запуска есть номер. Ответ старого процесса, пришедший после
//    того, как пользователь дописал букву, отбрасывается по несовпадению
//    номера — иначе в списке мелькали бы результаты предыдущего запроса.
Item {
    id: root

    // --- Настройки -----------------------------------------------------------
    // Папки для быстрых фильтров. Первая выбрана по умолчанию.
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
            "label": qsTr("Projects"),
            "path": Paths.homeDir + "/Projects"
        },
        {
            "label": qsTr("Config"),
            "path": Paths.xdgConfigHome
        }
    ]

    // Из списка показываются только существующие папки: чип для
    // несуществующей молча не находил бы ничего, и было бы непонятно, почему.
    property var availableDirs: []
    property string currentSearchDir: searchDirs.length > 0 ? searchDirs[0].path : Paths.homeDir
    property int maxResults: 15
    property int debounceMs: 300
    // Строка запроса наружу: Spotlight сможет вести поиск своим полем ввода,
    // не открывая внутренности компонента.
    property alias query: queryField.text

    // --- Состояние -----------------------------------------------------------
    property var results: []
    property int currentIndex: 0
    property bool searching: false
    property string errorText: ""
    // Имя найденной утилиты: fd, fdfind или find. Пустое, пока идёт поиск.
    property string finderPath: ""
    property bool finderIsFd: true
    // Номер запуска: ответы с чужим номером игнорируются.
    property int generation: 0
    property int pendingGeneration: -1

    signal searchCompleted

    // --- Поиск ---------------------------------------------------------------

    // В Ubuntu утилита называется fdfind (имя fd занято другим пакетом), в
    // Arch и Fedora — fd. Ищем один раз при создании; если нет ни того ни
    // другого, работаем через find, он есть везде.
    function detectFinder() {
        finderProcess.command = ["sh", "-c", "command -v fd || command -v fdfind || command -v find"];
        finderProcess.running = true;
    }

    // Одна проверка на все папки сразу. Пути здесь наши, из настроек
    // компонента, а не из ввода пользователя — оболочке их отдать безопасно.
    function detectDirs() {
        const quoted = root.searchDirs.map(dir => "'" + String(dir.path).replace(/'/g, "'\\''") + "'");
        dirsProcess.command = ["sh", "-c", "for d in " + quoted.join(" ") + "; do [ -d \"$d\" ] && echo \"$d\"; done"];
        dirsProcess.running = true;
    }

    function buildCommand(query, directory) {
        if (root.finderIsFd) {
            // --max-results заставляет fd остановиться на пятнадцатом
            // совпадении, а не искать всё и обрезать вывод.
            return [root.finderPath, "--type", "f", "--ignore-case", "--max-results", String(root.maxResults),
                    "--", query, directory];
        }

        // find не умеет ограничивать число результатов, поэтому глубина
        // ограничивается вручную, а лишнее отрезается уже при разборе вывода.
        return [root.finderPath, directory, "-maxdepth", "6", "-type", "f", "-iname", "*" + query + "*"];
    }

    function search() {
        const query = String(queryField.text).trim();
        if (query.length === 0 || root.finderPath === "") {
            root.stopSearch();
            root.results = [];
            root.errorText = "";
            return;
        }

        // Предыдущий поиск больше не нужен: убиваем, чтобы не тратил диск.
        root.stopSearch();

        root.generation += 1;
        root.pendingGeneration = root.generation;
        root.searching = true;
        root.errorText = "";
        searchProcess.command = root.buildCommand(query, root.currentSearchDir);
        searchProcess.running = true;
    }

    function stopSearch() {
        if (searchProcess.running)
            searchProcess.running = false;
        root.searching = false;
    }

    function applyOutput(text, answeredGeneration) {
        // Ответ устарел: пользователь успел изменить запрос или папку.
        if (answeredGeneration !== root.generation)
            return;

        const lines = String(text || "").split("\n");
        const found = [];
        for (let i = 0; i < lines.length && found.length < root.maxResults; ++i) {
            const path = lines[i].trim();
            if (path.length === 0)
                continue;
            const slash = path.lastIndexOf("/");
            found.push({
                "path": path,
                "name": slash >= 0 ? path.slice(slash + 1) : path,
                "directory": slash >= 0 ? root.compactPath(path.slice(0, slash)) : ""
            });
        }

        root.results = found;
        root.currentIndex = 0;
        root.searching = false;
    }

    function compactPath(path) {
        const home = String(Paths.homeDir).replace(/\/+$/, "");
        return path === home || path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    // --- Копирование ---------------------------------------------------------

    // Буфер обмена Wayland хранит не строку, а типизированные данные. Тип
    // text/uri-list означает «здесь файл»: файловый менеджер вставит сам файл,
    // почтовый клиент приложит его к письму.
    //
    // Путь превращается в URI по правилам RFC 3986: каждый сегмент кодируется
    // отдельно, чтобы уцелели слэши, а пробелы, кириллица, решётки и знаки
    // вопроса в именах не разорвали адрес.
    function fileUri(path) {
        const segments = String(path).split("/").map(encodeURIComponent);
        return "file://" + segments.join("/");
    }

    function copyFile(path) {
        if (!path)
            return;
        // Аргументы передаются массивом, поэтому кавычки вокруг пути не нужны
        // и не помогли бы: оболочка в этой цепочке вообще не участвует.
        copyProcess.command = ["wl-copy", "--type", "text/uri-list", root.fileUri(path)];
        copyProcess.running = true;
        root.searchCompleted();
    }

    function activateCurrent() {
        const entry = root.results[root.currentIndex];
        if (entry)
            root.copyFile(entry.path);
    }

    function moveSelection(delta) {
        if (root.results.length === 0)
            return;
        const next = root.currentIndex + delta;
        root.currentIndex = Math.max(0, Math.min(root.results.length - 1, next));
        resultsView.positionViewAtIndex(root.currentIndex, ListView.Contain);
    }

    Component.onCompleted: {
        root.detectFinder();
        root.detectDirs();
    }

    // Поиск запускается, когда пользователь перестал печатать. Перезапуск
    // таймера на каждую букву означает, что fd вызывается один раз на слово,
    // а не один раз на символ.
    Timer {
        id: debounceTimer

        interval: root.debounceMs
        onTriggered: root.search()
    }

    Process {
        id: finderProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const path = String(text || "").trim().split("\n")[0] || "";
                root.finderPath = path;
                root.finderIsFd = path.endsWith("/fd") || path.endsWith("/fdfind");
                if (path === "")
                    root.errorText = qsTr("Neither fd nor find was found");
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

        // Номер запоминается на момент старта: к приходу ответа значение
        // generation может быть уже другим.
        property int answering: root.pendingGeneration

        stdout: StdioCollector {
            onStreamFinished: root.applyOutput(text, searchProcess.answering)
        }

        onExited: exitCode => {
            root.searching = false;
            // У fd код 1 означает «ничего не найдено», это не ошибка.
            if (exitCode > 1)
                root.errorText = qsTr("Search failed (code %1)").arg(exitCode);
        }
    }

    Process {
        id: copyProcess

        onExited: exitCode => {
            if (exitCode !== 0)
                root.errorText = qsTr("Could not copy the file to the clipboard");
        }
    }

    // --- Интерфейс -----------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        OutlinedTextField {
            id: queryField

            Layout.fillWidth: true
            labelText: qsTr("File name")
            placeholderText: qsTr("part of the name")
            onTextChanged: debounceTimer.restart()
            onAccepted: root.activateCurrent()

            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)
            Keys.onEscapePressed: root.searchCompleted()
        }

        // Быстрые фильтры: ведут себя как переключатели, выбран ровно один.
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.availableDirs

                delegate: Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool selected: root.currentSearchDir === chip.modelData.path

                    implicitWidth: chipLabel.implicitWidth + 22
                    implicitHeight: 28
                    radius: Appearance.rounding.full
                    color: chip.selected ? Appearance.colors.colPrimary : (chipHover.containsMouse ?
                                                                               Appearance.colors.colLayer2 :
                                                                               Appearance.colors.colLayer1)

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Text {
                        id: chipLabel

                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        font.weight: chip.selected ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        id: chipHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentSearchDir = chip.modelData.path;
                            // Папка сменилась — ищем заново по тому же запросу.
                            debounceTimer.restart();
                        }
                    }
                }
            }
        }

        Text {
            visible: root.errorText.length > 0 || root.searching
                     || (root.results.length === 0 && queryField.text.trim().length > 0)
            Layout.fillWidth: true
            text: root.errorText.length > 0 ? root.errorText : root.searching ? qsTr("Searching…") : qsTr(
                                                                                    "Nothing found")
            color: root.errorText.length > 0 ? Appearance.colors.colError : Appearance.colors.colSubtext
            font.family: Fonts.ui
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        ListView {
            id: resultsView

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.results
            spacing: 2
            // Список заведомо короткий, но признак лишним не будет: так
            // ListView не создаёт делегаты за пределами видимой области.
            cacheBuffer: 0

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                width: resultsView.width
                height: 46
                radius: Appearance.rounding.normal
                color: row.index === root.currentIndex ? Appearance.colors.colPrimaryContainer : (rowHover.containsMouse ?
                                                                                                      Appearance.colors.colLayer1 :
                                                                                                      "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    MaterialSymbol {
                        text: "description"
                        iconSize: 20
                        color: row.index === root.currentIndex ? Appearance.colors.colOnPrimaryContainer :
                                                                 Appearance.colors.colSubtext
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: row.index === root.currentIndex ? Appearance.colors.colOnPrimaryContainer :
                                                                     Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.directory
                            color: Appearance.colors.colSubtext
                            font.family: Fonts.ui
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                        }
                    }
                }

                MouseArea {
                    id: rowHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.currentIndex = row.index
                    onClicked: root.copyFile(row.modelData.path)
                }
            }
        }
    }
}

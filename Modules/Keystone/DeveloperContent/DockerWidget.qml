pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Components
import qs.Widgets.common

// Вкладка «Developer» главного меню (Dashboard): контейнеры Docker,
// сгруппированные по compose-проектам.
//
// Данные — `docker ps -a` с JSON-форматом и метками Compose
// (com.docker.compose.project / .service), асинхронно через Quickshell
// Process (без shell). Группировка по полю project на стороне кода:
//   - контейнеры одного compose-проекта идут под заголовок-группу;
//   - контейнеры без метки проекта — в группу [Standalone].
//
// Управление (start/stop/restart) привязано к id контейнера и работает
// одинаково в группах и в Standalone.
//
// Стиль намеренно плоский: без рамок/карточек у строк, одна линия на
// контейнер (elide вместо переноса), высота делегата — константа по типу
// строки (groupRowHeight / containerRowHeight), а не implicitHeight
// вложенного RowLayout: ListView получает высоту сразу при создании
// делегата, поэтому строки не перекрывают друг друга, пока Layout
// досчитывает свои implicit-размеры.
//
// Сворачивание группы НЕ трогает модель: контейнеры всегда в rowsModel,
// а скрытие — это анимация высоты делегата к нулю (clip режет содержимое).
// Так при «hide» не удаляются и не пересоздаются делегаты, а ListView
// просто плавно подтягивает строки ниже.
//
// Опрос идёт, только пока вкладка реально видна: таймер, процесс и сокеты
// не держатся, когда хаб закрыт или активна другая вкладка.
//
// Состояния демона (daemonState): '' (ок), 'error' (демон недоступен),
// 'missing' (нет docker CLI в PATH), 'permission' (нет прав на сокет).
// Различение — по stderr docker-клиента; в Quickshell 0.3.1 у Process нет
// failedToStart, поэтому «нет CLI» распознаётся по never-started (тот же
// идиом, что в NetworkManagerExtras).
Item {
    id: root

    // Gating опроса: видимость родителя + своя видимость.
    readonly property bool polling: parent.visible && root.visible

    // '' | 'error' | 'permission' | 'missing'
    property string daemonState: ""
    // Был ли хотя бы один ответ docker (до первого — не показывать «пусто»).
    property bool everQueried: false
    // Идёт ли start/stop/restart: на это время опрос и новые действия молчат.
    property bool actionRunning: false
    // Запускался ли docker CLI за время жизни виджета.
    property bool _dockerStarted: false
    // Буфер разобранных строк текущей ps-сессии (плоский массив контейнеров).
    property var _psRows: []
    // Свёрнутые compose-проекты (projectKey -> true). По умолчанию всё открыто.
    property var collapsedProjects: ({})
    // Сколько контейнеров запущено (пересчитывается в applyPsRows).
    property int runningTotal: 0

    // Геометрия строк списка. Высота делегата берётся отсюда, а не из
    // implicitHeight содержимого — см. комментарий в шапке файла.
    readonly property int groupRowHeight: 30
    readonly property int groupContentHeight: 20
    readonly property int containerRowHeight: 34
    readonly property int containerContentHeight: 28

    // Формат вывода: id, имя, состояние, человекочитаемый статус и обе
    // compose-метки. Кавычки внутри {{ }} — часть Go-шаблона docker; shell
    // не участвует (Process запускает бинарь напрямую, список argv).
    readonly property string psFormat: '{"id":"{{.ID}}","name":"{{.Names}}","state":"{{.State}}","status":"{{.Status}}","project":"{{.Label \"com.docker.compose.project\"}}","service":"{{.Label \"com.docker.compose.service\"}}"}'

    // Плоская модель строк списка: элементы двух типов (kind: 'group' |
    // 'container'). Порядок: проекты по алфавиту, [Standalone] последней.
    ListModel {
        id: rowsModel
    }

    function isCollapsed(projectKey) {
        return collapsedProjects[projectKey] === true;
    }

    function toggleCollapsed(projectKey) {
        const next = Object.assign({}, collapsedProjects);
        if (isCollapsed(projectKey))
            delete next[projectKey];
        else
            next[projectKey] = true;
        collapsedProjects = next;
        // Модель не трогаем: делегаты сами перечитают isCollapsed() и уедут
        // в нулевую высоту. Пересбор модели здесь как раз и ломал раскладку.
    }

    // Имя для строки: compose-имена вида «проект-сервис-1» уже содержат
    // сервис — дублировать его («nginx · nginx») не нужно.
    function displayName(name, service) {
        if (service.length > 0 && name.toLowerCase().indexOf(service.toLowerCase()) === -1)
            return name + " · " + service;
        return name;
    }

    function statusColor(state) {
        switch (state) {
        case "running":
            return Appearance.colors.colPrimary;
        case "paused":
            return Appearance.colors.colTertiary;
        case "exited":
        case "created":
        case "dead":
            return Appearance.colors.colOutline;
        default:
            return Appearance.colors.colError;
        }
    }

    // Классификация неудачи по stderr docker-клиента.
    function classifyFailure(stderrText, exitCode) {
        const text = String(stderrText).toLowerCase();
        if (text.includes("permission denied"))
            return "permission";
        if (text.includes("cannot connect") || text.includes("daemon running") || text.includes(
                    "connection refused") || text.includes("is not running") || text.includes(
                    "no such file"))
            return "error";
        return exitCode === 0 ? "" : "error";
    }

    // start|stop|restart|rm <id>. Строка уходит в busy до onExited, затем
    // список переспрашивается сразу.
    function runAction(verb, containerId, row) {
        if (root.actionRunning || root.daemonState !== "")
            return;
        row.busy = true;
        actionProcess.targetRow = row;
        actionProcess.command = ["docker", verb, containerId];
        root.actionRunning = true;
        actionProcess.running = true;
    }

    function requestRefresh() {
        if (!psProcess.running && !root.actionRunning)
            psProcess.running = true;
    }

    // Дерево проектов из плоского массива контейнеров (по спецификации):
    // { projects: [ { name, containers: [ {id, service, name, state, status} ] } ] }.
    // [Standalone] — контейнеры без compose-метки, всегда последней группой.
    function buildProjectsTree(rows) {
        const byProject = new Map();
        for (const r of rows) {
            const key = r.project.length > 0 ? r.project : "__standalone__";
            if (!byProject.has(key))
                byProject.set(key, []);
            byProject.get(key).push({
                "id": r.id,
                "service": r.service,
                "name": r.name,
                "state": r.state,
                "status": r.status
            });
        }
        const names = Array.from(byProject.keys()).filter(k => k !== "__standalone__");
        names.sort((a, b) => a.localeCompare(b));
        if (byProject.has("__standalone__"))
            names.push("__standalone__");
        return names.map(key => ({
                    "key": key,
                    "name": key === "__standalone__" ? qsTr("Standalone") : key,
                    "containers": byProject.get(key)
                }));
    }

    // Отличается ли содержимое строки (при равных ключах kind равны всегда:
    // префиксы 'group:' и 'c:' не пересекаются).
    function rowsDiffer(o, d) {
        return o.name !== d.name || o.id !== d.id || o.service !== d.service || o.state !== d.state
                || o.status !== d.status || o.count !== d.count || o.running !== d.running;
    }

    // Дерево -> плоские строки ListView + синхронизация модели. Список
    // небольшой: сравнение по ключу/содержанию, пересбор только при реальном
    // изменении — опрос каждые 4 с не дёргает UI.
    function applyPsRows() {
        const desired = [];
        let totalRunning = 0;
        for (const project of root.buildProjectsTree(root._psRows)) {
            const running = project.containers.filter(c => c.state === "running").length;
            totalRunning += running;
            desired.push({
                "kind": "group",
                "key": "group:" + project.key,
                "name": project.name,
                "projectKey": project.key,
                "count": project.containers.length,
                "running": running,
                "id": "",
                "service": "",
                "state": "",
                "status": ""
            });
            // Свёрнутые группы тоже отдают свои контейнеры: скрытие живёт
            // в делегате (высота -> 0), а не в составе модели.
            for (const c of project.containers) {
                desired.push({
                    "kind": "container",
                    "key": "c:" + c.id,
                    "name": c.name,
                    "projectKey": project.key,
                    "count": 0,
                    "running": 0,
                    "id": c.id,
                    "service": c.service,
                    "state": c.state,
                    "status": c.status
                });
            }
        }
        root.runningTotal = totalRunning;

        // Вместо clear()+append() — инкрементальная синхронизация по ключам:
        // удаляются, вставляются и переставляются только реально изменившиеся
        // позиции. Живые строки не теряют делегат, «Up 38->39 minutes»
        // остаётся set() на месте, и опрос раз в 4 с не дёргает UI.
        const desiredKeys = new Set(desired.map(d => d.key));

        // 1) Исчезнувшие строки — снять (справа налево, индексы не съезжают).
        for (let i = rowsModel.count - 1; i >= 0; --i) {
            if (!desiredKeys.has(rowsModel.get(i).key))
                rowsModel.remove(i);
        }

        // 2) Проход по desired: оставить на месте / сдвинуть / вставить.
        for (let target = 0; target < desired.length; ++target) {
            const d = desired[target];
            const current = target < rowsModel.count ? rowsModel.get(target) : undefined;
            if (current && current.key === d.key) {
                if (root.rowsDiffer(current, d))
                    rowsModel.set(target, d);
                continue;
            }
            let source = -1;
            for (let j = target + 1; j < rowsModel.count; ++j) {
                if (rowsModel.get(j).key === d.key) {
                    source = j;
                    break;
                }
            }
            if (source >= 0) {
                rowsModel.move(source, target, 1);
                if (root.rowsDiffer(rowsModel.get(target), d))
                    rowsModel.set(target, d);
            } else if (target < rowsModel.count) {
                rowsModel.insert(target, d);
            } else {
                rowsModel.append(d);
            }
        }

        // 3) Страховка: лишние строки в хвосте (не должно случиться, но
        // держать модель в согласии с desired дешевле, чем ловить фантомы).
        if (rowsModel.count > desired.length)
            rowsModel.remove(desired.length, rowsModel.count - desired.length);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.spacing.small
        anchors.rightMargin: Appearance.spacing.small
        anchors.topMargin: Appearance.spacing.small
        anchors.bottomMargin: Appearance.spacing.small
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            MaterialSymbol {
                text: "apps"
                iconSize: 20
                fill: 1
                color: Appearance.colors.colPrimary
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Docker")
                color: Appearance.colors.colOnLayer1
                font.family: Fonts.ui
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            // Сводка «N running» — только когда демон жив и есть запущенные.
            Row {
                visible: root.daemonState === "" && root.runningTotal > 0
                spacing: Appearance.spacing.xSmall

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: Appearance.colors.colPrimary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.runningTotal + qsTr(" running")
                    color: Appearance.colors.colSubtext
                    font.family: Fonts.ui
                    font.pixelSize: 12
                }
            }

            RippleButton {
                id: refreshButton

                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                containerColor: "transparent"
                stateLayerColor: Appearance.colors.colLayer2Hover
                pressedStateLayerColor: Appearance.colors.colLayer2Active
                rippleColor: Appearance.colors.colOnLayer2
                Accessible.name: qsTr("Refresh")
                onClicked: root.requestRefresh()

                contentItem: MaterialSymbol {
                    text: "refresh"
                    iconSize: 17
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        // Баннер недоступности демона: выключен, нет CLI или нет прав.
        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.daemonState !== ""
            tone: "error"
            message: {
                switch (root.daemonState) {
                case "missing":
                    return qsTr("docker CLI was not found in PATH");
                case "permission":
                    return qsTr("No permission to talk to the Docker daemon") + qsTr(
                                " — add the user to the 'docker' group");
                default:
                    return qsTr("Docker daemon is not reachable");
                }
            }
        }

        // Демон жив, контейнеров нет.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.large
            visible: root.daemonState === "" && root.everQueried && rowsModel.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("No containers")
            color: Appearance.colors.colSubtext
            font.family: Fonts.ui
            font.pixelSize: 13
        }

        StyledListView {
            id: rowsList

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.daemonState === ""
            spacing: 0
            animateAppearance: false
            animateMovement: false
            showVerticalScrollBar: false

            model: rowsModel

            delegate: Item {
                id: rowRoot

                required property int index
                required property string kind
                required property string key
                required property string name
                required property string id
                required property string service
                required property string state
                required property string status
                required property string projectKey
                required property int count
                required property int running

                readonly property bool isGroup: kind === "group"
                // Свёрнутость читается прямо из root: collapsedProjects
                // переприсваивается целиком, поэтому биндинг пересчитывается.
                readonly property bool collapsedNow: root.isCollapsed(projectKey)
                readonly property bool rowHidden: !isGroup && collapsedNow

                width: rowsList.width
                // Высота — константа по типу строки, известна сразу при
                // создании делегата. Скрытая строка схлопывается в 0.
                height: rowHidden ? 0 : (isGroup ? root.groupRowHeight : root.containerRowHeight)
                opacity: rowHidden ? 0 : 1
                // Режет содержимое во время схлопывания и заодно отсекает
                // клики по кнопкам скрытых строк.
                clip: true
                enabled: !rowHidden
                visible: height > 0

                Behavior on height {
                    NumberAnimation {
                        duration: Animations.durations.small
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Animations.curves.standard
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Animations.durations.small
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Animations.curves.standard
                    }
                }

                // ====== Заголовок группы: compose-проект или [Standalone] ======
                RowLayout {
                    id: groupHeader

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.leftMargin: Appearance.spacing.xSmall
                    height: root.groupContentHeight
                    visible: rowRoot.isGroup
                    spacing: Appearance.spacing.xSmall

                    MaterialSymbol {
                        text: "folder"
                        iconSize: 15
                        color: Appearance.colors.colSubtext
                    }

                    Text {
                        text: rowRoot.projectKey === "__standalone__" ? "[" + rowRoot.name + "]" : rowRoot.name
                        color: Appearance.colors.colOnLayer2
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        text: rowRoot.running + "/" + rowRoot.count
                        color: rowRoot.running === rowRoot.count && rowRoot.count > 0 ? Appearance.colors.colPrimary : Appearance
                              .colors.colSubtext
                        font.family: Fonts.ui
                        font.pixelSize: 11
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Чип show/hide группы.
                    Rectangle {
                        width: chipRow.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.06)

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowRoot.collapsedNow ? qsTr("show") : qsTr("hide")
                                color: Appearance.colors.colSubtext
                                font.family: Fonts.ui
                                font.pixelSize: 10
                            }

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowRoot.collapsedNow ? "keyboard_arrow_down" : "keyboard_arrow_up"
                                iconSize: 13
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                // ====== Строка контейнера: без рамок, одна линия ======
                RowLayout {
                    id: containerRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Appearance.spacing.small + 6
                    height: root.containerContentHeight
                    visible: !rowRoot.isGroup
                    spacing: Appearance.spacing.small

                    // Идёт команда по этому контейнеру — вместо кнопок спиннер.
                    property bool busy: false

                    // Контейнер может исчезнуть из ps прямо во время команды:
                    // если делегат умер, освобождаем слот, чтобы
                    // actionRunning не завис навсегда.
                    Component.onDestruction: {
                        if (actionProcess.targetRow === containerRow) {
                            actionProcess.targetRow = null;
                            root.actionRunning = false;
                        }
                    }

                    // Полоска-маркер состояния вместо точки и рамки карточки.
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        width: 3
                        height: 20
                        radius: 1.5
                        color: root.statusColor(rowRoot.state)
                    }

                    Text {
                        Layout.preferredWidth: 172
                        text: root.displayName(rowRoot.name, rowRoot.service)
                        color: rowRoot.state === "running" ? Appearance.colors.colOnLayer3 : Appearance.colors.colSubtext
                        font.family: Fonts.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: rowRoot.status
                        color: Appearance.colors.colSubtext
                        font.family: Fonts.ui
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    // Слот фиксированной ширины: при busy строка не «прыгает»,
                    // кнопки просто меняются на спиннер.
                    Item {
                        Layout.preferredWidth: 28 * 4 + Appearance.spacing.xSmall * 3
                        Layout.preferredHeight: 28

                        RowLayout {
                            id: buttonRow

                            anchors.fill: parent
                            spacing: Appearance.spacing.xSmall
                            visible: !containerRow.busy

                            // Действия привязаны к id контейнера —
                            // работают и в проектах, и в Standalone.
                            ActionButton {
                                iconName: "play_arrow"
                                tooltip: qsTr("Start container")
                                enabled: !containerRow.busy && rowRoot.state !== "running" && rowRoot.state !== "paused"
                                onClicked: root.runAction("start", rowRoot.id, containerRow)
                            }

                            ActionButton {
                                iconName: "stop"
                                tooltip: qsTr("Stop container")
                                enabled: !containerRow.busy && (rowRoot.state === "running" || rowRoot.state === "paused")
                                onClicked: root.runAction("stop", rowRoot.id, containerRow)
                            }

                            ActionButton {
                                iconName: "restart_alt"
                                tooltip: qsTr("Restart container")
                                enabled: !containerRow.busy && rowRoot.state === "running"
                                onClicked: root.runAction("restart", rowRoot.id, containerRow)
                            }

                            // Удаление без -f: docker rm сам откажет running,
                            // поэтому кнопка активна только для остановленных —
                            // случайный клик не снесёт живой контейнер.
                            ActionButton {
                                iconName: "delete"
                                tooltip: qsTr("Delete container")
                                iconColor: Appearance.colors.colError
                                enabled: !containerRow.busy && rowRoot.state !== "running"
                                         && rowRoot.state !== "paused"
                                onClicked: root.runAction("rm", rowRoot.id, containerRow)
                            }
                        }

                        InlineBusyIndicator {
                            anchors.centerIn: parent
                            busy: containerRow.busy
                            spinnerColor: Appearance.colors.colPrimary
                        }
                    }
                }

                // Мыш-area заголовка — поверх всей строки группы (свернуть).
                MouseArea {
                    anchors.fill: parent
                    enabled: rowRoot.isGroup
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleCollapsed(rowRoot.projectKey)
                }
            }
        }
    }

    // Опрос раз в 4 с, только при видимости вкладки; во время действия — пауза.
    Timer {
        id: pollTimer

        interval: 4000
        repeat: true
        running: root.polling && !root.actionRunning
        triggeredOnStart: true
        onTriggered: root.requestRefresh()
    }

    // docker ps -a с compose-метками: строка JSON на контейнер, try/catch.
    Process {
        id: psProcess

        command: ["docker", "ps", "-a", "--format", root.psFormat]

        onStarted: {
            root._dockerStarted = true;
            root._psRows = [];
        }

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                const text = String(line).trim();
                if (text.length === 0)
                    return;

                try {
                    const obj = JSON.parse(text);
                    if (obj && typeof obj.id === "string") {
                        root._psRows.push({
                            "id": String(obj.id),
                            "name": String(obj.name ?? ""),
                            "state": String(obj.state ?? ""),
                            "status": String(obj.status ?? ""),
                            "project": String(obj.project ?? ""),
                            "service": String(obj.service ?? "")
                        });
                    }
                } catch (e) {
                    // битая строка — пропускаем, остальной список валиден
                }
            }
        }

        // waitForEnd по умолчанию true: text() готов к onExited.
        stderr: StdioCollector {
            id: psErrors
        }

        onExited: exitCode => {
            root.everQueried = true;
            root.daemonState = exitCode === 0 ? "" : root.classifyFailure(psErrors.text, exitCode);
            // Успешный прогон — пересобираем группы; при ошибке старый список
            // остаётся под баннером, чтобы не мигать пустотой.
            if (exitCode === 0)
                root.applyPsRows();
        }

        // Ни одного успешного старта — docker CLI отсутствует в PATH.
        onRunningChanged: {
            if (!running && !root._dockerStarted)
                root.daemonState = "missing";
        }
    }

    // start|stop|restart|rm по id. По завершении — немедленный переспрос списка.
    Process {
        id: actionProcess

        property var targetRow: null

        command: ["docker", "true"]

        stderr: StdioCollector {
            id: actionErrors
        }

        onExited: exitCode => {
            root.actionRunning = false;
            if (targetRow) {
                targetRow.busy = false;
                targetRow = null;
            }
            if (exitCode !== 0)
                root.daemonState = root.classifyFailure(actionErrors.text, exitCode);
            root.requestRefresh();
        }

        onRunningChanged: {
            if (!running && !root._dockerStarted) {
                root.actionRunning = false;
                if (targetRow) {
                    targetRow.busy = false;
                    targetRow = null;
                }
                root.daemonState = "missing";
            }
        }
    }

    // Кнопка действия контейнера: круглый слот 28×28 с иконкой.
    component ActionButton: RippleButton {
        id: actionButton

        required property string iconName
        required property string tooltip
        property color iconColor: Appearance.colors.colOnLayer2

        implicitWidth: 28
        implicitHeight: 28
        buttonRadius: Appearance.rounding.full
        containerColor: "transparent"
        stateLayerColor: Appearance.colors.colLayer2Hover
        pressedStateLayerColor: Appearance.colors.colLayer2Active
        rippleColor: Appearance.colors.colOnLayer2
        Accessible.name: tooltip

        contentItem: MaterialSymbol {
            text: actionButton.iconName
            iconSize: 17
            color: actionButton.enabled ? actionButton.iconColor : Appearance.colors.colOnLayer2Disabled
        }
    }
}

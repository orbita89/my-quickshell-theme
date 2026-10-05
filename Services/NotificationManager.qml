pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Common

Singleton {
    id: root

    readonly property int defaultPopupTimeoutMs: 7000
    readonly property string notificationsDir: Paths.stateHome + "/notifications"
    readonly property string filePath: notificationsDir + "/notifications.json"
    readonly property bool silent: UiPreferences.dndEnabled
    readonly property bool popupInhibited: silent || (WidgetState.dashboardSidebarOpen
                                                      && WidgetState.dashboardSidebarView === "info")
    readonly property bool hasNotifs: popupList.length > 0

    property bool historyReady: false
    property var pendingSavedFiles: []
    // МОЁ ДОБАВЛЕНИЕ: непрочитанные — всё, что пришло после последнего
    // открытия центра уведомлений (lastReadAt). Считается от списка, поэтому
    // смахнутое уведомление перестаёт быть непрочитанным само, а «Не
    // беспокоить» не мешает: пропущенное в тишине тоже непрочитано. Момент
    // прочтения хранится в read-state.json — точка на колокольчике переживает
    // перезапуск оболочки. По нему горит красная точка на кнопке в панели.
    property double lastReadAt: 0
    // Момент прочтения до текущего открытия центра уведомлений: всё, что
    // пришло позже, на это открытие отмечается красной точкой (isNew), хотя
    // уже засчитано прочитанным — при следующем открытии точек на нём нет.
    property double highlightSince: 0
    property bool readStateLoaded: false
    // Кликнутое уведомление прочитано, даже если центр уведомлений не открывали.
    readonly property int unread: root.readStateLoaded ? root.list.filter(notif => notif && !notif.read
                                                                              && notif.receivedAt
                                                                              > root.lastReadAt).length : 0
    readonly property bool centerOpen: WidgetState.dashboardSidebarOpen && WidgetState.dashboardSidebarView
                                       === "info"
    readonly property string readStatePath: notificationsDir + "/read-state.json"
    property int idOffset: 0
    // Deliberately `var` and not `list<Notif>`. Notif is an inline component,
    // so its type identity belongs to the compilation unit and is minted anew
    // on every config reload. A typed list checks the element type on append,
    // and after a reload that check started rejecting every entry: the whole
    // history (260 items) failed to append, the list came out full of nulls,
    // and the bindings below then read properties off them. Nothing here needs
    // the typed list — every use, in this file and in the four consumers, is a
    // plain JS array operation, exactly like popupList and groupsByAppName.
    property var list: []
    property var popupList: list.filter(notif => notif.popup).sort((a, b) => b.receivedAt - a.receivedAt)
    property var latestTimeForApp: ({})
    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property list<string> appNameList: appNameListForGroups(root.groupsByAppName)
    property list<string> popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    signal notify(notification: var)
    signal discard(id: int)
    signal discardAll
    signal timeout(id: var)
    signal initDone

    component Notif: QtObject {
        id: wrapper

        required property int notificationId
        property int serverNotificationId: -1
        property Notification notification: null
        property string appIcon: ""
        property string appName: ""
        property string body: ""
        property string desktopEntry: ""
        property string image: ""
        property bool isTransient: false
        property bool popup: false
        property double popupExpiresAt: 0
        property double popupStartedAt: 0
        property double receivedAt: Date.now()
        // Прочитано по клику на само уведомление (см. activateNotification).
        property bool read: false
        property string summary: ""
        property string localKind: ""
        property string filePath: ""
        property Timer timer: null
        property var urgency: NotificationUrgency.Normal
        property Connections closeConnection: Connections {
            target: wrapper.notification

            function onClosed(reason) {
                root.handleNativeClosed(wrapper.notificationId, reason);
            }
        }

        onNotificationChanged: {
            if (notification === null && serverNotificationId !== -1)
                root.detachNotification(notificationId);
        }
    }

    component NotifTimer: Timer {
        required property int notificationId
        running: true
        repeat: false

        onTriggered: {
            const notifObject = root.notificationById(notificationId);
            if (notifObject)
                notifObject.timer = null;
            destroy();
            root.expireNotification(notificationId);
        }
    }

    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    Component.onCompleted: ensureStoreDir.running = true

    onInitDone: {
        root.historyReady = true;
        const pending = root.pendingSavedFiles;
        root.pendingSavedFiles = [];
        pending.forEach(item => root.fileSaved(item.title, item.path));
    }

    Connections {
        target: FileActionService
        function onFinished(action, path, response) {
            if (!response || !response.ok)
                root.addLocal(qsTr("File action failed"), qsTr(
                                  "Could not open the saved file or its location: %1").arg(path));
            else if (!response.fileExists)
                root.addLocal(qsTr("File no longer exists"), qsTr("Opened the containing folder: %1").arg(
                                  path));
        }
    }

    function fileSaved(title, path) {
        if (typeof path !== "string" || !path.startsWith("/") || path.indexOf("\u0000") !== -1)
            return;
        if (!root.historyReady) {
            root.pendingSavedFiles = [...root.pendingSavedFiles,
                                      {
                                          title,
                                          path
                                      }
                    ];
            return;
        }
        root.addLocal(title, path, path);
    }

    function addLocal(title, body, filePath) {
        const now = Date.now();
        const notif = notifComponent.createObject(root, {
                                                      notificationId: ++root.idOffset,
                                                      appName: "Clavis Shell",
                                                      appIcon: "folder",
                                                      summary: title,
                                                      body: body.replace(/&/g, "&amp;").replace(/</g,
                                                                                                "&lt;").replace(
                                                                />/g, "&gt;"),
                                                      localKind: filePath ? "file-saved" : "",
                                                      filePath: filePath || "",
                                                      receivedAt: now,
                                                      urgency: NotificationUrgency.Low,
                                                      popup: !root.popupInhibited,
                                                      popupStartedAt: now,
                                                      popupExpiresAt: now + root.defaultPopupTimeoutMs
                                                  });
        notif.timer = notifTimerComponent.createObject(root, {
                                                           notificationId: notif.notificationId,
                                                           interval: root.defaultPopupTimeoutMs
                                                       });
        root.list = [...root.list, notif];
        if (root.centerOpen)
            Qt.callLater(root.markAllRead);
        root.trimPopupList(3);
        root.saveNotifications();
        root.notify(notif);
    }

    onListChanged: {
        const nextLatest = {};
        root.list.forEach(notif => {
            if (!nextLatest[notif.appName] || notif.receivedAt > nextLatest[notif.appName])
                nextLatest[notif.appName] = notif.receivedAt;
        });
        root.latestTimeForApp = nextLatest;
    }

    Process {
        id: ensureStoreDir
        command: ["mkdir", "-p", root.notificationsDir]
        running: false
        onExited: root.refresh()
    }

    NotificationServer {
        id: notifServer

        actionsSupported: true
        actionIconsSupported: false
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        inlineReplySupported: false
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;

            const replaced = root.list.filter(notif => notif.serverNotificationId === notification.id);
            replaced.forEach(notif => root.stopPopupTimer(notif));

            const now = Date.now();
            const timeoutMs = root.popupTimeoutMs(notification.expireTimeout);
            root.idOffset++;
            const newNotifObject = notifComponent.createObject(root, {
                                                                   "notificationId": root.idOffset,
                                                                   "serverNotificationId": notification.id,
                                                                   "notification": notification,
                                                                   "appIcon": notification.appIcon || "",
                                                                   "appName": notification.appName
                                                                              || notification.desktopEntry
                                                                              || qsTr("System"),
                                                                   "body": notification.body || "",
                                                                   "desktopEntry": notification.desktopEntry
                                                                                   || "",
                                                                   "image": notification.image || "",
                                                                   "isTransient": notification.transient,
                                                                   "summary": notification.summary
                                                                              || notification.appName || qsTr(
                                                                                  "Notification"),
                                                                   "receivedAt": now,
                                                                   "urgency": notification.urgency
                                                               });

            if (timeoutMs > 0) {
                newNotifObject.popupStartedAt = now;
                newNotifObject.popupExpiresAt = now + timeoutMs;
                newNotifObject.timer = notifTimerComponent.createObject(root, {
                                                                            "notificationId":
                                                                            newNotifObject.notificationId,
                                                                            "interval": timeoutMs
                                                                        });
            }

            if (!root.popupInhibited)
                newNotifObject.popup = true;
            // Центр уведомлений открыт — уведомление уже на глазах.
            if (root.centerOpen)
                Qt.callLater(root.markAllRead);

            root.list = [...root.list.filter(notif => notif.serverNotificationId !== notification.id),
                         newNotifObject,];
            replaced.forEach(notif => Qt.callLater(() => notif.destroy()));
            root.trimPopupList(3);
            root.saveNotifications();
            root.notify(newNotifObject);
        }
    }

    FileView {
        id: readStateFile

        path: root.readStatePath
        printErrors: false

        onLoaded: {
            try {
                const saved = JSON.parse(readStateFile.text() || "{}");
                root.lastReadAt = Number(saved.lastReadAt) || Date.now();
            } catch (error) {
                root.lastReadAt = Date.now();
            }
            root.readStateLoaded = true;
        }
        // Файла ещё нет (первый запуск) — всё, что уже в истории, прочитано.
        onLoadFailed: {
            root.markAllRead();
            root.readStateLoaded = true;
        }
    }

    FileView {
        id: notifFileView
        path: root.filePath

        onLoaded: {
            try {
                const fileContents = notifFileView.text();
                const loaded = JSON.parse(fileContents && fileContents.trim() !== "" ? fileContents : "[]");
                if (!Array.isArray(loaded)) {
                    root.list = [];
                    root.initDone();
                    return;
                }

                let maxId = 0;
                root.list = loaded.map(notif => {
                    const notificationId = Number(notif.notificationId || notif.id || 0);
                    maxId = Math.max(maxId, notificationId);
                    return notifComponent.createObject(root, {
                                                           "notificationId": notificationId,
                                                           "localKind": notif.localKind === "file-saved"
                                                                        ? "file-saved" : "",
                                                           "filePath": notif.localKind === "file-saved"
                                                                       && typeof notif.filePath === "string"
                                                                       && notif.filePath.startsWith("/")
                                                                       && notif.filePath.indexOf("\u0000")
                                                                       === -1 ? notif.filePath : "",
                                                           "appIcon": root.durableHistorySource(notif.appIcon),
                                                           "appName": notif.appName || qsTr("System"),
                                                           "body": notif.body || "",
                                                           "desktopEntry": notif.desktopEntry || "",
                                                           "image": root.durableHistorySource(notif.image),
                                                           "summary": notif.summary || notif.appName || qsTr(
                                                                          "Notification"),
                                                           "receivedAt": Number(notif.receivedAt
                                                                                || notif.time) || Date.now(),
                                                           "read": notif.read === true,
                                                           "urgency": notif.urgency
                                                                      ?? NotificationUrgency.Normal
                                                       });
                });
                root.idOffset = maxId;
                root.saveNotifications();
                root.initDone();
            } catch (error) {
                console.warn("NotificationManager failed to load history:", error);
                root.list = [];
                root.idOffset = 0;
                root.initDone();
            }
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.list = [];
                root.saveNotifications();
                root.initDone();
            } else {
                console.warn("NotificationManager failed to load notification file:", error);
                root.initDone();
            }
        }
    }

    function notificationById(id) {
        return root.list.find(notif => notif.notificationId === id) || null;
    }

    function popupTimeoutMs(expireTimeoutSeconds) {
        if (expireTimeoutSeconds === 0)
            return 0;
        if (expireTimeoutSeconds < 0)
            return root.defaultPopupTimeoutMs;
        return Math.max(1, Math.round(expireTimeoutSeconds * 1000));
    }

    function nativeActions(notifObject) {
        if (notifObject && notifObject.localKind === "file-saved" && notifObject.filePath) {
            const path = notifObject.filePath;
            return [
                        {
                            identifier: "default",
                            text: qsTr("Show in folder"),
                            invoke: () => FileActionService.run("reveal", path)
                        },
                        {
                            identifier: "reveal",
                            text: qsTr("Show in folder"),
                            invoke: () => FileActionService.run("reveal", path)
                        },
                        {
                            identifier: "open",
                            text: qsTr("Open"),
                            invoke: () => FileActionService.run("open", path)
                        }
                    ];
        }
        return notifObject && notifObject.notification && notifObject.notification.actions
                ? notifObject.notification.actions : [];
    }

    function defaultAction(notifObject) {
        return root.nativeActions(notifObject).find(action => action.identifier === "default") || null;
    }

    // ЛОКАЛЬНАЯ ПРАВКА: кнопка «Настройки» (action «settings»), которую Chromium
    // и Brave добавляют к каждому своему уведомлению, не показывается — она
    // открывает настройки уведомлений сайта, а не сообщение.
    function normalActions(notifObject) {
        return root.nativeActions(notifObject).filter(action => action.identifier !== "default"
                                                     && action.identifier !== "settings");
    }

    function durableHistorySource(source) {
        const value = source || "";
        return value.startsWith("image://qsimage/") ? "" : value;
    }

    function notifToJSON(notif) {
        return {
            "notificationId": notif.notificationId,
            "localKind": notif.localKind,
            "filePath": notif.filePath,
            "appIcon": root.durableHistorySource(notif.appIcon),
            "appName": notif.appName,
            "body": notif.body,
            "desktopEntry": notif.desktopEntry,
            "image": root.durableHistorySource(notif.image),
            "receivedAt": notif.receivedAt,
            "read": notif.read,
            "summary": notif.summary,
            "urgency": notif.urgency
        };
    }

    function stringifyList(notifications) {
        return JSON.stringify(notifications.filter(notif => !notif.isTransient).map(notif => root.notifToJSON(
                                                                                                 notif)), null,
                              2);
    }

    function refresh() {
        notifFileView.reload();
        readStateFile.reload();
    }

    function saveNotifications() {
        notifFileView.setText(root.stringifyList(root.list));
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => groups[b].receivedAt - groups[a].receivedAt);
    }

    function groupsForList(notifications) {
        const groups = {};
        notifications.forEach(notif => {
            const appName = notif.appName || qsTr("System");
            if (!groups[appName]) {
                groups[appName] = {
                    appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    receivedAt: 0
                };
            }
            groups[appName].notifications.push(notif);
            groups[appName].receivedAt = root.latestTimeForApp[appName] || notif.receivedAt;
            if (!groups[appName].appIcon && notif.appIcon)
                groups[appName].appIcon = notif.appIcon;
        });
        return groups;
    }

    function triggerListChange() {
        root.list = root.list.slice(0);
    }

    function stopPopupTimer(notifObject) {
        if (!notifObject || !notifObject.timer)
            return;
        notifObject.timer.stop();
        notifObject.timer.destroy();
        notifObject.timer = null;
    }

    function hidePopup(notifObject) {
        if (notifObject)
            notifObject.popup = false;
    }

    function finishPopupLifetime(notifObject) {
        if (!notifObject)
            return;
        root.stopPopupTimer(notifObject);
        notifObject.popup = false;
        notifObject.popupStartedAt = 0;
        notifObject.popupExpiresAt = 0;
    }

    function trimPopupList(maxCount) {
        const popups = root.list.filter(notif => notif.popup).sort((a, b) => b.receivedAt - a.receivedAt);
        for (let i = maxCount; i < popups.length; i++)
            root.hidePopup(popups[i]);
        if (popups.length > maxCount)
            root.triggerListChange();
    }

    function setSilent(value) {
        UiPreferences.setDndEnabled(value);
    }

    // Центр уведомлений открыли: запомнить, что было непрочитанным, и
    // засчитать всё прочитанным.
    function beginViewing() {
        root.highlightSince = root.lastReadAt;
        root.markAllRead();
    }

    function isNew(notifObject) {
        return !!notifObject && !notifObject.read && notifObject.receivedAt > root.highlightSince;
    }

    function markAllRead() {
        root.lastReadAt = Date.now();
        readStateFile.setText(JSON.stringify({
                                                 "lastReadAt": root.lastReadAt
                                             }));
    }

    function detachNotification(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        if (notifObject.isTransient) {
            root.removeSnapshot(id);
            return;
        }
        root.finishPopupLifetime(notifObject);
        notifObject.appIcon = root.durableHistorySource(notifObject.appIcon);
        notifObject.image = root.durableHistorySource(notifObject.image);
        notifObject.serverNotificationId = -1;
        notifObject.notification = null;
        root.triggerListChange();
        root.saveNotifications();
    }

    function handleNativeClosed(id, reason) {
        root.detachNotification(id);
    }

    function removeSnapshot(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        root.stopPopupTimer(notifObject);
        root.list = root.list.filter(candidate => candidate.notificationId !== id);
        root.saveNotifications();
        Qt.callLater(() => notifObject.destroy());
    }

    function dismissPopup(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        const nativeNotification = notifObject.notification;
        root.finishPopupLifetime(notifObject);
        if (nativeNotification)
            nativeNotification.dismiss();
        else if (notifObject.isTransient)
            root.removeSnapshot(id);
        root.triggerListChange();
    }

    function expireNotification(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        const nativeNotification = notifObject.notification;
        root.finishPopupLifetime(notifObject);
        if (nativeNotification)
            nativeNotification.expire();
        else if (notifObject.isTransient)
            root.removeSnapshot(id);
        root.triggerListChange();
        root.timeout(id);
    }

    function discardNotification(id) {
        root.discardNotifications([id]);
    }

    function discardNotifications(ids) {
        const targetIds = new Set(ids || []);
        const removed = root.list.filter(notif => targetIds.has(notif.notificationId));
        if (removed.length === 0)
            return;
        removed.forEach(notif => root.stopPopupTimer(notif));
        root.list = root.list.filter(candidate => !targetIds.has(candidate.notificationId));
        root.saveNotifications();
        removed.forEach(notif => {
            if (notif.notification)
                notif.notification.dismiss();
            root.discard(notif.notificationId);
            Qt.callLater(() => notif.destroy());
        });
    }

    function discardAllNotifications() {
        const removed = root.list.slice();
        removed.forEach(notif => root.stopPopupTimer(notif));
        root.list = [];
        root.saveNotifications();
        removed.forEach(notif => {
            if (notif.notification)
                notif.notification.dismiss();
            Qt.callLater(() => notif.destroy());
        });
        root.discardAll();
    }

    function hideAllPopups() {
        root.popupList.forEach(notif => root.hidePopup(notif));
        root.triggerListChange();
    }

    function invokeDefaultAction(id) {
        const action = root.defaultAction(root.notificationById(id));
        if (action)
            action.invoke();
    }

    // МОЁ ДОБАВЛЕНИЕ: клик по карточке уведомления.
    //
    // Вызывает действие «default»: Telegram открывает чат, из которого пришло
    // сообщение, браузер — вкладку (Slack, Gmail…). Чтобы поднять окно, приложению
    // под Wayland нужен токен активации; если его не хватило, окно остаётся
    // позади, и scripts/system/focus_notification_app.py через мгновение
    // переключается на него сам. Уведомление без действия (из истории, после
    // перезапуска приложения) просто показывает приложение, а если оно
    // закрыто — запускает его.
    function activateNotification(id) {
        const notifObject = root.notificationById(id);
        if (!notifObject)
            return;
        // Клик — это прочтение: точка на колокольчике за это уведомление гаснет.
        if (!notifObject.read) {
            notifObject.read = true;
            root.triggerListChange();
            root.saveNotifications();
        }
        const action = root.defaultAction(notifObject);
        if (action)
            action.invoke();
        const keys = [notifObject.desktopEntry, notifObject.appName].filter(key => String(key || "") !== "");
        if (keys.length === 0)
            return;
        const launch = notifObject.desktopEntry || "";
        Quickshell.execDetached(["python3", Paths.systemScriptsDir + "/focus_notification_app.py"].concat(
                                    launch !== "" ? ["--launch", launch] : [], keys));
    }

    // МОЁ ДОБАВЛЕНИЕ: откуда уведомление — «Brave · Slack», «Telegram».
    //
    // Приложение — appName (без хвоста «Desktop»: «Telegram Desktop» →
    // «Telegram»). Сайт — из ссылки, которую браузер ставит первой строкой
    // текста (см. displayBody): app.slack.com → Slack.
    readonly property var knownSites: ({
                                           "mail.google.com": "Gmail",
                                           "calendar.google.com": "Google Календарь",
                                           "web.telegram.org": "Telegram",
                                           "web.whatsapp.com": "WhatsApp",
                                           "github.com": "GitHub",
                                           "gitlab.com": "GitLab",
                                           "youtube.com": "YouTube",
                                           "vk.com": "ВКонтакте",
                                           "linkedin.com": "LinkedIn"
                                       })

    function siteName(body) {
        const match = String(body || "").match(/^\s*<a\b[^>]*href=["']?([^"' >]+)/i);
        if (!match)
            return "";
        let host = "";
        try {
            host = new URL(match[1]).hostname.toLowerCase();
        } catch (error) {
            return "";
        }
        host = host.replace(/^www\./, "");
        if (root.knownSites[host])
            return root.knownSites[host];
        // app.slack.com → slack, discord.com → discord
        const parts = host.split(".");
        const name = parts.length >= 2 ? parts[parts.length - 2] : parts[0];
        return name ? name.charAt(0).toUpperCase() + name.slice(1) : "";
    }

    function sourceLabel(notifObject) {
        if (!notifObject)
            return "";
        const app = String(notifObject.appName || "").replace(/\s+Desktop$/i, "").trim();
        const site = root.siteName(notifObject.body);
        if (site === "" || site.toLowerCase() === app.toLowerCase())
            return app;
        return app === "" ? site : app + " · " + site;
    }

    // МОЁ ДОБАВЛЕНИЕ: текст уведомления для показа.
    //
    // Браузеры (Chromium, Brave, Яндекс) первой строкой ставят ссылку на сайт —
    // «<a href="https://app.slack.com/">app.slack.com</a>». Клик по ней открывал
    // просто slack.com, а не чат. Эту строку убираем, остальные ссылки
    // показываем обычным текстом: кликается вся карточка (activateNotification).
    function displayBody(body) {
        let text = String(body || "").replace(/<img\b[^>]*>/gi, "");
        text = text.replace(/^\s*<a\b[^>]*>[^<]*<\/a>\s*(\n|<br\s*\/?>)+/i, "");
        text = text.replace(/<a\b[^>]*>([\s\S]*?)<\/a>/gi, "$1");
        return text.replace(/^\s+/, "");
    }

    function invokeAction(action) {
        if (action)
            action.invoke();
    }
}

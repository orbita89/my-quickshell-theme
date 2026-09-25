pragma Singleton
import Clavis.Runtime as Runtime
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string uploadRoot: UiPreferences.cloudUploadRoot
    readonly property bool hasWritableRemote: RcloneService.selectedRemote !== null &&
                                              !RcloneService.isReadOnly(RcloneService.selectedRemote)
    readonly property bool uploadActive: currentJobId >= 0 || uploadProcess.running
    readonly property int uploadJobCount: uploadJobs.length
    readonly property bool hasPendingUploads: uploadJobs.some(job => {
        return ["queued", "preparing", "uploading"].indexOf(job.state) >= 0;
    })
    property var uploadJobs: []
    property bool pasteBusy: false

    // Вставка асинхронная (читается процессом), поэтому итог сообщается
    // сигналом — вкладка по нему переключается на очередь, как после drop.
    signal clipboardPasted(int addedCount)
    property bool uploadsPaused: false
    property int currentJobId: -1
    property int nextJobId: 1
    property string lastMessage: ""
    property string lastMessageTone: "neutral"
    property string _stderrText: ""
    property int _cancelRequestedId: -1

    function cloneWith(job, changes) {
        const result = {};
        for (const key in job)
            result[key] = job[key];
        for (const changeKey in changes)
            result[changeKey] = changes[changeKey];
        return result;
    }

    function indexForId(id) {
        for (let index = 0; index < uploadJobs.length; ++index) {
            if (uploadJobs[index].id === id)
                return index;
        }
        return -1;
    }

    function updateJob(id, changes) {
        const index = indexForId(id);
        if (index < 0)
            return;

        const jobs = uploadJobs.slice();
        jobs[index] = cloneWith(jobs[index], changes);
        uploadJobs = jobs;
    }

    function isActivePath(path) {
        for (const job of uploadJobs) {
            if (job.sourcePath === path && ["queued", "preparing", "uploading"].indexOf(job.state) >= 0)
                return true;
        }
        return false;
    }

    function localUrlInfos(urls) {
        const result = [];
        const seen = {};
        for (const url of urls || []) {
            const info = Runtime.ClavisFileSystem.localUrlInfo(url);
            if (!info.valid || seen[info.path])
                continue;

            seen[info.path] = true;
            result.push(info);
        }
        return result;
    }

    function hasLocalUrls(urls) {
        return localUrlInfos(urls).length > 0;
    }

    // ---- Вставка из буфера обмена (Ctrl+V) ----
    //
    // Тот же вход, что у перетаскивания: список file://-адресов уходит в
    // enqueueUrls. Разница только в источнике — буфер вместо drag-and-drop.
    //
    // Буфер читается через wl-paste. `key clipboard` здесь не подходит: это
    // менеджер истории, а нужен живой буфер с конкретным MIME-типом.
    //
    // Разбор одинаково переваривает три формата, которые кладут файловые
    // менеджеры и терминалы:
    //   text/uri-list                 — строки file://…, могут быть #-комментарии;
    //   x-special/gnome-copied-files  — первая строка «copy» или «cut», дальше адреса;
    //   обычный текст                 — просто абсолютный путь, скопированный руками.
    function clipboardUrlsFromText(text) {
        const urls = [];
        for (const rawLine of String(text || "").split("\n")) {
            const line = rawLine.trim();
            if (line === "" || line.startsWith("#") || line === "copy" || line === "cut")
                continue;

            if (line.startsWith("file://")) {
                urls.push(line);
                continue;
            }
            // Голый путь кодируем сами: пробелы и кириллица иначе не доедут.
            // Готовый file://-адрес трогать нельзя — получилось бы двойное
            // кодирование знака процента.
            if (line.startsWith("/"))
                urls.push("file://" + encodeURI(line));
        }
        return urls;
    }

    function pasteFromClipboard() {
        if (pasteBusy || clipboardPasteProcess.running)
            return;

        if (!hasWritableRemote) {
            lastMessage = qsTr("Choose a writable default cloud storage first");
            lastMessageTone = "error";
            return;
        }
        pasteBusy = true;
        clipboardPasteProcess.running = true;
    }

    function enqueueUrls(urls) {
        const infos = localUrlInfos(urls);
        if (infos.length === 0) {
            lastMessage = qsTr("No local files or folders are available to upload");
            lastMessageTone = "error";
            return 0;
        }
        if (!hasWritableRemote) {
            lastMessage = qsTr("Choose a writable default cloud storage first");
            lastMessageTone = "error";
            return 0;
        }
        const remoteName = String(RcloneService.selectedRemote.name || "");
        const jobs = uploadJobs.slice();
        let added = 0;
        for (const info of infos) {
            if (isActivePath(info.path))
                continue;

            const destination = remoteName + ":" + uploadRoot + "/" + info.displayName;
            jobs.push({
                          "id": nextJobId++,
                          "sourcePath": info.path,
                          "displayName": info.displayName,
                          "isDirectory": info.isDirectory,
                          "destination": destination,
                          "state": "queued",
                          "progress": -1,
                          "bytes": 0,
                          "totalBytes": -1,
                          "speed": -1,
                          "eta": -1,
                          "transfers": 0,
                          "totalTransfers": -1,
                          "errors": 0,
                          "transferring": [],
                          "errorMessage": ""
                      });
            added += 1;
        }
        uploadJobs = jobs;
        lastMessage = added > 0 ? "" : qsTr("The same path is already in the upload queue");
        lastMessageTone = added > 0 ? "success" : "neutral";
        if (added > 0)
            Qt.callLater(startNextJob);

        return added;
    }

    function startNextJob() {
        if (uploadsPaused || uploadProcess.running || currentJobId >= 0)
            return;

        let job = null;
        for (const candidate of uploadJobs) {
            if (candidate.state === "queued") {
                job = candidate;
                break;
            }
        }
        if (!job)
            return;

        currentJobId = job.id;
        _stderrText = "";
        updateJob(job.id, {
                      "state": "preparing",
                      "errorMessage": ""
                  });
        const command = [RcloneService.commandName];
        if (job.isDirectory)
            command.push("copy", job.sourcePath, job.destination, "--create-empty-src-dirs");
        else
            command.push("copyto", job.sourcePath, job.destination);
        command.push("--stats=1s", "--stats-log-level=NOTICE", "--use-json-log");
        uploadProcess.command = command;
        uploadProcess.running = true;
    }

    function numberOr(value, fallback) {
        const number = Number(value);
        return isFinite(number) ? number : fallback;
    }

    function handleProcessLine(line, isError) {
        if (currentJobId < 0)
            return;

        const text = String(line || "").trim();
        if (text.length === 0)
            return;

        let data = null;
        try {
            data = JSON.parse(text);
        } catch (error) {
            if (isError)
                _stderrText += (_stderrText.length > 0 ? "\n" : "") + text;

            return;
        }
        const stats = data.stats || (data.msg === "Transferred" ? data : null);
        if (!stats) {
            const level = String(data.level || "").toLowerCase();
            if (level === "error" || level === "fatal")
                _stderrText += (_stderrText.length > 0 ? "\n" : "") + String(data.msg || text);

            return;
        }
        const bytes = numberOr(stats.bytes, 0);
        const totalBytes = numberOr(stats.totalBytes, -1);
        const progress = totalBytes > 0 ? Math.max(0, Math.min(1, bytes / totalBytes)) : -1;
        updateJob(currentJobId, {
                      "state": "uploading",
                      "progress": progress,
                      "bytes": bytes,
                      "totalBytes": totalBytes,
                      "speed": numberOr(stats.speed, -1),
                      "eta": numberOr(stats.eta, -1),
                      "transfers": numberOr(stats.transfers, 0),
                      "totalTransfers": numberOr(stats.totalTransfers, -1),
                      "errors": numberOr(stats.errors, 0),
                      "transferring": Array.isArray(stats.transferring) ? stats.transferring : []
                  });
    }

    function usefulError(text) {
        const lines = String(text || "").split("\n").filter(line => {
            return line.trim().length > 0;
        });
        if (lines.length === 0)
            return qsTr("Upload failed. Check the network or remote permissions");

        const first = lines[0].trim();
        return first.length > 220 ? first.substring(0, 217) + "…" : first;
    }

    function clearCompletedUploads() {
        uploadJobs = uploadJobs.filter(job => {
            return job.state !== "success";
        });
    }

    function removeCompletedUpload(id) {
        const index = indexForId(id);
        if (index < 0 || uploadJobs[index].state !== "success")
            return false;

        const jobs = uploadJobs.slice();
        jobs.splice(index, 1);
        uploadJobs = jobs;
        return true;
    }

    function setUploadsPaused(paused) {
        const nextPaused = Boolean(paused);
        if (uploadsPaused === nextPaused)
            return;

        uploadsPaused = nextPaused;
        if (uploadProcess.running)
            uploadProcess.signal(nextPaused ? 19 : 18);

        if (!nextPaused)
            Qt.callLater(startNextJob);
    }

    function toggleUploadsPaused() {
        setUploadsPaused(!uploadsPaused);
    }

    function retryUpload(id) {
        const index = indexForId(id);
        if (index < 0 || uploadJobs[index].state !== "error" || isActivePath(uploadJobs[index].sourcePath))
            return;

        updateJob(id, {
                      "state": "queued",
                      "progress": -1,
                      "bytes": 0,
                      "totalBytes": -1,
                      "speed": -1,
                      "eta": -1,
                      "transfers": 0,
                      "totalTransfers": -1,
                      "errors": 0,
                      "transferring": [],
                      "errorMessage": ""
                  });
        Qt.callLater(startNextJob);
    }

    function cancelUpload(id) {
        const index = indexForId(id);
        if (index < 0)
            return;

        const state = uploadJobs[index].state;
        if (state === "queued") {
            updateJob(id, {
                          "state": "cancelled"
                      });
            Qt.callLater(startNextJob);
            return;
        }
        if (id === currentJobId && (state === "preparing" || state === "uploading")) {
            _cancelRequestedId = id;
            if (uploadsPaused)
                uploadProcess.signal(18);

            uploadProcess.signal(2);
        }
    }

    // Типы перебираются по приоритету: список адресов надёжнее голого текста.
    // Если ни одного файлового типа нет, берётся обычный текст — вдруг там
    // вставленный руками путь. Всё выводится как есть, разбор — в QML.
    Process {
        id: clipboardPasteProcess

        command: ["sh", "-c", "types=$(wl-paste --list-types 2>/dev/null) || exit 1\n"
            + "for t in text/uri-list x-special/gnome-copied-files; do\n"
            + "  if printf '%s\\n' \"$types\" | grep -qx \"$t\"; then\n"
            + "    exec wl-paste --no-newline --type \"$t\"\n"
            + "  fi\n"
            + "done\n"
            + "exec wl-paste --no-newline"]

        stdout: StdioCollector {
            id: clipboardPasteOutput
        }

        onExited: exitCode => {
            root.pasteBusy = false;
            const urls = exitCode === 0 ? root.clipboardUrlsFromText(clipboardPasteOutput.text) : [];
            if (urls.length === 0) {
                root.lastMessage = qsTr("The clipboard has no files or folders to upload");
                root.lastMessageTone = "error";
                return;
            }
            root.clipboardPasted(root.enqueueUrls(urls));
        }
    }

    Process {
        id: uploadProcess

        running: false
        onExited: exitCode => {
            const finishedId = root.currentJobId;
            root.currentJobId = -1;
            if (finishedId >= 0) {
                if (root._cancelRequestedId === finishedId)
                    root.updateJob(finishedId, {
                                       "state": "cancelled",
                                       "speed": 0,
                                       "eta": -1
                                   });
                else if (exitCode === 0)
                    root.updateJob(finishedId, {
                                       "state": "success",
                                       "progress": 1,
                                       "speed": 0,
                                       "eta": 0
                                   });
                else
                    root.updateJob(finishedId, {
                                       "state": "error",
                                       "speed": 0,
                                       "eta": -1,
                                       "errorMessage": root.usefulError(root._stderrText)
                                   });
            }
            root._cancelRequestedId = -1;
            Qt.callLater(root.startNextJob);
        }

        stdout: SplitParser {
            onRead: data => {
                return root.handleProcessLine(data, false);
            }
        }

        stderr: SplitParser {
            onRead: data => {
                return root.handleProcessLine(data, true);
            }
        }
    }
}

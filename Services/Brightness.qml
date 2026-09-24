pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Clavis.Niri
import Clavis.Runtime

Singleton {
    id: root

    signal brightnessChanged

    property var ddcMonitors: []
    property var pendingDdcMonitors: []
    property real fallbackBrightnessValue: 0.5
    property var monitors: []
    readonly property string focusedScreenName: Niri.currentOutput
    readonly property var activeScreen: root.getScreenByName(root.focusedScreenName) || (
                                            Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    readonly property var activeMonitor: root.getMonitorByName(root.focusedScreenName) || (
                                             root.monitors.length > 0 ? root.monitors[0] : null)
    readonly property real brightnessValue: root.activeMonitor ? root.activeMonitor.brightness :
                                                                 root.fallbackBrightnessValue

    Component.onCompleted: {
        root.rebuildMonitors();
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.rebuildMonitors();
        }
    }

    function rebuildMonitors() {
        for (let i = 0; i < root.monitors.length; i += 1)
            root.monitors[i].destroy();

        const next = [];
        for (let i = 0; i < Quickshell.screens.length; i += 1)
            next.push(monitorComponent.createObject(root, {
                                                        screen: Quickshell.screens[i]
                                                    }));

        root.monitors = next;
        root.rescanDdcMonitors();
    }

    Connections {
        target: BacklightState
        function onChanged() {
            for (const monitor of root.monitors) {
                if (monitor.ready && !monitor.isDdc)
                    monitor.applyBacklight();
            }
        }
    }

    // ЛОКАЛЬНАЯ ПРАВКА: вместо прямого вызова brightnessctl — свой скрипт
    // ~/.local/bin/backlight-set.
    //
    // brightnessctl здесь не работает: udev отдаёт файл
    // /sys/class/backlight/*/brightness группе video, а пользователь в ней не
    // состоит, поэтому подсветка не менялась вовсе. Скрипт сначала пробует
    // brightnessctl, а если тот не смог — просит logind, которому права не
    // нужны. Подробности и причина в комментарии внутри скрипта.
    function backlightCommand(percent) {
        const device = BacklightState.deviceName.length > 0 ? BacklightState.deviceName : "-";
        return ["backlight-set", device, String(percent)];
    }

    function clampBrightness(value, allowZero) {
        const numericValue = Number(value);
        const safeValue = isNaN(numericValue) ? root.fallbackBrightnessValue : numericValue;
        return Math.max(allowZero ? 0.0 : 0.01, Math.min(1.0, safeValue));
    }

    function normalizeConnectorName(name) {
        const raw = String(name || "").trim();
        if (raw.length === 0)
            return "";
        return raw.replace(/^card[0-9]+-/, "");
    }

    function getMonitorForScreen(screen) {
        if (!screen)
            return root.activeMonitor;
        return root.getMonitorByName(screen.name);
    }

    function getScreenByName(name) {
        const normalizedName = root.normalizeConnectorName(name);
        if (normalizedName.length === 0)
            return null;
        return Quickshell.screens.find(screen => root.normalizeConnectorName(screen.name) === normalizedName)
                || null;
    }

    function getMonitorByName(name) {
        const normalizedName = root.normalizeConnectorName(name);
        if (normalizedName.length === 0)
            return null;
        return root.monitors.find(m => root.normalizeConnectorName(m.screenName) === normalizedName) || null;
    }

    function setBrightness(val, allowZero) {
        root.setBrightnessForScreen(null, val, allowZero);
    }

    function setBrightnessForScreen(screen, val, allowZero) {
        const monitor = root.getMonitorForScreen(screen);
        if (monitor) {
            monitor.setBrightness(val, allowZero);
            return;
        }

        const safeVal = root.clampBrightness(val, allowZero);
        const pct = Math.round(safeVal * 100);
        fallbackBrightnessValue = safeVal;
        fallbackSetProc.exec(root.backlightCommand(pct));
        root.brightnessChanged();
    }

    function rescanDdcMonitors() {
        if (ddcDetectProcess.running)
            ddcDetectProcess.running = false;
        pendingDdcMonitors = [];
        ddcDetectProcess.settled = false;
        ddcProbeProcess.running = true;
    }

    function parseDdcBlock(data) {
        const block = String(data || "").trim();
        if (!block.startsWith("Display "))
            return;

        const lines = block.split("\n").map(line => line.trim());
        const busLine = lines.find(line => line.startsWith("I2C bus:"));
        const connectorLine = lines.find(line => line.startsWith("DRM connector:"));
        if (!busLine || !connectorLine)
            return;

        const busMatch = busLine.match(/\/dev\/i2c-([0-9]+)/);
        const connector = root.normalizeConnectorName(connectorLine.split(":").slice(1).join(":"));
        if (!busMatch || connector.length === 0)
            return;

        const next = pendingDdcMonitors.slice();
        next.push({
                      name: connector,
                      busNum: busMatch[1]
                  });
        pendingDdcMonitors = next;
    }

    function initializeMonitor(index) {
        if (index >= root.monitors.length)
            return;
        root.monitors[index].initialize();
    }

    // Наличие ddcutil проверяется через sh, а не попыткой его запустить.
    // Quickshell пишет в лог предупреждение на каждый непойманный запуск, а в
    // 0.3.1 у Process нет failedToStart, чтобы его подавить из QML — и на
    // машине без ddcutil лог засорялся строкой на каждую перезагрузку конфига.
    // sh есть всегда, так что сама проверка молчит.
    Process {
        id: ddcProbeProcess

        command: ["sh", "-c", "command -v ddcutil > /dev/null"]

        onExited: exitCode => {
            if (exitCode === 0)
                ddcDetectProcess.running = true;
            else
                ddcDetectProcess.settle();
        }
    }

    Process {
        id: ddcDetectProcess

        // ЛОКАЛЬНАЯ ПРАВКА: раньше мониторы начинали работать только после
        // выхода ddcutil. Здесь его нет вовсе (внешних мониторов по DDC тоже
        // нет), запуск проваливался, onExited не приходил — и мониторы
        // навсегда оставались с ready = false. Из-за этого ползунок яркости
        // не делал ничего: каждое изменение вставало в pendingSync и там
        // и оставалось.
        //
        // Теперь итог опроса подводится в одном месте и срабатывает в любом
        // случае: и когда ddcutil отработал, и когда его не удалось
        // запустить (тогда running просто вернётся в false).
        property bool settled: false

        function settle() {
            if (settled)
                return;
            settled = true;
            root.ddcMonitors = root.pendingDdcMonitors;
            root.pendingDdcMonitors = [];
            root.initializeMonitor(0);
        }

        command: ["ddcutil", "detect", "--brief"]

        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => root.parseDdcBlock(data)
        }

        onExited: settle()
        onRunningChanged: {
            if (!running)
                settle();
        }
    }

    Process {
        id: fallbackSetProc
        onExited: BacklightState.refresh()
    }

    Component {
        id: monitorComponent

        QtObject {
            id: monitor

            required property var screen
            readonly property string screenName: screen ? screen.name : ""
            property bool isDdc: false
            property string busNum: ""
            property int rawMaxBrightness: 100
            property real brightness: root.fallbackBrightnessValue
            property bool ready: false
            property bool pendingSync: false
            property bool reading: false

            onBrightnessChanged: {
                if (reading)
                    return;

                root.fallbackBrightnessValue = brightness;
                root.brightnessChanged();

                if (!ready) {
                    pendingSync = true;
                    return;
                }

                scheduleSync();
            }

            function initialize() {
                ready = false;
                pendingSync = false;

                const connectorName = root.normalizeConnectorName(screenName);
                const match = root.ddcMonitors.find(m => root.normalizeConnectorName(m.name)
                                                         === connectorName);
                isDdc = !!match;
                busNum = match ? match.busNum : "";
                refresh();
            }

            function applyBacklight() {
                if (!BacklightState.available)
                    return;
                reading = true;
                rawMaxBrightness = BacklightState.maxBrightness;
                brightness = BacklightState.brightness;
                reading = false;
                root.fallbackBrightnessValue = brightness;
            }

            function finishRead() {
                reading = false;
                ready = true;
                if (pendingSync) {
                    pendingSync = false;
                    scheduleSync();
                }
                root.initializeMonitor(root.monitors.indexOf(monitor) + 1);
            }

            function refresh() {
                if (!isDdc) {
                    applyBacklight();
                    finishRead();
                    return;
                }
                reading = true;
                readProcess.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
                readProcess.running = true;
            }

            function parseReadOutput(text) {
                const data = String(text || "").trim();
                if (data.length === 0)
                    return;

                if (isDdc) {
                    const fields = data.split(/\s+/);
                    if (fields.length < 5)
                        return;
                    const current = parseInt(fields[3]);
                    const max = parseInt(fields[4]);
                    if (!isNaN(current) && !isNaN(max) && max > 0) {
                        rawMaxBrightness = max;
                        brightness = Math.max(0, Math.min(1, current / max));
                    }
                    return;
                }
            }

            function setBrightness(value, allowZero) {
                brightness = root.clampBrightness(value, allowZero);
            }

            function scheduleSync() {
                if (isDdc)
                    ddcSetTimer.restart();
                else
                    syncBrightness();
            }

            function syncBrightness() {
                const safeBrightness = Math.max(0, Math.min(1, brightness));
                if (isDdc) {
                    const rawValue = Math.max(1, Math.floor(safeBrightness * rawMaxBrightness));
                    setProcess.exec(["ddcutil", "-b", busNum, "setvcp", "10", String(rawValue)]);
                    return;
                }

                const percent = Math.round(safeBrightness * 100);
                setProcess.exec(root.backlightCommand(percent));
            }

            readonly property Process readProcess: Process {
                stdout: StdioCollector {
                    onStreamFinished: monitor.parseReadOutput(this.text)
                }

                onExited: monitor.finishRead()
            }

            readonly property Process setProcess: Process {
                onExited: {
                    if (!monitor.isDdc)
                        BacklightState.refresh();
                }
            }

            readonly property Timer ddcSetTimer: Timer {
                id: ddcSetTimer

                interval: 300
                running: false
                repeat: false
                onTriggered: monitor.syncBrightness()
            }
        }
    }
}

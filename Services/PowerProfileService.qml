pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// МОЙ МОДУЛЬ: режимы энергопотребления.
//
// Работает поверх power-profiles-daemon — он уже стоит в системе и им же
// пользуется GNOME. Демон даёт три режима: performance, balanced и
// power-saver; переключение разрешено пользователю без root, polkit пропускает.
//
// Чтение и запись идут через busctl напрямую по шине, а не через
// powerprofilesctl: тот написан на Python и стартует десятки миллисекунд,
// а нам нужно опрашивать состояние при каждом открытии панели.
//
// За изменениями следит `gdbus monitor`: один долгоживущий процесс, который
// присылает строку сразу, как только режим сменили — хоть из нашей панели,
// хоть из настроек GNOME, хоть автоматически при переходе на батарею.
// Поэтому опроса по таймеру здесь нет.
//
// Проверить руками:
//     powerprofilesctl get
//     powerprofilesctl list
Singleton {
    id: root

    readonly property string busName: "net.hadess.PowerProfiles"
    readonly property string objectPath: "/net/hadess/PowerProfiles"

    // performance | balanced | power-saver
    property string profile: ""
    // Список того, что умеет именно эта машина; порядок от экономного к мощному.
    property var profiles: []
    readonly property bool available: root.profiles.length > 0
    // Непустая строка, когда производительный режим урезан — обычно из-за
    // нагрева или отключённого блока питания.
    property string degradedReason: ""
    readonly property bool degraded: root.degradedReason.length > 0

    function labelFor(name) {
        switch (name) {
        case "performance":
            return qsTr("Performance");
        case "balanced":
            return qsTr("Balanced");
        case "power-saver":
            return qsTr("Power saver");
        default:
            return name;
        }
    }

    function descriptionFor(name) {
        switch (name) {
        case "performance":
            return qsTr("Full clocks, louder fans, shorter battery life");
        case "balanced":
            return qsTr("Default: clocks rise only under load");
        case "power-saver":
            return qsTr("Clocks limited, quiet, longest battery life");
        default:
            return "";
        }
    }

    function iconFor(name) {
        switch (name) {
        case "performance":
            return "bolt";
        case "power-saver":
            return "energy_savings_leaf";
        default:
            return "balance";
        }
    }

    function setProfile(name) {
        if (name === "" || name === root.profile)
            return;
        setter.command = ["busctl", "--system", "set-property", root.busName, root.objectPath,
                          root.busName, "ActiveProfile", "s", name];
        setter.running = true;
    }

    // По кругу от экономного к мощному: один клик по плитке — следующий режим.
    function cycle() {
        if (root.profiles.length === 0)
            return;
        const index = root.profiles.indexOf(root.profile);
        root.setProfile(root.profiles[(index + 1) % root.profiles.length]);
    }

    function applyProfileList(text) {
        let parsed = null;
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            return;
        }

        const rows = Array.isArray(parsed && parsed.data) ? parsed.data : [];
        const names = [];
        for (let i = 0; i < rows.length; ++i) {
            const entry = rows[i] && rows[i].Profile;
            if (entry && typeof entry.data === "string")
                names.push(entry.data);
        }
        root.profiles = names;
    }

    function applyString(text, property) {
        let parsed = null;
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            return;
        }
        if (typeof parsed.data === "string")
            root[property] = parsed.data;
    }

    function readProperty(process, name) {
        process.command = ["busctl", "--system", "--json=short", "get-property", root.busName,
                           root.objectPath, root.busName, name];
        process.running = true;
    }

    function refresh() {
        root.readProperty(activeReader, "ActiveProfile");
        root.readProperty(degradedReader, "PerformanceDegraded");
    }

    Component.onCompleted: {
        root.readProperty(listReader, "Profiles");
        root.refresh();
    }

    Process {
        id: listReader

        stdout: StdioCollector {
            onStreamFinished: root.applyProfileList(text)
        }
    }

    Process {
        id: activeReader

        stdout: StdioCollector {
            onStreamFinished: root.applyString(text, "profile")
        }
    }

    Process {
        id: degradedReader

        stdout: StdioCollector {
            onStreamFinished: root.applyString(text, "degradedReason")
        }
    }

    Process {
        id: setter

        // Демон подтверждает смену сигналом, его поймает монитор ниже.
        // Но если запись не прошла, состояние надо вернуть к настоящему.
        onExited: exitCode => {
            if (exitCode !== 0)
                root.refresh();
        }
    }

    // Одна строка на каждое изменение свойства, значение прямо в ней:
    //   ... PropertiesChanged ('net.hadess.PowerProfiles',
    //       {'ActiveProfile': <'performance'>}, @as [])
    Process {
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", root.busName]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const active = /'ActiveProfile':\s*<'([^']*)'>/.exec(line);
                if (active)
                    root.profile = active[1];

                const degraded = /'PerformanceDegraded':\s*<'([^']*)'>/.exec(line);
                if (degraded)
                    root.degradedReason = degraded[1];
            }
        }
    }
}

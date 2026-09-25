pragma Singleton

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    // niri rejects a second input section, so pointer settings are edited in
    // place inside the user's configuration. NiriConfigService owns the file
    // access; this service only debounces the UI and keeps optimistic values
    // visible until the configuration snapshot catches up.
    readonly property var snapshot: NiriConfigService.snapshot.input || ({
                                                                             "available": false,
                                                                             "writable": false,
                                                                             "locked": [],
                                                                             "devices": {}
                                                                         })
    readonly property bool supported: NiriConfigService.supported
    readonly property bool available: !!snapshot.available
    readonly property bool writable: !!snapshot.writable
    readonly property string source: snapshot.source || ""
    readonly property bool busy: NiriConfigService.busy && NiriConfigService.activeFeature === "input"
    readonly property string error: NiriConfigService.errorFeature === "input" ? NiriConfigService.error : ""
    readonly property bool editable: supported && available && writable

    property var pending: ({})
    property var inFlight: ({})

    function deviceSettings(device) {
        const entry = snapshot.devices ? snapshot.devices[device] : null;
        return entry && entry.settings ? entry.settings : ({});
    }

    function overlay(store, device, name) {
        const entry = store[device];
        return entry && entry[name] !== undefined ? entry[name] : undefined;
    }

    function value(device, name, fallback) {
        let current = overlay(root.pending, device, name);
        if (current === undefined)
            current = overlay(root.inFlight, device, name);
        if (current === undefined)
            current = root.deviceSettings(device)[name];
        return current === undefined || current === null ? fallback : current;
    }

    function number(device, name, fallback) {
        return Number(root.value(device, name, fallback));
    }

    function flag(device, name) {
        return root.value(device, name, false) === true;
    }

    function choice(device, name, fallback) {
        return String(root.value(device, name, fallback));
    }

    function locked(name) {
        const entries = snapshot.locked || [];
        return entries.indexOf(name) !== -1;
    }

    function sectionValue(name, fallback) {
        const current = overlay(root.pending, "", name);
        if (current !== undefined)
            return current;
        const sent = overlay(root.inFlight, "", name);
        if (sent !== undefined)
            return sent;
        return snapshot[name] === undefined ? fallback : snapshot[name];
    }

    function sectionFlag(name) {
        return root.sectionValue(name, false) === true;
    }

    function set(device, name, value) {
        root.pending = Object.assign({}, root.pending, {
                                         [device]: Object.assign({}, root.pending[device] || {}, {
                                                                     [name]: value
                                                                 })
                                     });
        commit.restart();
    }

    function setSectionFlag(name, value) {
        root.set("", name, value);
    }

    function reset(device, name) {
        root.set(device, name, null);
    }

    function flush() {
        const devices = {};
        let flags = {};
        for (const device in root.pending) {
            if (device === "")
                flags = root.pending[device];
            else
                devices[device] = root.pending[device];
        }
        if (Object.keys(devices).length === 0 && Object.keys(flags).length === 0)
            return;

        root.inFlight = root.pending;
        root.pending = ({});
        NiriConfigService.saveInput(Object.assign({
                                                      "devices": devices
                                                  }, flags));
    }

    Timer {
        id: commit

        interval: 350
        onTriggered: {
            // Never overlap writes: the editor rejects stale revisions.
            if (NiriConfigService.busy) {
                commit.restart();
                return;
            }
            root.flush();
        }
    }

    Connections {
        function onSaved() {
            root.inFlight = ({});
        }

        function onErrorChanged() {
            if (NiriConfigService.error !== "" && NiriConfigService.errorFeature === "input")
                root.inFlight = ({});
        }

        target: NiriConfigService
    }
}

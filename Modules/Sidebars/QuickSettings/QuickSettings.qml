import QtQuick
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    property bool foreground: false
    property string displayedView: ""
    readonly property string activeView: {
        switch (WidgetState.quickSettingsView) {
        case "network":
        case "bluetooth":
        case "idle":
        case "audio":
        case "microphone":
        case "night":
        case "power":
        case "settings":
            return WidgetState.quickSettingsView;
        default:
            return "settings";
        }
    }
    // ЛОКАЛЬНАЯ ПРАВКА: была цепочка тернарных операторов на пятнадцать строк
    // с лесенкой отступов — дописать в неё страницу, не сломав форматирование,
    // почти невозможно. Тот же выбор списком.
    readonly property var activeViewLoader: {
        switch (activeView) {
        case "network":
            return networkLoader;
        case "bluetooth":
            return bluetoothLoader;
        case "idle":
            return idleLoader;
        case "audio":
            return audioLoader;
        case "microphone":
            return microphoneLoader;
        case "night":
            return nightLoader;
        case "power":
            return powerLoader;
        default:
            return settingsLoader;
        }
    }
    readonly property bool readyForPresentation: activeViewLoader.active && activeViewLoader.status
                                                 === Loader.Ready && activeViewLoader.item !== null
                                                 && displayedView === activeView

    function syncDisplayedView() {
        if (activeViewLoader.active && activeViewLoader.status === Loader.Ready && activeViewLoader.item
                !== null) {
            displayedView = activeView;
        }
    }

    Component.onCompleted: syncDisplayedView()
    onActiveViewChanged: syncDisplayedView()

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "network"
        transitionsEnabled: root.foreground

        Loader {
            id: networkLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "network" || loadedOnce
            asynchronous: true
            sourceComponent: networkComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "bluetooth"
        transitionsEnabled: root.foreground

        Loader {
            id: bluetoothLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "bluetooth" || loadedOnce
            asynchronous: true
            sourceComponent: bluetoothComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "idle"
        transitionsEnabled: root.foreground

        Loader {
            id: idleLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "idle" || loadedOnce
            asynchronous: true
            sourceComponent: idleComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "audio"
        transitionsEnabled: root.foreground

        Loader {
            id: audioLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "audio" || loadedOnce
            asynchronous: true
            sourceComponent: audioComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "microphone"
        transitionsEnabled: root.foreground

        Loader {
            id: microphoneLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "microphone" || loadedOnce
            asynchronous: true
            sourceComponent: microphoneComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "night"
        transitionsEnabled: root.foreground

        Loader {
            id: nightLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "night" || loadedOnce
            asynchronous: true
            sourceComponent: nightComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "power"
        transitionsEnabled: root.foreground

        Loader {
            id: powerLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "power" || loadedOnce
            asynchronous: true
            sourceComponent: powerComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "settings"
        hubPage: true
        transitionsEnabled: root.foreground

        Loader {
            id: settingsLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "settings" || loadedOnce
            asynchronous: true
            sourceComponent: settingsComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    Component {
        id: networkComponent

        NetworkContent {
            foreground: root.foreground && root.activeView === "network"
        }
    }

    Component {
        id: bluetoothComponent

        BluetoothContent {
            foreground: root.foreground && root.activeView === "bluetooth"
        }
    }

    Component {
        id: idleComponent

        IdleContent {
            foreground: root.foreground && root.activeView === "idle"
        }
    }

    Component {
        id: audioComponent

        AudioContent {
            foreground: root.foreground && root.activeView === "audio"
        }
    }

    Component {
        id: microphoneComponent

        MicrophoneContent {
            foreground: root.foreground && root.activeView === "microphone"
        }
    }

    Component {
        id: nightComponent

        NightModeContent {}
    }

    Component {
        id: powerComponent

        PowerProfileContent {}
    }

    Component {
        id: settingsComponent

        SettingsContent {
            screen: root.screen
        }
    }
}

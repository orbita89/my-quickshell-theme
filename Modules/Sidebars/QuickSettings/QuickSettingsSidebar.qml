import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property var panelScreen: null
    readonly property bool onLeft: PersonalizationConfig.quickSettingsSidebarSide === "left"
    // ЛОКАЛЬНАЯ ПРАВКА: та же ширина, что у Dashboard. Обе панели выезжают
    // с одного края и подменяют друг друга; когда быстрые настройки были на
    // 120 px уже, при переключении справа открывалась полоса рабочего стола.
    property real sidebarWidth: Math.min(Metrics.sidebarWidthComfortable, Math.max(0, width - gap * 2))
    property int gap: Math.min(Metrics.pageMargin, Math.max(Metrics.spacingS, Math.min(width, height)
                                                            * 0.025))
    readonly property alias blurBackgroundItem: panelSurface
    // ЛОКАЛЬНАЯ ПРАВКА: во всю высоту, как Dashboard — иначе снизу оставался
    // просвет там, где только что была вторая панель.
    readonly property int panelTargetHeight: Math.max(0, height - sidebarY - gap)
    // The host window already starts inside layer-shell's usable geometry.
    readonly property int sidebarY: gap
    readonly property real closedSlideOffset: (onLeft ? -1 : 1) * (sidebarWidth + gap)
    readonly property int enterDuration: Animations.durations.sidebarEnter
    readonly property int exitDuration: Animations.durations.sidebarExit
    readonly property bool requestedOpen: WidgetState.quickSettingsOpen
    property bool presentationAllowed: true
    property bool panelPresented: false
    property bool contentRetained: false
    property bool presentationOpen: false
    readonly property bool contentReady: quickSettingsLoader.status === Loader.Ready
                                         && quickSettingsLoader.item !== null
                                         && quickSettingsLoader.item.readyForPresentation
    // A presented surface is only created after contentReady. It remains
    // operational during closing so its contents leave with the panel.
    readonly property bool contentOperational: panelPresented
    readonly property bool panelActive: panelPresented

    function preparePresentation() {
        contentRetained = true;
        startPresentation();
    }

    function startPresentation() {
        if (!requestedOpen || !contentReady || !presentationAllowed)
            return;
        panelPresented = true;
        presentationOpen = true;
    }

    function beginClosing() {
        presentationOpen = false;
        if (panelPresented)
            return;
        if (!PersonalizationConfig.keepSidebarsLoaded)
            contentRetained = false;
    }

    function finishClosing() {
        if (requestedOpen)
            return;

        // Hide the already off-screen surface before releasing its layout tree.
        panelPresented = false;
        if (!PersonalizationConfig.keepSidebarsLoaded)
            contentRetained = false;
    }

    Component.onCompleted: {
        // Retain after the first open, without preloading QuickSettings
        // and its services during shell startup.
        if (requestedOpen)
            preparePresentation();
    }

    onRequestedOpenChanged: {
        if (requestedOpen)
            preparePresentation();
        else
            beginClosing();
    }

    onPresentationAllowedChanged: {
        if (presentationAllowed)
            startPresentation();
    }

    onContentReadyChanged: {
        if (contentReady)
            startPresentation();
    }

    Connections {
        target: PersonalizationConfig

        function onKeepSidebarsLoadedChanged() {
            if (!PersonalizationConfig.keepSidebarsLoaded && !root.requestedOpen && !root.panelPresented) {
                root.contentRetained = false;
            }
        }
    }

    function containsPoint(hostX, hostY) {
        const localPosition = sidebarContentFrame.mapFromItem(root, hostX, hostY);
        return localPosition.x >= 0 && localPosition.x <= sidebarContentFrame.width && localPosition.y >= 0
                && localPosition.y <= sidebarContentFrame.height;
    }

    Item {
        id: animController

        property real slideOffset: root.closedSlideOffset

        state: root.presentationOpen ? "open" : "closed"

        states: [
            State {
                name: "open"

                PropertyChanges {
                    target: animController
                    slideOffset: 0
                }
            },
            State {
                name: "closed"

                PropertyChanges {
                    target: animController
                    slideOffset: root.closedSlideOffset
                }
            }
        ]

        transitions: [
            Transition {
                id: openTransition
                to: "open"

                NumberAnimation {
                    target: animController
                    property: "slideOffset"
                    duration: root.enterDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.3
                }
            },
            Transition {
                id: closeTransition
                to: "closed"

                SequentialAnimation {
                    NumberAnimation {
                        target: animController
                        property: "slideOffset"
                        duration: root.exitDuration
                        easing.type: Easing.InBack
                        easing.overshoot: 0.18
                    }

                    ScriptAction {
                        script: root.finishClosing()
                    }
                }
            }
        ]
    }

    Rectangle {
        id: panelSurface

        visible: root.panelActive
        x: (root.onLeft ? root.gap : root.width - root.sidebarWidth - root.gap) + animController.slideOffset
        y: root.sidebarY
        width: root.sidebarWidth
        height: root.panelTargetHeight
        color: BlurService.backgroundColor(Appearance.colors.colLayer0)
        radius: Appearance.rounding.large
    }

    Item {
        id: sidebarContentFrame

        visible: root.panelActive
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height
        clip: true

        Loader {
            id: quickSettingsLoader

            anchors.fill: parent
            active: root.contentRetained
            asynchronous: true
            sourceComponent: quickSettingsComponent
        }
    }

    Component {
        id: quickSettingsComponent

        QuickSettings {
            anchors.fill: parent
            screen: root.panelScreen
            foreground: root.contentOperational
        }
    }
}

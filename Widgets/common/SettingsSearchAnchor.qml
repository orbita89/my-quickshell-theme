import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services

// An explicit declaration attached to the actual section. The build consumes
// only this JSON literal; its ID is also the runtime registration key.
Item {
    id: root
    required property string declaration
    required property Item target
    readonly property var entry: JSON.parse(declaration)
    readonly property string title: {
        const language = Qt.uiLanguage;
        return SpotlightCatalog.title(entry.id);
    }
    property bool registerAnchor: true
    property bool wholePage: false
    property int requestSerial: -1
    property real highlightOpacity: 0
    visible: false
    width: 0
    height: 0

    // QtQuick.Layouts manages every visible child it has, so a highlight
    // parented into one cannot use anchors (that is the warning) and, once
    // visible, would claim a cell of its own and push the section's content
    // aside. Some targets are plain items (SettingsSection, MaterialCard) and
    // some are layouts (KeystoneSection, the Section components of ThemePage
    // and WallpaperPage), so the host is resolved per target: the target
    // itself when it can hold a free-floating child, otherwise its nearest
    // non-layout ancestor.
    function isLayout(item) {
        return item instanceof RowLayout || item instanceof ColumnLayout || item instanceof GridLayout
                || item instanceof StackLayout;
    }

    readonly property Item highlightHost: {
        let item = root.target;
        while (item && root.isLayout(item))
            item = item.parent;
        return item;
    }

    // Target geometry in host coordinates. mapToItem() is not reactive, so the
    // target's own position and size are read first: they are what the binding
    // depends on, and a layout moving the target updates them.
    readonly property rect highlightArea: {
        const target = root.target;
        const host = root.highlightHost;
        if (!target || !host)
            return Qt.rect(0, 0, 0, 0);
        const width = target.width;
        const height = target.height;
        const x = target.x;
        const y = target.y;
        if (host === target)
            return Qt.rect(0, 0, width, height);
        const point = target.mapToItem(host, 0, 0);
        return Qt.rect(point.x, point.y, width, height);
    }

    function polishTarget() {
        const ancestors = [];
        for (let item = target; item; item = item.parent)
            ancestors.push(item);
        for (let index = ancestors.length - 1; index >= 0; --index)
            ancestors[index].ensurePolished();
    }

    function reveal(serial) {
        if (!target || !target.visible || target.width <= 0 || target.height <= 0)
            return false;
        requestSerial = serial;
        if (wholePage && target instanceof Flickable)
            target.contentY = target.originY;
        // Each enclosing scroll viewport is handled in its own coordinates.
        for (let item = target.parent; item; item = item.parent) {
            if (item instanceof Flickable) {
                item.cancelFlick();
                const point = target.mapToItem(item.contentItem, 0, 0);
                item.contentY = Math.max(item.originY, Math.min(point.y - Metrics.spacingM, item.originY + Math.max(
                                                                    0, item.contentHeight - item.height)));
            }
        }
        highlightOpacity = 1;
        hold.restart();
        return true;
    }
    Component.onCompleted: {
        if (registerAnchor)
            ControlCenterService.registerSearchAnchor(root);
    }
    Component.onDestruction: {
        if (registerAnchor)
            ControlCenterService.unregisterSearchAnchor(root);
    }
    Connections {
        target: root.target
        function onWidthChanged() {
            ControlCenterService.retrySearch();
        }
        function onHeightChanged() {
            ControlCenterService.retrySearch();
        }
        function onYChanged() {
            ControlCenterService.retrySearch();
        }
        function onVisibleChanged() {
            ControlCenterService.retrySearch();
        }
    }
    Connections {
        target: ControlCenterService
        function onSearchSerialChanged() {
            if (root.requestSerial !== ControlCenterService.searchSerial) {
                hold.stop();
                root.highlightOpacity = 0;
            }
        }
    }
    Rectangle {
        parent: root.highlightHost
        x: root.highlightArea.x
        y: root.highlightArea.y
        width: root.highlightArea.width
        height: root.highlightArea.height
        radius: Metrics.cornerM
        color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.10)
        border.width: 1
        border.color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.38)
        opacity: root.highlightOpacity
        visible: opacity > 0
        z: 100
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
            }
        }
    }
    Timer {
        id: hold
        interval: 1100
        onTriggered: root.highlightOpacity = 0
    }
}

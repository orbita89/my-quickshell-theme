import QtQuick
import qs.Modules.Keystone.DashboardContent

// Вкладка «Dashboard» главного меню: колонка виджетов и плашка с
// карточками. Раскладка — DashboardContent.qml, описание — README.md рядом.
//
// Наружу, кроме размера, отдаёт геометрию плашки: KeystoneSurface вырезает
// под неё окно в фоне островка и размывает то, что под ним.
Item {
    id: root

    property var hub: null

    readonly property bool keyholeVisible: content.keyholeVisible
    readonly property var keyholeGlassItems: content.keyholeGlassItems
    readonly property real keyholeCenterOffset: content.keyholeCenterOffset
    readonly property real keyholeWidth: content.keyholeWidth
    readonly property real keyholeHeight: content.keyholeHeight
    readonly property real keyholeTopOffset: content.keyholeTopOffset

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    DashboardContent {
        id: content

        anchors.fill: parent
        screen: root.hub ? root.hub.screen : null
    }
}

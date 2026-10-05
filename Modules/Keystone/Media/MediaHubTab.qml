import QtQuick
import qs.Modules.Keystone.Media

// Вкладка «Media» главного меню: полноценный плеер с обложкой, волной и
// текстом песни. Контракт вкладки — Modules/Keystone/Hub/README.md.
Item {
    id: root

    // HubContent; отсюда берётся текущий плеер MPRIS.
    property var hub: null

    implicitWidth: 760
    implicitHeight: 480

    Media {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        player: root.hub ? root.hub.player : null
    }
}

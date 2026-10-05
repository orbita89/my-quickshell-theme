import QtQuick
import qs.Modules.Keystone.CloudUploadContent

// Вкладка «Upload» главного меню: очередь загрузки в облако (rclone).
// Файлы сюда перетаскивают или вставляют Ctrl+V — поэтому в реестре у неё
// stickyOpen и acceptsFileDrop. Контракт вкладки — Modules/Keystone/Hub/README.md.
Item {
    id: root

    property var hub: null

    // Вызывается островком после drop или Ctrl+V: показать очередь.
    function finishDrop(addedCount) {
        content.finishDrop(addedCount);
    }

    // ЛОКАЛЬНАЯ ПРАВКА: вкладка заметно уже и ниже остальных — на
    // ноутбучном экране 1536x864 прежние 960x580 занимали две трети высоты.
    implicitWidth: 440
    implicitHeight: 220

    CloudUploadContent {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.95
        height: parent.height
        dragActive: root.hub ? root.hub.dragActive : false
    }
}

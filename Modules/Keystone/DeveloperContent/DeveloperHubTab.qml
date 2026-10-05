import QtQuick
import qs.Modules.Keystone.DeveloperContent

// Вкладка «Developer» главного меню: список контейнеров Docker.
// DockerWidget опрашивает docker, только пока виден его родитель — эта
// обёртка, а она видна, только пока вкладка открыта.
// Контракт вкладки — Modules/Keystone/Hub/README.md.
Item {
    id: root

    property var hub: null

    implicitWidth: 760
    implicitHeight: 480

    DockerWidget {
        anchors.fill: parent
    }
}

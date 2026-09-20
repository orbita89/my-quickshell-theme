pragma Singleton

import QtQuick
import Quickshell

// МОЙ МОДУЛЬ: мостик к островку Keystone.
//
// Островок — обычный компонент внутри AppShell, а не синглтон, поэтому
// из панели до него не дотянуться напрямую. Этот синглтон просто раздаёт
// сигналы: панель их шлёт, островок слушает (см. Modules/Keystone/Keystone.qml).
//
// Сейчас используется для мини-плеера: клик по волне в панели открывает
// вкладку «Media» островка.
Singleton {
    id: root

    signal mediaRequested
    signal hubRequested
}

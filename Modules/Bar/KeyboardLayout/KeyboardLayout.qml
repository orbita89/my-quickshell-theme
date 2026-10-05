import QtQuick
import Clavis.Niri
import qs.Common
import qs.Widgets.common
import "KeyboardLayoutCodes.js" as KeyboardLayoutCodes

// МОЙ МОДУЛЬ: раскладка клавиатуры на панели — флагом (🇷🇺, 🇺🇸…).
//
// Текущая раскладка — из niri (Niri.currentKeyboardLayoutName, плагин
// Clavis.Niri), клик переключает на следующую (Niri.cycleKeyboardLayout).
// Включается в Настройках → Общие → Панель («Раскладка клавиатуры»).
TopBarPill {
    id: root

    property bool vertical: false
    readonly property string layoutName: Niri.currentKeyboardLayoutName
    readonly property string layoutCode: KeyboardLayoutCodes.codeFor(root.layoutName)

    visible: root.layoutName !== ""
    implicitWidth: root.vertical ? Sizes.barVisualThickness : flag.implicitWidth + 20
    implicitHeight: root.vertical ? flag.implicitHeight + 20 : Sizes.barPillThickness

    LayoutFlag {
        id: flag

        anchors.centerIn: parent
        code: root.layoutCode
        scale: mouseArea.containsMouse ? 1.1 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Niri.cycleKeyboardLayout()
    }

    StyledToolTip {
        text: root.layoutName
        extraVisibleCondition: mouseArea.containsMouse
    }
}

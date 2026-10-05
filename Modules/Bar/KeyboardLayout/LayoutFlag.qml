import QtQuick
import qs.Common

// МОЙ МОДУЛЬ: флаг раскладки клавиатуры, нарисованный прямоугольниками.
//
// Не эмодзи: флаги-эмодзи зависят от цветного шрифта и без него показываются
// буквами. Нарисованы флаги ru, us, ua, de, fr; для любого другого кода —
// плашка с двумя буквами (KZ, BY…). Как добавить флаг — README.md рядом.
Item {
    id: root

    // Двухбуквенный код: "ru", "us"… (см. KeyboardLayoutCodes.js).
    property string code: ""
    readonly property var stripes: ({
                                        "ru": {
                                            "horizontal": true,
                                            "colors": ["#ffffff", "#0039a6", "#d52b1e"]
                                        },
                                        "ua": {
                                            "horizontal": true,
                                            "colors": ["#0057b7", "#ffd700"]
                                        },
                                        "de": {
                                            "horizontal": true,
                                            "colors": ["#000000", "#dd0000", "#ffce00"]
                                        },
                                        "fr": {
                                            "horizontal": false,
                                            "colors": ["#0055a4", "#ffffff", "#ef4135"]
                                        }
                                    })
    readonly property var stripeFlag: root.stripes[root.code] || null
    readonly property bool drawn: root.stripeFlag !== null || root.code === "us"

    implicitWidth: 22
    implicitHeight: 15

    // Рисуется напрямую, без слоя и маски: скрытый слой-источник для маски не
    // всегда перерисовывался при смене раскладки, и флаг США оставался пустым
    // («чёрное пятно»). Скругление — радиус 2 у обрезающего прямоугольника.
    Rectangle {
        id: flagContent

        anchors.fill: parent
        visible: root.drawn
        radius: 2
        clip: true
        color: "transparent"

        // Полосатые флаги.
        Repeater {
            model: root.stripeFlag ? root.stripeFlag.colors : []

            Rectangle {
                required property int index
                required property string modelData
                readonly property int count: root.stripeFlag ? root.stripeFlag.colors.length : 1

                x: root.stripeFlag && !root.stripeFlag.horizontal ? Math.round(index * flagContent.width / count) : 0
                y: root.stripeFlag && root.stripeFlag.horizontal ? Math.round(index * flagContent.height / count) : 0
                width: root.stripeFlag && !root.stripeFlag.horizontal ? Math.ceil(flagContent.width / count) :
                                                                        flagContent.width
                height: root.stripeFlag && root.stripeFlag.horizontal ? Math.ceil(flagContent.height / count) :
                                                                        flagContent.height
                color: modelData
            }
        }

        // США, упрощённо для 22×15: 7 полос вместо 13 (тонкие полосы сливались
        // в бурое пятно) и синий крыж без звёзд.
        Item {
            anchors.fill: parent
            visible: root.code === "us"

            Repeater {
                model: 7

                Rectangle {
                    required property int index

                    y: Math.round(index * flagContent.height / 7)
                    width: flagContent.width
                    height: Math.ceil(flagContent.height / 7)
                    color: index % 2 === 0 ? "#d22f42" : "#ffffff"
                }
            }

            Rectangle {
                width: Math.round(flagContent.width * 0.45)
                height: Math.round(flagContent.height * 4 / 7)
                color: "#3c4a9e"
            }
        }
    }

    // Тонкая обводка: белые полосы не сливаются со светлой панелью.
    Rectangle {
        anchors.fill: parent
        visible: root.drawn
        radius: 3
        color: "transparent"
        border.width: 1
        border.color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.25)
    }

    // Флага нет — две буквы кода.
    Rectangle {
        anchors.fill: parent
        visible: !root.drawn
        radius: 3
        color: Appearance.colors.colSecondaryContainer

        Text {
            anchors.centerIn: parent
            text: root.code.toUpperCase()
            color: Appearance.colors.colOnSecondaryContainer
            font.family: Fonts.numeric
            font.pixelSize: 9
            font.bold: true
        }
    }
}

import QtQuick
import QtQuick.Effects
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

    Item {
        id: flagContent

        anchors.fill: parent
        visible: false
        layer.enabled: true

        // Полосатые флаги.
        Repeater {
            model: root.stripeFlag ? root.stripeFlag.colors : []

            Rectangle {
                required property int index
                required property string modelData
                readonly property int count: root.stripeFlag.colors.length

                x: root.stripeFlag.horizontal ? 0 : index * flagContent.width / count
                y: root.stripeFlag.horizontal ? index * flagContent.height / count : 0
                width: root.stripeFlag.horizontal ? flagContent.width : Math.ceil(flagContent.width / count)
                height: root.stripeFlag.horizontal ? Math.ceil(flagContent.height / count) : flagContent.height
                color: modelData
            }
        }

        // США: 13 полос и синий крыж; звёзды при таком размере — точки.
        Item {
            anchors.fill: parent
            visible: root.code === "us"

            Repeater {
                model: 13

                Rectangle {
                    required property int index

                    y: index * flagContent.height / 13
                    width: flagContent.width
                    height: Math.ceil(flagContent.height / 13)
                    color: index % 2 === 0 ? "#b22234" : "#ffffff"
                }
            }

            Rectangle {
                width: flagContent.width * 0.42
                height: flagContent.height * 7 / 13
                color: "#3c3b6e"

                Grid {
                    anchors.centerIn: parent
                    columns: 3
                    rows: 3
                    spacing: 1.2

                    Repeater {
                        model: 9

                        Rectangle {
                            width: 1.2
                            height: 1.2
                            radius: 0.6
                            color: "#ffffff"
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: flagMask

        anchors.fill: parent
        radius: 3
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.drawn
        source: flagContent
        maskEnabled: true
        maskSource: flagMask
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

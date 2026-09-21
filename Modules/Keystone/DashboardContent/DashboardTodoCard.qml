import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// МОЙ МОДУЛЬ: список дел в правой плашке Dashboard.
//
// Полноценный виджет из боковой панели (TodoWidget) сюда не влезает: там
// вкладки, плавающая кнопка и отдельное окно ввода. Здесь всё на одном
// экране — поле ввода, невыполненные сверху, выполненные снизу приглушённо.
//
// Данные общие с боковой панелью: TodoService, файл ~/.local/state/clavis/todo.json.
Item {
    id: root

    property bool active: false

    // Индексы нужны настоящие, из TodoService: по ним идут отметка и удаление.
    readonly property var pending: {
        const out = [];
        for (let i = 0; i < TodoService.list.length; ++i)
            if (!TodoService.list[i].done)
                out.push({
                    "index": i,
                    "content": TodoService.list[i].content
                });
        return out;
    }
    readonly property var finished: {
        const out = [];
        for (let i = TodoService.list.length - 1; i >= 0; --i)
            if (TodoService.list[i].done)
                out.push({
                    "index": i,
                    "content": TodoService.list[i].content
                });
        return out;
    }

    function addTask() {
        if (!TodoService.addTask(taskField.text))
            return;
        taskField.text = "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "checklist"
                iconSize: 22
                fill: 1
                color: Appearance.colors.colPrimary
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("To-do")
                color: Appearance.colors.colOnLayer0
                font.family: Fonts.ui
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Text {
                text: root.pending.length > 0 ? qsTr("%1 left").arg(root.pending.length) : qsTr("all done")
                color: Appearance.colors.colSubtext
                font.family: Fonts.ui
                font.pixelSize: 12
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            OutlinedTextField {
                id: taskField

                Layout.fillWidth: true
                labelText: qsTr("New task")
                onAccepted: root.addTask()
            }

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.rounding.full
                color: taskField.text.trim().length === 0 ? Appearance.applyAlpha(
                                                                Appearance.colors.colOnLayer0, 0.08) :
                                                            (addHover.containsMouse ?
                                                                 Appearance.colors.colPrimaryHover :
                                                                 Appearance.colors.colPrimary)

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "add"
                    iconSize: 22
                    color: taskField.text.trim().length === 0 ? Appearance.colors.colSubtext :
                                                                Appearance.colors.colOnPrimary
                }

                MouseArea {
                    id: addHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addTask()
                }
            }
        }

        Text {
            visible: TodoService.list.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: qsTr("Nothing planned yet")
            color: Appearance.colors.colSubtext
            font.family: Fonts.ui
            font.pixelSize: 13
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: taskColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: taskColumn

                width: parent.width
                spacing: 4

                Repeater {
                    model: root.pending

                    delegate: TaskRow {
                        required property var modelData

                        Layout.fillWidth: true
                        taskIndex: modelData.index
                        content: modelData.content
                        done: false
                    }
                }

                // Выполненные уходят вниз и тускнеют, но остаются на виду:
                // так видно, что за день сделано, и можно вернуть отметку.
                Rectangle {
                    visible: root.finished.length > 0 && root.pending.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 2
                    implicitHeight: 1
                    color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.12)
                }

                Repeater {
                    model: root.finished

                    delegate: TaskRow {
                        required property var modelData

                        Layout.fillWidth: true
                        taskIndex: modelData.index
                        content: modelData.content
                        done: true
                    }
                }
            }
        }
    }

    component TaskRow: Item {
        id: taskRow

        property int taskIndex: -1
        property string content: ""
        property bool done: false

        implicitHeight: 32

        MouseArea {
            id: rowHover

            anchors.fill: parent
            hoverEnabled: true
        }

        RowLayout {
            anchors.fill: parent
            spacing: 8

            // Кружок-отметка: клик переключает состояние.
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.rounding.full
                color: taskRow.done ? Appearance.colors.colPrimary : "transparent"
                border.width: taskRow.done ? 0 : 2
                border.color: checkHover.containsMouse ? Appearance.colors.colPrimary :
                                                         Appearance.applyAlpha(Appearance.colors.colOnLayer0,
                                                                               0.35)

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: taskRow.done
                    text: "check"
                    iconSize: 14
                    color: Appearance.colors.colOnPrimary
                }

                MouseArea {
                    id: checkHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TodoService.setDone(taskRow.taskIndex, !taskRow.done)
                }
            }

            Text {
                Layout.fillWidth: true
                text: taskRow.content
                color: taskRow.done ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer0
                font.family: Fonts.ui
                font.pixelSize: 14
                font.strikeout: taskRow.done
                elide: Text.ElideRight
            }

            // Удаление показывается только при наведении, чтобы список
            // не пестрел крестиками.
            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                opacity: rowHover.containsMouse || deleteHover.containsMouse ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.full
                    color: deleteHover.containsMouse ? Appearance.colors.colErrorContainer : "transparent"
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 14
                    color: deleteHover.containsMouse ? Appearance.colors.colOnErrorContainer :
                                                       Appearance.colors.colSubtext
                }

                MouseArea {
                    id: deleteHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TodoService.deleteItem(taskRow.taskIndex)
                }
            }
        }
    }
}

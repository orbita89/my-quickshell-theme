.pragma library

// Раскладка вкладки Dashboard — чистая функция, без QML.
//
// Dashboard состоит из двух частей:
//   колонка — виджеты друг под другом (порядок и набор из настроек);
//   плашка  — карусель карточек; под ней островок вырезает окно в фоне,
//             поэтому её положение должно быть известно точно.
//
// Плашка стоит справа или слева от колонки. Любая из частей может быть
// выключена; тогда вторая занимает всё место, а ширина островка сжимается.
//
// columnIds  включённые виджеты колонки сверху вниз (id из реестра)
// widgets    KeystoneHubRegistry.dashboardWidgets
// keyholeOn  плашка включена и в ней есть карточки
// side       "right" | "left" — сторона плашки
// metrics    { margin, spacing, columnWidth, keyholeWidth, keyholeHeight,
//              emptyHeight }
//
// Возвращает:
//   width, height        размер вкладки
//   innerHeight          высота без полей
//   stackVisible, stackX колонка и её левый край
//   keyholeVisible, keyholeX
//   items                { id: { y, height } } для каждого включённого виджета
//   empty                выключено всё — показать заглушку
function compute(columnIds, widgets, keyholeOn, side, metrics) {
    const byId = {};
    for (let index = 0; index < widgets.length; index += 1)
        byId[widgets[index].id] = widgets[index];

    const column = columnIds.filter(id => byId[id] !== undefined);
    const stackOn = column.length > 0;
    const m = metrics.margin;
    const s = metrics.spacing;

    if (!stackOn && !keyholeOn) {
        return {
            width: m * 2 + metrics.columnWidth,
            height: m * 2 + metrics.emptyHeight,
            innerHeight: metrics.emptyHeight,
            stackVisible: false,
            stackX: m,
            keyholeVisible: false,
            keyholeX: m,
            items: {},
            empty: true
        };
    }

    let natural = 0;
    let fillers = 0;
    for (let index = 0; index < column.length; index += 1) {
        natural += byId[column[index]].preferredHeight;
        if (byId[column[index]].fillHeight)
            fillers += 1;
    }
    if (column.length > 1)
        natural += s * (column.length - 1);

    const innerHeight = Math.max(stackOn ? natural : 0, keyholeOn ? metrics.keyholeHeight : 0);
    // Свободную высоту (плашка выше колонки) делят виджеты с fillHeight;
    // если таких нет, колонка просто короче плашки.
    const extra = fillers > 0 ? (innerHeight - natural) / fillers : 0;

    const items = {};
    let y = m;
    for (let index = 0; index < column.length; index += 1) {
        const widget = byId[column[index]];
        const height = widget.preferredHeight + (widget.fillHeight ? extra : 0);
        items[widget.id] = {
            y: y,
            height: height
        };
        y += height + s;
    }

    const keyholeLeft = side === "left";
    const both = stackOn && keyholeOn;
    return {
        width: m * 2 + (stackOn ? metrics.columnWidth : 0) + (keyholeOn ? metrics.keyholeWidth : 0) + (both ? s : 0),
        height: m * 2 + innerHeight,
        innerHeight: innerHeight,
        stackVisible: stackOn,
        stackX: both && keyholeLeft ? m + metrics.keyholeWidth + s : m,
        keyholeVisible: keyholeOn,
        keyholeX: both && !keyholeLeft ? m + metrics.columnWidth + s : m,
        items: items,
        empty: false
    };
}

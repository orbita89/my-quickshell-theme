import QtQuick
import qs.Modules.QuickSettings

Item {
    id: root

    property var screen: null

    clip: true

    function capturesWheelAt(x, y) {
        if (!quickSettings.capturesWheel)
            return false;

        const point = quickSettings.mapFromItem(root, x, y);
        return quickSettings.capturesWheelAt(point.x, point.y);
    }

    // ЛОКАЛЬНАЯ ПРАВКА: поверхность занимает карточку целиком.
    //
    // Раньше она рисовалась на холсте 420×572 и вся целиком масштабировалась
    // под карточку. Ограничителем всегда была высота: в доступные 398 px
    // влезало 0.7 холста, и расширение карточки по ширине ничего не меняло —
    // содержимое оставалось мелким, а по бокам копилась пустота.
    //
    // Раскладка внутри и так на ColumnLayout: ползунки и сетка плиток берут
    // свою естественную высоту, а остаток раньше уходил в распорку снизу.
    // Значит холст был не нужен — поверхность спокойно раскладывается по
    // фактическому размеру и рисуется в натуральную величину.
    QuickSettingsSurface {
        id: quickSettings

        anchors.fill: parent
        screen: root.screen
    }
}

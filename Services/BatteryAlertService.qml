pragma Singleton
import QtQuick
import Quickshell

// МОЙ МОДУЛЬ: предупреждения о низком заряде батареи.
//
//   15% и ниже — «Низкий заряд батареи», обычное уведомление;
//    7% и ниже — «Срочно подключите зарядку!», критическое: не пропадает,
//                пока его не закроют.
//
// Только при работе от батареи. Каждое предупреждение — один раз за разряд:
// снова «взводится», когда подключили зарядку или заряд поднялся выше 20%
// (запас, чтобы колебания 14↔15% не сыпали уведомлениями).
//
// Заряд — из PowerService (UPower), опросов нет: UPower сам сообщает об
// изменении. Создаётся из AppShell (BatteryAlertService.initialize()).
Singleton {
    id: root

    readonly property int warningPercent: 15
    readonly property int criticalPercent: 7
    readonly property int rearmPercent: 20

    readonly property bool batteryKnown: PowerService.present && isFinite(PowerService.percentage)
    readonly property real percent: root.batteryKnown ? Math.round(PowerService.percentage * 100) : NaN
    readonly property bool discharging: PowerService.onBattery
    // 0 — ещё не предупреждали, 1 — было предупреждение 15%, 2 — было 7%.
    property int alertedLevel: 0

    function initialize() {
        root.evaluate(root.percent, root.discharging);
    }

    // Новый уровень предупреждения по заряду. Чистая функция — её проверяют
    // без батареи: (процент, от батареи ли, прошлый уровень) → уровень.
    function levelFor(percent, discharging, previousLevel) {
        if (!isFinite(percent) || !discharging || percent > root.rearmPercent)
            return 0;
        if (percent <= root.criticalPercent)
            return 2;
        if (percent <= root.warningPercent)
            return Math.max(previousLevel, 1);
        return previousLevel;
    }

    function evaluate(percent, discharging) {
        const next = root.levelFor(percent, discharging, root.alertedLevel);
        if (next > root.alertedLevel)
            root.notify(next, percent);
        root.alertedLevel = next;
    }

    function notify(level, percent) {
        const critical = level >= 2;
        const title = critical ? qsTr("Plug in the charger now!") : qsTr("Low battery");
        const body = critical ? qsTr("%1% left — the laptop will shut down soon.").arg(Math.round(percent)) :
                                qsTr("%1% left. Connect the charger.").arg(Math.round(percent));
        Quickshell.execDetached(["notify-send", "-a", qsTr("Battery"), "-u", critical ? "critical" : "normal",
                                 "-i", critical ? "battery-caution" : "battery-low", "-t", critical ? "0" : "15000",
                                 title, body]);
    }

    onPercentChanged: root.evaluate(root.percent, root.discharging)
    onDischargingChanged: root.evaluate(root.percent, root.discharging)
}

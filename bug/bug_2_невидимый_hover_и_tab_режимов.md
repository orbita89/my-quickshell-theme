# Bug 2. Невидимый hover и отсутствие выделения Tab на кнопках режимов в Spotlight

Симптом: при наведении на кнопку Clipboard (и соседние: Apps, Wallpapers,
Files) в рельсе режимов строки поиска нет ни подсветки, ни перекраски;
выбор кнопки через Tab тоже никак не отображается.

## 1. Причина бага

Две независимые причины в `Modules/Launcher/SpotlightSearchBar.qml`:

1. **Двойное умножение альфы у hover.** Фон кнопки рисовался так:
   `Appearance.applyAlpha(root.style.hoverColor, 0.42)`. Но
   `SpotlightStyle.hoverColor` сам по себе уже полупрозрачный —
   `applyAlpha(m3surfaceContainerHighest, max(0.30, shellBackgroundOpacity))`.
   Итого итоговая альфа 0.42 × 0.30…1.0 ≈ **0.13 и меньше** — оттенок
   неразличим на размытой подложке окна.
2. **Tab-фокус не рисовался.** Свойство `logicalFocus`
   (`modeRailExpanded && modeFocusIndex === index`) в делегате объявлено,
   но использовалось только для `fill: 1` у иконки (`iconSelected`). Ни
   фона, ни кольца, ни обводки для него не было — логическое выделение
   клавиатурой оставалось невидимым.

## 2. Решение

В delegate `modeButton` (`SpotlightSearchBar.qml`):

- Фон переведён на стандартный для темы state-layer (образец —
  `Widgets/common/StyledMenuItem.qml`): непрозрачная краска
  `Appearance.colors.colOnSurface` плюс токены `Appearance.interaction` —
  `hoverStateLayerOpacity` (0.08) / `pressedStateLayerOpacity` (0.12), с
  плавным `Behavior on opacity`.
- Добавлено кольцо фокуса: `Rectangle` с `border.width: 2`,
  `border.color: Appearance.colors.colPrimary`, привязан к `logicalFocus`
  через opacity/scale с анимацией. Кольцо видно и поверх hover, и на
  активной кнопке; наведённая мышью кнопка больше не конфликтует с
  клавиатурным выделением.

Других мест с тем же удвоенным alpha-паттерном (`applyAlpha(*hoverColor`)
в проекте не нашлось.

## 3. Краткая информация (сделано)

**Сделано.** Оба дефекта исправлены в одном файле:

- `Modules/Launcher/SpotlightSearchBar.qml` — hover/pressed state-layer +
  кольцо Tab-фокуса (+39/−3 строк).
- `qmllint` (Qt 6.9.3) по файлу чистый, кроме ожидаемых предупреждений про
  пути `qs.*`-модулей Quickshell.
- В git ничего не коммитилось и не пушилось.

**Проверка.** Навести мышь на кнопку Clipboard в развёрнутом рельсе — фон
должен светлиться; нажать Tab в строке поиска — на кнопке появляется
кольцо из `colPrimary`, стрелки/Tab перемещают его, Enter активирует.
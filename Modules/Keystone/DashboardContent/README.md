# Вкладка Dashboard

Первая вкладка главного меню. Состоит из двух частей:

- **колонка** — виджеты друг под другом шириной 392 px (сейчас
  «Использование ресурсов» и «Календарь»);
- **плашка** (замочная скважина) — карусель карточек 462×480 px (быстрые
  настройки, помидор, секундомер, задачи). Под ней островок вырезает окно в фоне и
  размывает то, что под ним.

Пользователь включает и переставляет виджеты, включает плашку, выбирает её
сторону и карточки в Центре управления → Keystone → Главное меню.

## Файлы

| Файл | Что делает |
|---|---|
| `DashboardHubTab.qml` | Обёртка вкладки по контракту хаба (`../Hub/README.md`). Пробрасывает наружу геометрию плашки. |
| `DashboardContent.qml` | Раскладка: `Loader` на каждый виджет реестра, `Loader` плашки, заглушка «всё выключено». |
| `DashboardLayout.js` | Чистая функция `compute()` — все координаты и размеры. Без QML, проверяется в node. |
| `KeyholeCardCarousel.qml` | Карусель карточек плашки. |
| `Dashboard*Card.qml` | Карточки плашки. |
| `Widgets/<Имя>/` | Виджеты колонки, каждый в своей папке со своим README. |

## Раскладка

Все числа — в `DashboardLayout.compute()`; константы — в
`Common/KeystoneHubRegistry.qml` (`dashboardMargin` 20, `dashboardSpacing` 16,
`dashboardColumnWidth` 392, `keyholeWidth` 462, `keyholeHeight` 480).

- Высота = 20 + max(высота колонки, 480 если плашка есть) + 20.
- Виджеты с `fillHeight: true` делят свободную высоту, если плашка выше колонки.
- Ширина = 20 + колонка + 16 + плашка + 20 (отсутствующая часть и промежуток
  выпадают). По умолчанию 910×520.
- Плашка без карточек не показывается (и вырез не рисуется).
- Выключено всё — заглушка 392×200 с подсказкой.

Быстрая проверка расчёта:

```sh
node -e "eval(require('fs').readFileSync('Modules/Keystone/DashboardContent/DashboardLayout.js','utf8').replace('.pragma library',''));
console.log(compute(['resourceStats','calendar'],[{id:'resourceStats',preferredHeight:180},{id:'calendar',preferredHeight:284,fillHeight:true}],true,'right',{margin:20,spacing:16,columnWidth:392,keyholeWidth:462,keyholeHeight:480,emptyHeight:200}))"
```

## Как добавить виджет колонки (пошагово)

1. Создайте папку `Widgets/<Имя>/` и в ней `<Имя>.qml`. Корень — любой
   `Item`; размер ему задаёт `Loader` (ширина 392, высота из реестра), поэтому
   растягивайте содержимое на `parent` / `anchors.fill`.
2. Рядом положите `README.md` по образцу `Widgets/Calendar/README.md`.
3. Добавьте запись в `dashboardWidgets` в `Common/KeystoneHubRegistry.qml`:
   ```js
   ({
       "id": "<имя>",                  // латиница, навсегда: хранится в конфиге
       "title": qsTranslate("KeystoneHubRegistry", "<Подпись>"),
       "icon": "<значок Material Symbols>",
       "source": Qt.resolvedUrl("../Modules/Keystone/DashboardContent/Widgets/<Имя>/<Имя>.qml"),
       "preferredHeight": 200,
       "fillHeight": false,
       "services": [],                 // какие службы будит — для документации
       "defaultEnabled": true
   })
   ```
4. В `DashboardContent.qml` добавьте
   `import qs.Modules.Keystone.DashboardContent.Widgets.<Имя>` рядом с
   остальными — иначе «… is not a type».
5. Если виджет опрашивает систему (таймер, Process), сделайте опрос
   зависимым от включённости: см. `ProcessStatsService.active` — там
   `PersonalizationConfig.keystoneDashboardWidgetEnabled("<имя>")`.
6. Переводы и проверка — как в `../Hub/README.md`.

## Как добавить карточку плашки

1. Файл `Dashboard<Имя>Card.qml` в этой папке.
2. id в `keystoneKeyholeCardIds` и запись в `keystoneKeyholeCardOptions`
   (`Services/PersonalizationConfig.qml`).
3. `Loader { active: cardDelegate.cardId === "<имя>" … }` в делегате
   `KeyholeCardCarousel.qml`. Свойство `active` карточки
   (`cardDelegate.cardActive`) — видна ли она сейчас; по нему стоит
   останавливать таймеры.

## Частые ошибки

- Вырез в фоне не совпал с плашкой — менялись координаты плашки мимо
  `DashboardLayout.js`. Плашка и вырез обязаны считаться по одним числам
  (`keyholeCenterOffset`, `keyholeWidth`, `keyholeHeight`, `keyholeTopOffset`).
- Виджет асинхронный — у Dashboard все `Loader`'ы синхронные, иначе размер
  островка скачет на первом кадре.

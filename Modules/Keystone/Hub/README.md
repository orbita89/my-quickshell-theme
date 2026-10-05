# Главное меню (хаб островка Keystone)

Хаб — панель с вкладками, которая раскрывается из островка вверху экрана.
Сейчас в нём вкладки Dashboard, Media, Upload и Developer. Пользователь
включает, выключает и переставляет их в Центре управления → Keystone →
Главное меню.

## Из чего состоит

| Файл | Что делает |
|---|---|
| `Common/KeystoneHubRegistry.qml` | **Реестр**: список всех вкладок и виджетов Dashboard — id, подпись, значок, файл, размер, флаги. Только данные. |
| `Services/PersonalizationConfig.qml` | Что включено и в каком порядке (`keystone.hub` в `config/config.json`). Свойства `keystoneHubTabs`, `keystoneDashboardColumn`; функции `moveKeystoneHubTab`, `toggleKeystoneHubTab`, `removeKeystoneHubTab` и такие же для виджетов. |
| `Modules/Keystone/Hub/HubContent.qml` | Панель вкладок и их `Loader`'ы. Строит всё по реестру, вкладок «в лицо» не знает. |
| `Modules/Keystone/Styles/Shared/KeystoneSurface.qml` | Островок. Хранит id открытой вкладки (`hubTabId`, `activeHubTabId`), обрабатывает IPC, мышь, перетаскивание файлов, вырез под плашку. |
| `Modules/ControlCenter/KeystoneHubPage.qml` | Страница настроек «Главное меню». |
| `<папка вкладки>/<Имя>HubTab.qml` | Обёртка вкладки по единому контракту (ниже). |

Поток данных:

```
KeystoneHubRegistry (что бывает) ─┐
PersonalizationConfig (что включено) ─┴─> HubContent ──> Loader вкладки ──> <Имя>HubTab.qml
                                            ▲   │ tabRequested(id)
                         currentTabId       │   ▼
                                      KeystoneSurface (hubTabId)
```

## Контракт вкладки

Файл вкладки (`<Имя>HubTab.qml`) — это `Item`, у которого:

- `property var hub: null` — сюда HubContent передаёт себя. Из него можно
  читать `hub.player` (текущий плеер MPRIS), `hub.screen`, `hub.dragActive`
  (над островком тащат файл) и вызывать `hub.closeRequested()`.
  **Всегда проверяйте `hub` на null** (`root.hub ? root.hub.player : null`).
- `implicitWidth` / `implicitHeight` — размер области содержимого без панели
  вкладок. По нему раскрывается островок.
- необязательно `function finishDrop(addedCount)` — если вкладка принимает
  файлы (флаг `acceptsFileDrop`).

Вкладка создаётся при первом открытии и дальше живёт, пока её не выключат в
настройках. Выключенная вкладка не создаётся вовсе: её файл даже не
компилируется. Видимость: пока вкладка не открыта, она невидима
(`visible: false`) — опросы и анимации внутри стоит привязывать к `visible`.

## Как добавить вкладку (пошагово)

1. Создайте папку `Modules/Keystone/<Имя>Content/` и в ней содержимое
   вкладки, например `<Имя>Widget.qml`.
2. Рядом создайте обёртку `<Имя>HubTab.qml`:
   ```qml
   import QtQuick
   import qs.Modules.Keystone.<Имя>Content

   Item {
       id: root
       property var hub: null
       implicitWidth: 760
       implicitHeight: 480

       <Имя>Widget {
           anchors.fill: parent
       }
   }
   ```
3. Добавьте запись в `tabs` в `Common/KeystoneHubRegistry.qml`:
   ```js
   ({
       "id": "<имя>",                 // латиница, навсегда: хранится в конфиге
       "title": qsTranslate("KeystoneHubRegistry", "<Подпись>"),
       "icon": "<значок Material Symbols>",
       "source": Qt.resolvedUrl("../Modules/Keystone/<Имя>Content/<Имя>HubTab.qml"),
       "width": 760, "height": 480,   // те же числа, что implicit* в обёртке
       "asynchronous": true,
       "stickyOpen": false,
       "acceptsFileDrop": false,
       "defaultEnabled": true
   })
   ```
4. В `HubContent.qml` добавьте `import qs.Modules.Keystone.<Имя>Content`
   рядом с остальными. **Без этого Quickshell не зарегистрирует папку**, и в
   журнале появится «… is not a type».
5. Переведите подпись: `cmake --build build --target update_translations`,
   впишите перевод в `i18n/clavis_ru_RU.ts`, `scripts/build-native.sh ClavisI18n`.
6. Проверьте (раздел «Проверка» ниже). Конфиги пользователей менять не нужно:
   новая вкладка сама допишется в их порядок и будет включена.

## Флаги реестра

- `asynchronous` — создавать вкладку в фоне. У Dashboard `false`: она
  открывается первой, асинхронная дала бы скачок размера островка.
- `stickyOpen` — не закрывать хаб, когда курсор ушёл с островка (нужно,
  чтобы донести файл из файлового менеджера).
- `acceptsFileDrop` — перетаскивание файла на островок открывает вкладку.
  Сейчас это только Upload: логика drop в `KeystoneSurface.qml` (DropArea
  `cloudUploadDropArea`) завязана на `CloudUploadService`.
- `defaultEnabled: false` — новая вкладка у существующих пользователей
  появится выключенной.

## Наведение и клики по островку

Действия мыши (Центр управления → Keystone → Действия мыши) ссылаются на
вкладки: `hub` → последняя открытая вкладка (`hubTabId` в KeystoneSurface,
помнится до перезапуска оболочки), `dashboard` → Dashboard, `library` →
Media, `upload` → Upload. Если
вкладка выключена, действие открывает хаб на **первой включённой** вкладке
(по порядку из настроек) — иначе наведение перестало бы открывать меню.
Логика — `activateMouseAction` в `Styles/Shared/KeystoneSurface.qml`.

IPC строже: `dashboard` и `media` для выключенной вкладки ничего не
открывают и отвечают `…_DISABLED`; `hub` открывает первую включённую.

## IPC

```
quickshell -c my-quickshell-theme ipc call keystone hub        # HUB_OPENED / HUB_CLOSED / HUB_EMPTY
quickshell -c my-quickshell-theme ipc call keystone dashboard  # … / DASHBOARD_DISABLED
quickshell -c my-quickshell-theme ipc call keystone media      # … / MEDIA_DISABLED
quickshell -c my-quickshell-theme ipc call control-center openSetting keystone.hub.section.tabs
```

## Частые ошибки

- **«X is not a type»** в журнале — папка вкладки не импортирована в
  `HubContent.qml` (шаг 4), либо в обёртке нет `import qs.Modules.Keystone.<папка>`.
- **Островок дёргается при открытии** — `width`/`height` в реестре не
  совпадают с `implicitWidth`/`implicitHeight` обёртки.
- **Вкладка пропала после перестановки** — нельзя делать `Repeater` по
  списку включённых вкладок для `Loader`'ов: он пересоздаёт делегаты.
  Модель содержимого — статичный `KeystoneHubRegistry.tabs`.
- **Номер вкладки вместо id** — вкладки адресуются только строковым id
  (`"upload"`), никаких `hubTabIndex === 2`.

## Проверка

- `qmllint <изменённые файлы>`
- запущенная оболочка перезагружается сама; журнал:
  `quickshell-bin log --pid $(pgrep -x quickshell-bin) -t 50`
- IPC выше (каждую команду дважды: открыть и закрыть)
- выключить вкладку в настройках → её нет на панели, IPC отвечает `…_DISABLED`

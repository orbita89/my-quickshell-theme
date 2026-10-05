# Памятка для ИИ-ассистентов

Оболочка рабочего стола на Quickshell (QML) для композитора niri, своя
сборка на базе Clavis. Комментарии, документация и сообщения коммитов —
по-русски. Подробности для людей — `README.md` и `INSTALL.md`.

## Карта

| Где | Что |
|---|---|
| `shell.qml`, `AppShell.qml` | Точка входа; IPC-обработчики `spotlight`, `wallpaper`, `control-center`, `lock`. |
| `Common/` | Синглтоны без логики: размеры, цвета, пути (`Paths`), реестры (`KeystoneHubRegistry`), `settings-routes.json`. |
| `Services/` | Синглтоны с логикой и состоянием: настройки (`PersonalizationConfig`, `UiPreferences`), системные службы. **Службы не импортируют `Modules`.** |
| `Modules/` | Окна и панели: `Bar`, `Keystone` (островок и главное меню), `ControlCenter` (настройки), `Sidebars`, `Launcher` (Spotlight), `Lock`, `Wallpaper`… |
| `Widgets/`, `Components/` | Переиспользуемые элементы (`SettingsRow`, `StyledSwitch`, `SortableMultiSelectField`, `MaterialSymbol`…). |
| `core/` | C++-плагины QML (`Clavis.*`), собираются `scripts/build-native.sh`. |
| `config/` | Настройки пользователя (в git не входят, создаются сами). |
| `i18n/clavis_ru_RU.ts` | Русский перевод (единственный файл в `i18n/`, который хранится в git). |

## Главное меню (хаб островка)

Модульное, настраивается пользователем. Начните с
`Modules/Keystone/Hub/README.md` (вкладки) и
`Modules/Keystone/DashboardContent/README.md` (виджеты Dashboard). Там
пошаговые рецепты «как добавить вкладку / виджет / карточку».

## Правила, о которые легко споткнуться

- **Регистрация модулей Quickshell.** Папка становится модулем
  `qs.<путь.через.точки>`, только если её где-то импортируют. Файл,
  загруженный по пути (`Loader.source`), не видит соседей своей папки, пока
  папку никто не импортировал → «X is not a type».
- **Настройки** — `PersonalizationConfig` (`config/config.json`): свойство,
  функция-сеттер с `save()`, запись в `toJson()`, чтение и нормализация в
  `loadFromObject()`. Старые и испорченные значения должны чиниться
  нормализацией, а не падать.
- **Новая страница или раздел настроек:**
  - маршрут в `Common/settings-routes.json`;
  - `SettingsSearchAnchor` с однострочным `declaration: '{…}'`;
  - затем `python3 scripts/dev/generate-search-catalog.py`.
  Сгенерированный `Common/generated/SearchCatalog.js` коммитится.
- **Переводы:** строки в `qsTr()`. Затем:
  1. `cmake --build build --target update_translations`;
  2. впишите перевод в `i18n/clavis_ru_RU.ts` вместо `type="unfinished"`;
  3. `scripts/build-native.sh ClavisI18n`;
  4. `systemctl --user restart my-shell.service`.
- **Ресурсы.** Пользователю важна экономия памяти и процессора:
  - тяжёлое создаётся лениво (`Loader` с `active`);
  - выключенное в настройках не создаётся вовсе;
  - таймеры и опросы привязаны к видимости или включённости.
  Замер: `scripts/memory-report.sh`.
- Локальные изменения относительно Clavis помечены комментариями
  `ЛОКАЛЬНАЯ ПРАВКА:` / `МОЁ ДОБАВЛЕНИЕ:` с объяснением «почему».

## Проверка

```sh
qmllint <изменённые .qml>
python3 scripts/dev/generate-search-catalog.py --check
# запущенная оболочка перезагружает QML сама; журнал текущего процесса:
quickshell-bin log --pid $(pgrep -x quickshell-bin) -t 50
# главное меню
quickshell -c my-quickshell-theme ipc call keystone hub
quickshell -c my-quickshell-theme ipc call keystone dashboard
# раздел настроек по id из каталога поиска
quickshell -c my-quickshell-theme ipc call control-center openSetting keystone.hub.section.tabs
grim -o "$(niri msg -j focused-output | python3 -c 'import json,sys;print(json.load(sys.stdin)["name"])')" /tmp/shot.png
```

`quickshell-bin log -c <конфиг>` может показать журнал старого экземпляра, поэтому журнал надёжнее читать по `--pid`. Одинаковые предупреждения Quickshell повторно не пишет: чтобы увидеть журнал с чистого листа, перезапустите службу.

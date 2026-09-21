# Моя оболочка для niri

Самостоятельный проект на базе [Clavis Shell](https://github.com/StatIndet/quickshell)
(версия 2026.9.12), работает на движке [Quickshell](https://quickshell.org/).

## Запуск

    quickshell -c my

Автозапуск — служба `my-shell.service`.

## Окружение

Собрано вручную, системными пакетами не ставится:

| Компонент | Путь | Зачем |
|---|---|---|
| Quickshell 0.3.1 | `~/.local/bin/quickshell` (обёртка) | движок; системного пакета нет |
| Qt 6.9.3 | `~/.local/opt/Qt/6.9.3` | нужен движку и теме; в Ubuntu 24.04 только 6.4.2 |
| key-cli | `~/.local/bin/key` | буфер обмена, файлы, запись экрана |
| keytop | `~/.local/bin/keytop` (обёртка) | системный монитор |
| libcava 0.9.1 | `~/.local/lib/libcava.so` | визуализатор звука; в Ubuntu пакета нет |
| M3Shapes | `~/.local/lib/qt6/qml/M3Shapes` | QML-плагин фигур |
| cliphist | `~/.local/bin/cliphist` (обёртка) | чинит несовместимость с версией 0.4.0 из Ubuntu |
| backlight-set | `~/.local/bin/backlight-set` | яркость подсветки: brightnessctl здесь без прав |

Нативные модули проекта (`Clavis.*`) собираются из каталога `core/`
и ставятся в `~/.local/lib/qt6/qml`.

### Правка в плагине Clavis.Gamma

Исходники native-модулей лежат в `~/.local/src/clavis`. В
`core/plugin/gamma/src/` поднят предел размера таблицы гаммы с 65536 до
1048576 (`gamma_backend.cpp` и `gamma_curve.cpp`). Intel Tiger Lake отдаёт
сегментированную таблицу на 262145 значений, старая проверка браковала её
молча: плагин сам помечал управление как `failed` и уничтожал его, поэтому
ночной режим не включался, а в логе композитора не было ни строчки.

Правка живёт вне этого репозитория. После `git pull` в `~/.local/src/clavis`
её нужно наложить заново и пересобрать:

```sh
cmake --build ~/.local/src/clavis/build --target ClavisGamma
cp ~/.local/src/clavis/build/qml/Clavis/Gamma/libClavisGamma.so \
   ~/.local/lib/qt6/qml/Clavis/Gamma/
```

Проверить, что гамма применяется: при включённом ночном режиме сторонний
клиент получает отказ, потому что управление держит панель.

```sh
WAYLAND_DEBUG=1 wlsunset -T 3001 -t 3000   # увидите zwlr_gamma_control_v1.failed
```

## Мои отличия от оригинала

- Убран режим поиска по файлам (`Modules/Launcher`, `Common/functions`).
- Отключены модули, которые дублируют уже работающие программы
  или не нужны — см. комментарии в `AppShell.qml`.

## Обновления оригинала

Оригинал лежит рядом: `~/.config/quickshell/clavis` (там свой git с
remote `upstream`). Посмотреть, что изменил автор, и перенести нужное:

    cd ~/.config/quickshell/clavis
    git fetch upstream && git diff HEAD upstream/main -- Modules/Launcher

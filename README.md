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

### Native-модули

Исходники модулей `Clavis.*` лежат в этом репозитории, в `core/`. Раньше они
собирались из апстримного дерева `~/.local/src/clavis`, и правки там
терялись при обновлении — теперь C++ правится вместе с QML и попадает в те же
коммиты.

```sh
scripts/build-native.sh                 # собрать всё и поставить
scripts/build-native.sh ClavisGamma     # только один модуль
systemctl --user restart my-shell.service
```

Скрипт кладёт собранное в `~/.local/lib/qt6/qml/Clavis` — туда, откуда модули
берёт обёртка `~/.local/bin/quickshell`. Дерево сборки `build/` в git не
попадает.

Сборке нужен Qt 6.9.3 из `~/.local/opt/Qt`, заголовки из
`~/.local/opt/devroot/usr` и системные dev-пакеты; они уже стоят с первой
сборки. Апстримное дерево `~/.local/src/clavis` оставлено только как образец
для сравнения — на сборку и работу оболочки оно больше не влияет. Общесистемную установку (`/etc/xdg`, юниты systemd) апстрим-скрипты
делают, а мы нет: конфигом служит сам репозиторий, служба своя.

### Мои правки в core

- `core/plugin/gamma/src/` — предел размера таблицы гаммы поднят с 65536 до
  1048576 (`gamma_backend.cpp`, `gamma_curve.cpp`). Intel Tiger Lake отдаёт
  сегментированную таблицу на 262145 значений, старая проверка браковала её
  молча: плагин сам помечал управление как `failed` и уничтожал его, ничего
  не отправив композитору. Из-за этого не работал ночной режим, а в логе niri
  не было ни строчки.

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

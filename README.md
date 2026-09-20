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

Нативные модули проекта (`Clavis.*`) собираются из каталога `core/`
и ставятся в `~/.local/lib/qt6/qml`.

## Мои отличия от оригинала

- Убран режим поиска по файлам (`Modules/Launcher`, `Common/functions`).
- Отключены модули, которые дублируют уже работающие программы
  или не нужны — см. комментарии в `AppShell.qml`.

## Обновления оригинала

Оригинал лежит рядом: `~/.config/quickshell/clavis` (там свой git с
remote `upstream`). Посмотреть, что изменил автор, и перенести нужное:

    cd ~/.config/quickshell/clavis
    git fetch upstream && git diff HEAD upstream/main -- Modules/Launcher

#!/bin/sh
# Сборка и установка native-модулей оболочки (Clavis.Cava, Clavis.Gamma,
# Clavis.Niri и остальные из core/plugin).
#
# Раньше они собирались из апстримного дерева ~/.local/src/clavis, и правки
# там терялись при обновлении. Теперь исходники лежат в этом репозитории
# рядом с QML, а собранные модули кладутся туда, откуда их берёт обёртка
# ~/.local/bin/quickshell (QML2_IMPORT_PATH).
#
# Использование:
#   scripts/build-native.sh              собрать и поставить всё
#   scripts/build-native.sh ClavisGamma  собрать и поставить одну цель
#
# После установки оболочку нужно перезапустить:
#   systemctl --user restart my-shell.service

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
build="$root/build"
qt="$HOME/.local/opt/Qt/6.9.3/gcc_64"
install_dir="$HOME/.local/lib/qt6/qml"

if [ ! -d "$qt" ]; then
    echo "Не найден Qt: $qt" >&2
    exit 1
fi

# Перенастраиваем только когда сборки ещё нет: повторный запуск cmake на
# готовом дереве занимает время и ничего не меняет.
if [ ! -f "$build/build.ninja" ]; then
    cmake -S "$root" -B "$build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
        -DCMAKE_PREFIX_PATH="$qt;$HOME/.local/opt/devroot/usr;/usr"
fi

if [ $# -gt 0 ]; then
    cmake --build "$build" --target "$@"
else
    cmake --build "$build"
fi

# Ставим только модули QML. Общесистемный конфиг и юниты systemd из апстрима
# нам не нужны: конфигом служит сам репозиторий, служба своя.
mkdir -p "$install_dir"
cp -r "$build/qml/Clavis" "$install_dir/"
echo "Модули установлены в $install_dir/Clavis"
echo "Перезапустить оболочку: systemctl --user restart my-shell.service"

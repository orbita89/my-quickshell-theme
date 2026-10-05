#!/bin/sh
# Установка окружения оболочки на чистую машину.
#
# В репозитории лежит код и настройки, но не бинарники: движок Quickshell,
# Qt 6.9.3, keytop, key-cli, libcava, M3Shapes и matugen собираются отдельно
# и ставятся в ~/.local. Этот скрипт проходит все шаги по порядку.
#
# ЧЕСТНОЕ ПРЕДУПРЕЖДЕНИЕ. Скрипт восстановлен по тому, как собрано на этой
# машине (Ubuntu 24.04), и на чистой системе целиком не прогонялся — здесь
# уже всё установлено. Считайте его подробной инструкцией, которая умеет
# выполняться сама: запускайте по шагам и смотрите на вывод.
#
# Использование:
#   scripts/install-fresh.sh --check        показать, чего не хватает
#   scripts/install-fresh.sh                поставить недостающее
#   scripts/install-fresh.sh qt quickshell  только выбранные шаги
#   scripts/install-fresh.sh niri           только подключить фрагменты niri
#
# Шаги: apt, qt, devroot, cava, quickshell, m3shapes, keytop, keycli,
#       matugen, fonts, native, links, niri

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
opt="$HOME/.local/opt"
src="$HOME/.local/src"
bin="$HOME/.local/bin"
lib="$HOME/.local/lib"
qt_version=6.9.3
qt_root="$opt/Qt/$qt_version/gcc_64"
devroot="$opt/devroot"

check_only=false
[ "${1:-}" = "--check" ] && { check_only=true; shift; }
steps=${*:-"apt qt devroot cava quickshell m3shapes keytop keycli matugen fonts native links niri"}

want() {
    for s in $steps; do [ "$s" = "$1" ] && return 0; done
    return 1
}

have() {
    if [ -e "$2" ]; then
        printf '  есть      %s\n' "$1"
        return 0
    fi
    printf '  НЕ ХВАТАЕТ %s\n' "$1"
    return 1
}

# Пакеты Ubuntu. Заголовки, которых в системе нет отдельными пакетами, ниже
# распаковываются в devroot без root.
APT_PACKAGES="git cmake ninja-build pkgconf build-essential python3-venv
    libwayland-dev wayland-protocols libxkbcommon-dev libpipewire-0.3-dev
    libdrm-dev libpam0g-dev libjemalloc-dev libfftw3-dev
    libgtk-layer-shell-dev libdbusmenu-glib-dev libdbusmenu-gtk3-dev
    libpolkit-agent-1-dev libpolkit-gobject-1-dev
    power-profiles-daemon brightnessctl cliphist btop jq"

# То же самое, но только заголовки: ставится распаковкой .deb в devroot,
# когда нет права писать в /usr.
DEVROOT_PACKAGES="libdrm-dev libpam0g-dev libjemalloc-dev libfftw3-dev
    libgtk-layer-shell-dev libdbusmenu-glib-dev libdbusmenu-gtk3-dev
    libpolkit-agent-1-dev libpolkit-gobject-1-dev"

step_apt() {
    if $check_only; then
        printf 'apt:\n'
        for p in cmake ninja pkgconf brightnessctl btop jq; do
            command -v "$p" >/dev/null 2>&1 && printf '  есть      %s\n' "$p" || printf '  НЕ ХВАТАЕТ %s\n' "$p"
        done
        return 0
    fi
    printf 'Нужны права root. Выполните сами:\n\n    sudo apt install %s\n\n' "$(echo $APT_PACKAGES)"
    printf 'Нажмите Enter, когда поставите, или Ctrl-C чтобы прервать.\n'
    read -r _ || true
}

step_qt() {
    $check_only && { printf 'Qt %s:\n' "$qt_version"; have "$qt_root" "$qt_root"; return 0; }
    [ -d "$qt_root" ] && { printf 'Qt уже стоит\n'; return 0; }
    # aqtinstall качает официальные сборки Qt без учётной записи.
    [ -d "$opt/aqt-venv" ] || python3 -m venv "$opt/aqt-venv"
    "$opt/aqt-venv/bin/pip" install -q --upgrade aqtinstall
    "$opt/aqt-venv/bin/aqt" install-qt linux desktop "$qt_version" linux_gcc_64 \
        -O "$opt/Qt" -m qtshadertools qtwayland qtdeclarative qttools
}

step_devroot() {
    $check_only && { printf 'devroot:\n'; have "$devroot/usr/include" "$devroot/usr/include"; return 0; }
    mkdir -p "$devroot"
    tmp=$(mktemp -d)
    ( cd "$tmp" && apt-get download $DEVROOT_PACKAGES && for deb in *.deb; do dpkg-deb -x "$deb" "$devroot"; done )
    rm -rf "$tmp"
}

step_cava() {
    # Библиотека libcava нужна плагину Clavis.Cava. Версия строго 0.9.1:
    # в 1.0.0 у cava_init появился лишний аргумент и плагин не собирается.
    $check_only && { printf 'libcava:\n'; have "$lib/libcava.so" "$lib/libcava.so"; return 0; }
    [ -f "$lib/libcava.so" ] && { printf 'libcava уже собрана\n'; return 0; }
    [ -d "$src/cava" ] || git clone --branch 0.9.1 --depth 1 https://github.com/karlstav/cava.git "$src/cava"
    ( cd "$src/cava" && ./autogen.sh && ./configure --prefix="$HOME/.local" && make -j"$(nproc)" && make install )
    mkdir -p "$devroot/usr/include/cava" "$devroot/usr/lib/x86_64-linux-gnu/pkgconfig"
    cp -f "$src/cava/cavacore.h" "$devroot/usr/include/cava/" 2>/dev/null || true
}

step_quickshell() {
    $check_only && { printf 'Quickshell:\n'; have "$bin/quickshell-bin" "$bin/quickshell-bin"; return 0; }
    [ -x "$bin/quickshell-bin" ] && { printf 'Quickshell уже собран\n'; return 0; }
    [ -d "$src/quickshell" ] || git clone https://github.com/outfoxxed/quickshell.git "$src/quickshell"
    ( cd "$src/quickshell" && git checkout c6a516096dd84d5255b409482eb4bf740b952f88 &&
      cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$qt_root" -DCMAKE_INSTALL_PREFIX="$HOME/.local" &&
      cmake --build build && cmake --install build )
    [ -x "$bin/quickshell" ] && [ ! -L "$bin/quickshell" ] && mv "$bin/quickshell" "$bin/quickshell-bin"
}

step_m3shapes() {
    $check_only && { printf 'M3Shapes:\n'; have "$lib/qt6/qml/M3Shapes" "$lib/qt6/qml/M3Shapes"; return 0; }
    [ -d "$lib/qt6/qml/M3Shapes" ] && { printf 'M3Shapes уже стоит\n'; return 0; }
    [ -d "$src/m3shapes" ] || git clone https://github.com/soramanew/m3shapes.git "$src/m3shapes"
    ( cd "$src/m3shapes" && cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$qt_root" -DCMAKE_INSTALL_PREFIX="$HOME/.local" &&
      cmake --build build && cmake --install build )
}

step_keytop() {
    $check_only && { printf 'keytop:\n'; have "$bin/keytop-bin" "$bin/keytop-bin"; return 0; }
    [ -x "$bin/keytop-bin" ] && { printf 'keytop уже собран\n'; return 0; }
    [ -d "$src/keytop" ] || git clone https://github.com/StatIndet/keytop.git "$src/keytop"
    ( cd "$src/keytop" && cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$qt_root;$devroot/usr;/usr" -DCMAKE_INSTALL_PREFIX="$HOME/.local" &&
      cmake --build build && cmake --install build )
    [ -x "$bin/keytop" ] && [ ! -L "$bin/keytop" ] && mv "$bin/keytop" "$bin/keytop-bin"
}

step_keycli() {
    $check_only && { printf 'key-cli:\n'; have "$opt/key-venv/bin/key" "$opt/key-venv/bin/key"; return 0; }
    [ -x "$opt/key-venv/bin/key" ] && { printf 'key-cli уже стоит\n'; return 0; }
    [ -d "$src/key-cli" ] || git clone https://github.com/StatIndet/key-cli.git "$src/key-cli"
    python3 -m venv "$opt/key-venv"
    "$opt/key-venv/bin/pip" install -q "$src/key-cli"
    ln -sfn "$opt/key-venv/bin/key" "$bin/key"
}

step_matugen() {
    $check_only && { printf 'matugen:\n'; have "$bin/matugen" "$bin/matugen"; return 0; }
    command -v matugen >/dev/null 2>&1 && { printf 'matugen уже стоит\n'; return 0; }
    command -v cargo >/dev/null 2>&1 || { printf 'Нужен Rust: https://rustup.rs\n'; return 1; }
    cargo install matugen --root "$HOME/.local" --locked
}

step_fonts() {
    font_dir="$HOME/.local/share/fonts"
    $check_only && { printf 'шрифты:\n'; fc-list 2>/dev/null | grep -qi "Material Symbols Rounded" &&
        printf '  есть      Material Symbols Rounded\n' || printf '  НЕ ХВАТАЕТ Material Symbols Rounded\n'; return 0; }
    mkdir -p "$font_dir"
    if ! fc-list | grep -qi "Material Symbols Rounded"; then
        curl -fsSL -o "$font_dir/material-symbols-rounded.ttf" \
            "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
        fc-cache -f "$font_dir" >/dev/null
    fi
    printf 'Шрифт значков на месте. JetBrainsMono Nerd Font ставится с nerdfonts.com, он нужен только для цифр.\n'
}

step_native() {
    $check_only && { printf 'модули Clavis.*:\n'; have "$lib/qt6/qml/Clavis" "$lib/qt6/qml/Clavis"; return 0; }
    "$root/scripts/build-native.sh"
}

step_links() {
    $check_only && { printf 'ссылки на системные файлы:\n'; "$root/scripts/install-system.sh" --check; return 0; }
    "$root/scripts/install-system.sh"
    systemctl --user enable my-shell.service
    printf 'Запустить: systemctl --user start my-shell.service\n'
}

# МОЁ ДОБАВЛЕНИЕ: фрагменты Clavis в конфиге niri. Без них часть настроек
# в центре управления выключена: тема и размер курсора (cursor), обои обзора
# (layer-rules), размытие (effects). Раньше их подключали кнопкой
# «Настроить» на каждой странице по отдельности.
#
# Подключается то же, что и кнопкой: создаётся ~/.config/niri/clavis/<имя>.kdl
# и в конец config.kdl дописывается include (с резервной копией и проверкой
# `niri validate`). Уже подключённые фрагменты не трогаются.
#
# binds и outputs не подключаются нарочно: первый заменил бы свои горячие
# клавиши набором Clavis, второй — раскладку мониторов из config.kdl.
#
# Курсор подключается с текущими XCURSOR_THEME/XCURSOR_SIZE сессии, чтобы
# ничего не поменялось. Дальше значения задаёт оболочка (Тема → Тема курсора).
niri_fragments="effects layer-rules cursor"

step_niri() {
    command -v niri >/dev/null 2>&1 || { printf 'niri не найден — фрагменты подключать некуда.\n'; return 0; }
    python3 - "$root/scripts/system/niri_config.py" "$check_only" $niri_fragments <<'PYEOF'
import json, os, subprocess, sys

script, check_only, *features = sys.argv[1:]
check_only = check_only == "true"

def call(request):
    out = subprocess.run(["python3", script, json.dumps(request)], capture_output=True, text=True).stdout
    return json.loads(out or "{}")

status = call({"operation": "status"})
if status.get("error"):
    sys.exit("niri_config: " + status["error"])
fragments = status.get("fragments", {})

print("фрагменты niri:")
for feature in features:
    state = fragments.get(feature, {}).get("state", "unknown")
    if state == "ready":
        print("  есть       ", feature)
        continue
    if check_only:
        print("  НЕ ХВАТАЕТ  %s (%s)" % (feature, state))
        continue
    request = {"operation": "setup", "feature": feature}
    if feature == "cursor":
        size = os.environ.get("XCURSOR_SIZE", "24")
        request.update(theme=os.environ.get("XCURSOR_THEME", ""), size=int(size) if size.isdigit() else 24,
                       hideTyping=False, hideAfter=0)
    result = call(request)
    if result.get("error"):
        print("  ОШИБКА      %s: %s" % (feature, result["error"]))
        continue
    state = result.get("fragments", {}).get(feature, {}).get("state", "unknown")
    print("  подключён   %s (%s)" % (feature, state))
PYEOF
    step_niri_autostart
}

# МОЁ ДОБАВЛЕНИЕ: автозапуск программ пользователя (~/.config/autostart) —
# из niri, см. system/bin/clavis-autostart. Строка дописывается в конец
# config.kdl один раз, с резервной копией и проверкой `niri validate`.
step_niri_autostart() {
    command -v niri >/dev/null 2>&1 || return 0
    config="${NIRI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl}"
    [ -f "$config" ] || { printf 'нет %s — автозапуск подключать некуда.\n' "$config"; return 0; }
    if grep -q 'clavis-autostart' "$config"; then
        printf '  есть        автозапуск программ (clavis-autostart)\n'
        return 0
    fi
    if $check_only; then
        printf '  НЕ ХВАТАЕТ  автозапуск программ (clavis-autostart)\n'
        return 0
    fi
    backup="$config.bak-autostart-$(date +%Y%m%d-%H%M%S)"
    cp -- "$config" "$backup"
    printf '\n// Автозапуск программ из ~/.config/autostart (Настройки → Автозапуск).\n// Подключено scripts/install-fresh.sh niri, см. system/bin/clavis-autostart.\nspawn-at-startup "%s/.local/bin/clavis-autostart"\n' "$HOME" >> "$config"
    if niri validate -c "$config" >/dev/null 2>&1; then
        printf '  подключён   автозапуск программ (копия: %s)\n' "$backup"
    else
        cp -- "$backup" "$config"
        printf '  ОШИБКА      автозапуск: niri validate не принял конфиг, вернул как было\n'
    fi
}

for name in apt qt devroot cava quickshell m3shapes keytop keycli matugen fonts native links niri; do
    want "$name" || continue
    "step_$name"
done

$check_only && printf '\nНедостающее ставится тем же скриптом без --check.\n'
exit 0

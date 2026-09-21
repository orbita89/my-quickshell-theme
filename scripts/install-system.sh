#!/bin/sh
# Связывает системные файлы оболочки с этим репозиторием.
#
# Зачем. Оболочке нужны не только QML и native-модули: её запускает служба
# systemd, а несколько обёрток в ~/.local/bin подставляют пути к Qt и чинят
# чужие несовместимости. Всё это лежало снаружи репозитория — правки там
# не попадали в коммиты и терялись. Теперь исходники живут в system/, а
# рабочие места превращаются в ссылки сюда: правишь в репозитории, работает
# сразу, история сохраняется.
#
# Что связывается:
#   system/systemd/my-shell.service -> ~/.config/systemd/user/
#   system/bin/quickshell           -> ~/.local/bin/   (пути к Qt 6.9.3 и модулям)
#   system/bin/keytop               -> ~/.local/bin/   (то же для системного монитора)
#   system/bin/cliphist             -> ~/.local/bin/   (обход несовместимости версий)
#   system/bin/backlight-set        -> ~/.local/bin/   (яркость через logind)
#   ~/.local/bin/qs                 -> quickshell      (был отдельной копией)
#
# Обычные файлы, которые окажутся на пути, не удаляются, а сохраняются
# рядом с суффиксом .bak-ГГГГММДД-ЧЧММСС.
#
# Использование:
#   scripts/install-system.sh            связать
#   scripts/install-system.sh --check    только показать, что не совпадает

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
bin_dir="$HOME/.local/bin"
unit_dir="$HOME/.config/systemd/user"
check_only=false
[ "${1:-}" = "--check" ] && check_only=true

stamp=$(date +%Y%m%d-%H%M%S)
changed=false

link() {
    source_path=$1
    target_path=$2

    if [ -L "$target_path" ] && [ "$(readlink -f "$target_path")" = "$source_path" ]; then
        return 0
    fi

    changed=true
    if [ "$check_only" = true ]; then
        echo "не связан: $target_path"
        return 0
    fi

    if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
        mv -- "$target_path" "$target_path.bak-$stamp"
        echo "сохранил прежний: $target_path.bak-$stamp"
    fi
    mkdir -p -- "$(dirname -- "$target_path")"
    ln -sfn -- "$source_path" "$target_path"
    echo "связал: $target_path"
}

for name in quickshell keytop cliphist backlight-set; do
    link "$root/system/bin/$name" "$bin_dir/$name"
done

# qs был точной копией обёртки quickshell; держим одну и ту же.
link "$root/system/bin/quickshell" "$bin_dir/qs"

link "$root/system/systemd/my-shell.service" "$unit_dir/my-shell.service"

if [ "$check_only" = true ]; then
    [ "$changed" = false ] && echo "всё связано"
    exit 0
fi

if [ "$changed" = true ]; then
    systemctl --user daemon-reload
    echo "Готово. Применить изменения службы: systemctl --user restart my-shell.service"
else
    echo "всё уже связано"
fi

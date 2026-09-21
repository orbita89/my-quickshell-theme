#!/bin/sh
# Сколько памяти занимает оболочка и на что она уходит.
#
# Зачем. Оболочка держала 600 МБ, и на глаз было не понять, утечка это или
# такова цена содержимого. Скрипт отвечает на оба вопроса: показывает
# разбивку по областям памяти и умеет измерять «пол» — сколько занимает
# пустая оболочка на этом же движке.
#
# Что важно знать про цифры:
#   RSS      всё, что сейчас в памяти, включая разделяемое с другими
#            программами (библиотеки Mesa, шрифты) — завышает вклад оболочки;
#   PSS      разделяемое поделено между теми, кто им пользуется — честнее;
#   Private  только наше, чужого здесь нет — по нему видно утечку.
#
# Использование:
#   scripts/memory-report.sh            разбивка текущего процесса
#   scripts/memory-report.sh --floor    плюс замер пустой оболочки
#   scripts/memory-report.sh --watch 60 следить минуту, растёт ли

set -eu

# Имя процесса, а не строка запуска: pgrep -f поймал бы и эту команду,
# в которой имя упоминается.
pid=$(pgrep -x quickshell-bin | head -1 || true)
[ -n "$pid" ] || { echo "Оболочка не запущена" >&2; exit 1; }

mode=${1:-}

summary() {
    awk '/^Rss:/ {r=$2} /^Pss:/ {p=$2} /^Private_Dirty:/ {d=$2} /^Swap:/ {s=$2}
        END {printf "  RSS            %8.1f МБ\n  PSS            %8.1f МБ\n  своё (private) %8.1f МБ\n  в подкачке     %8.1f МБ\n", r/1024, p/1024, d/1024, s/1024}' \
        "/proc/$1/smaps_rollup"
}

printf 'Оболочка (pid %s, работает %s с)\n' "$pid" "$(ps -o etimes= -p "$pid" | tr -d ' ')"
summary "$pid"

printf '\nКрупнейшие области:\n'
python3 - "$pid" <<'PYEOF'
import sys, collections
pid = sys.argv[1]
current = None
totals = collections.Counter()
for line in open(f'/proc/{pid}/smaps'):
    if '-' in line.split(' ')[0] and ':' not in line.split(' ')[0]:
        parts = line.split()
        current = parts[5] if len(parts) > 5 else '[аноним]'
    elif line.startswith('Rss:'):
        totals[current] += int(line.split()[1])
for name, kb in totals.most_common(10):
    short = name if len(name) < 52 else '…' + name[-51:]
    print('  %8.1f МБ  %s' % (kb / 1024, short))
PYEOF

if [ "$mode" = "--floor" ]; then
    printf '\nПустая оболочка на том же движке:\n'
    tmp=$(mktemp -d)
    cat > "$tmp/shell.qml" <<'QML'
import Quickshell
import QtQuick
ShellRoot {
    PanelWindow {
        anchors { top: true; left: true }
        implicitWidth: 80; implicitHeight: 20
        color: "#202020"
    }
}
QML
    setsid "$HOME/.local/bin/quickshell" -p "$tmp/shell.qml" >/dev/null 2>&1 &
    sleep 8
    floor_pid=$(pgrep -x quickshell-bin | grep -v "^$pid\$" | head -1 || true)
    if [ -n "$floor_pid" ]; then
        summary "$floor_pid"
        kill "$floor_pid" 2>/dev/null || true
        printf '\n  Разница с этим полом — цена содержимого оболочки.\n'
    else
        printf '  не удалось запустить\n'
    fi
    rm -rf "$tmp"
fi

if [ "$mode" = "--watch" ]; then
    seconds=${2:-60}
    printf '\nНаблюдение %s с (растёт ли):\n' "$seconds"
    elapsed=0
    while [ "$elapsed" -le "$seconds" ]; do
        printf '  %4s с  %8.1f МБ\n' "$elapsed" \
            "$(awk '/^Rss:/ {print $2/1024}' "/proc/$pid/smaps_rollup")"
        sleep 10
        elapsed=$((elapsed + 10))
    done
fi

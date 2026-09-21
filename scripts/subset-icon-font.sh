#!/bin/sh
# Урезает шрифт значков до тех иконок, которые оболочка действительно рисует.
#
# Зачем. Material Symbols Rounded — вариативный шрифт на 6618 глифов и 14 МБ.
# Qt отображает его в память по мере использования, и в долгой сессии это
# 17 МБ резидентно. Оболочка рисует около двухсот иконок, остальное лежит
# мёртвым грузом.
#
# Как. Имена иконок собираются из самого проекта: строки вида
# `iconName: "wifi"`, `text: "bolt"`, `icon` в config/*.json. Плюс к ним все
# глифы с началами вроде battery, signal, volume — их имена в коде собираются
# из частей, и по одному их не найти. Дальше pyftsubset оставляет только эти
# глифы и правила подстановки, которые к ним ведут.
#
# Важно про features: Material Symbols подставляет иконки через `rlig` и
# `rclt`, а не через обычные `liga`. Если оставить только `liga`, из шрифта
# пропадут все подстановки и вместо иконок будут видны их названия буквами.
#
# Полный шрифт хранится в ~/.local/opt/material-symbols и служит источником
# для пересборки. Именно вне каталога шрифтов: fontconfig ищет по имени
# семейства, и две версии с одним именем спорят между собой.
#
# Использование:
#   scripts/subset-icon-font.sh            пересобрать и поставить
#   scripts/subset-icon-font.sh --restore  вернуть полный шрифт
#   scripts/subset-icon-font.sh --dry-run  посчитать, ничего не меняя

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
font_dir="$HOME/.local/share/fonts/material-symbols"
installed="$font_dir/material-symbols-rounded.ttf"
# Полный шрифт держим ВНЕ каталога шрифтов. Если положить его рядом,
# fontconfig увидит два файла с одним именем семейства «Material Symbols
# Rounded» и выберет полный — урезанный окажется бесполезен. Я на это
# наступил: экономии не было, пока копия лежала в font_dir.
full="$HOME/.local/opt/material-symbols/material-symbols-rounded-full.ttf"
venv="$HOME/.local/opt/fonttools-venv"
mode=${1:-}

[ -f "$installed" ] || { echo "Не нашёл шрифт: $installed" >&2; exit 1; }

if [ "$mode" = "--restore" ]; then
    [ -f "$full" ] || { echo "Полного шрифта нет: $full" >&2; exit 1; }
    cp -f "$full" "$installed"
    fc-cache -f "$font_dir" >/dev/null
    echo "Вернул полный шрифт. Перезапустить оболочку: systemctl --user restart my-shell.service"
    exit 0
fi

if [ ! -x "$venv/bin/pyftsubset" ]; then
    echo "Ставлю fonttools в $venv"
    python3 -m venv "$venv"
    "$venv/bin/pip" install -q fonttools brotli
fi

mkdir -p "$(dirname "$full")"

# Источником всегда служит $full. Если его ещё нет, им становится
# установленный шрифт — но только после проверки, что он действительно
# полный. Без этой проверки повторный запуск взял бы за источник уже
# урезанный файл и стёр бы всё остальное: я так и потерял оригинал.
if [ ! -f "$full" ]; then
    if "$venv/bin/python" - "$installed" <<'PY'
import sys
from fontTools.ttLib import TTFont
font = TTFont(sys.argv[1])
order = font.getGlyphOrder()
full_enough = len(order) > 3000
named = any(not n.startswith('glyph') for n in order[3:20])
sys.exit(0 if (full_enough and named) else 1)
PY
    then
        cp "$installed" "$full"
        echo "Сохранил полный шрифт как источник: $full"
    else
        echo "Установленный шрифт уже урезан, а источника нет: $full" >&2
        echo "Положите туда полный Material Symbols Rounded и запустите снова." >&2
        exit 1
    fi
fi

# Копия из прошлых версий скрипта лежала в каталоге шрифтов, и fontconfig
# выбирал её вместо урезанной — экономии не было. Убираем, но только когда
# источник уже на месте.
stale="$font_dir/material-symbols-rounded-full.ttf"
if [ -f "$stale" ] && [ -f "$full" ]; then
    rm -f "$stale"
    echo "Убрал лишнюю копию из каталога шрифтов: $stale"
fi

glyphs=$(mktemp)
trap 'rm -f "$glyphs" "$glyphs.ttf"' EXIT

"$venv/bin/python" - "$root" "$full" "$glyphs" <<'PYEOF'
import json, pathlib, re, sys
from fontTools.ttLib import TTFont

root, full_font, out_path = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
available = set(TTFont(full_font).getGlyphOrder())

# Имена из кода. Контексты, где значение точно иконка, плюс любые строки в
# строке с присваиванием иконки — там встречаются тернарные выражения.
direct = re.compile(r'(?:iconName|icon|materialSymbol|secondaryMaterialSymbol|text)\s*:\s*"([a-z][a-z0-9_]{2,40})"')
quoted = re.compile(r'"([a-z][a-z0-9_]{2,40})"')
context = re.compile(r'(iconName|materialSymbol|\bicon)\s*:')

names = set()
for pattern in ('*.qml', '*.js'):
    for path in root.rglob(pattern):
        if 'build/' in str(path):
            continue
        text = path.read_text(encoding='utf-8', errors='ignore')
        names.update(direct.findall(text))
        for line in text.split('\n'):
            if context.search(line):
                names.update(quoted.findall(line))

# Имена из настроек: плитки, карточки плашки, компоненты панели.
def walk(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == 'icon' and isinstance(value, str):
                names.add(value)
            walk(value)
    elif isinstance(node, list):
        for value in node:
            walk(value)

for path in (root / 'config').glob('*.json'):
    walk(json.loads(path.read_text(encoding='utf-8')))

from_code = {n for n in names if n in available}

# Страховка: имена, собираемые в коде из частей (battery_5_bar, wifi_2_bar…).
prefixes = ('battery', 'signal', 'wifi', 'bluetooth', 'volume', 'brightness',
            'keyboard', 'network', 'mic', 'screen', 'cloud', 'timer', 'light',
            'dark', 'notifications', 'power', 'sensors', 'sunny', 'bedtime',
            'play', 'pause', 'skip', 'repeat', 'shuffle', 'folder', 'image',
            'music', 'lock', 'wallpaper', 'settings', 'chevron', 'arrow')
by_prefix = {g for g in available if g.startswith(prefixes)}

keep = from_code | by_prefix
pathlib.Path(out_path).write_text('\n'.join(sorted(keep)))
print('  из кода и настроек: %d' % len(from_code))
print('  добавлено по началам имён: %d' % len(by_prefix - from_code))
print('  всего оставляем: %d из %d глифов' % (len(keep), len(available)))
PYEOF

if [ "$mode" = "--dry-run" ]; then
    echo "Ничего не меняю (--dry-run)."
    exit 0
fi

# rlig и rclt обязательны: именно ими подставляются иконки.
"$venv/bin/pyftsubset" "$full" --output-file="$glyphs.ttf" \
    --glyphs-file="$glyphs" --unicodes=U+0020-007E \
    --layout-features=rlig,rclt,liga,calt,ccmp --no-layout-closure \
    --name-IDs='*' --recalc-bounds

"$venv/bin/python" - "$glyphs.ttf" <<'PYEOF'
import sys
from fontTools.ttLib import TTFont
font = TTFont(sys.argv[1])
features = sorted({r.FeatureTag for r in font['GSUB'].table.FeatureList.FeatureRecord})
assert 'rlig' in features and 'rclt' in features, \
    'потерялись подстановки: иконки будут видны буквами (features=%s)' % features
axes = [a.axisTag for a in font['fvar'].axes]
assert 'FILL' in axes and 'opsz' in axes, 'потерялись оси: %s' % axes
print('  проверка: подстановки %s, оси %s' % (features, axes))
PYEOF

cp -f "$glyphs.ttf" "$installed"
fc-cache -f "$font_dir" >/dev/null
printf 'Готово: %.2f МБ вместо %.2f МБ\n' \
    "$(stat -c %s "$installed" | awk '{print $1/1048576}')" \
    "$(stat -c %s "$full" | awk '{print $1/1048576}')"
echo "Перезапустить оболочку: systemctl --user restart my-shell.service"
